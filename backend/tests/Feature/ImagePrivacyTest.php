<?php

namespace Tests\Feature;

use App\Media\PrivateImage;
use App\Models\City;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Photos people send (messages, posts, avatars, covers) are re-encoded on the server: no EXIF / GPS / device data
 * survives, and a camera photo that relies on its EXIF orientation tag still ends up upright.
 */
class ImagePrivacyTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private User $sender;

    private User $receiver;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        $city = City::where('slug', 'alanya')->value('id');
        $make = fn (string $name) => User::create(['name' => ucfirst($name), 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => '1995-01-01', 'password' => 'TestPassword1234', 'city_id' => $city]);
        $this->sender = $make('sender');
        $this->receiver = $make('receiver');
    }

    private function as(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    /** A landscape (40×20) JPEG that carries an EXIF block with GPS-looking data and the given orientation. */
    private function cameraJpeg(int $orientation, bool $little = true, int $width = 40, int $height = 20): string
    {
        $image = imagecreatetruecolor($width, $height);
        imagefill($image, 0, 0, imagecolorallocate($image, 20, 40, 200));
        imagefilledrectangle($image, 0, 0, intdiv($width, 4), $height - 1, imagecolorallocate($image, 250, 10, 10)); // the "left" edge is red
        ob_start();
        imagejpeg($image, null, 90);
        $jpeg = ob_get_clean();

        $short = fn (int $v) => $little ? pack('v', $v) : pack('n', $v);
        $long = fn (int $v) => $little ? pack('V', $v) : pack('N', $v);
        $gps = 'GPSLatitude=36.54463 GPSLongitude=32.00217 Make=Pixel Model=6a';
        // TIFF: header, IFD0 with the orientation entry only, followed by a blob that looks like GPS/device tags.
        $tiff = ($little ? 'II' : 'MM').$short(42).$long(8).$short(1)
            .$short(0x0112).$short(3).$long(1).$short($orientation).$short(0).$long(0).$gps;
        $payload = "Exif\0\0".$tiff;
        $app1 = "\xFF\xE1".pack('n', strlen($payload) + 2).$payload;

        return substr($jpeg, 0, 2).$app1.substr($jpeg, 2);
    }

    private function assertClean(string $bytes, string $where): void
    {
        $this->assertStringNotContainsString('Exif', $bytes, "$where: no EXIF block");
        $this->assertStringNotContainsString('GPSLatitude', $bytes, "$where: no GPS data");
        $this->assertStringNotContainsString('Pixel', $bytes, "$where: no device data");
        $this->assertStringNotContainsString("\xFF\xE1", $bytes, "$where: no APP1 segment at all");
        $this->assertSame("\xFF\xD8", substr($bytes, 0, 2), "$where: still a JPEG");
    }

    public function test_the_orientation_reader_understands_both_byte_orders_and_ignores_bad_input(): void
    {
        foreach (range(1, 8) as $value) {
            $this->assertSame($value, PrivateImage::orientation($this->cameraJpeg($value, true)), "little endian $value");
            $this->assertSame($value, PrivateImage::orientation($this->cameraJpeg($value, false)), "big endian $value");
        }
        $this->assertSame(1, PrivateImage::orientation($this->cameraJpeg(9)), 'Out of range values count as upright.');
        $this->assertSame(1, PrivateImage::orientation(''));
        $this->assertSame(1, PrivateImage::orientation('not an image at all'));
        $this->assertSame(1, PrivateImage::orientation("\xFF\xD8\xFF\xE1\x00\x04Exif"), 'Truncated EXIF never throws.');
        ob_start();
        imagejpeg(imagecreatetruecolor(4, 4));
        $this->assertSame(1, PrivateImage::orientation(ob_get_clean()), 'A JPEG without EXIF is upright.');
    }

    public function test_message_photos_lose_all_metadata_and_a_rotated_camera_photo_is_made_upright(): void
    {
        $this->as($this->sender)->postJson('/api/v1/users/'.$this->receiver->id.'/messages', ['body' => 'Hi', 'request_id' => (string) Str::uuid()])->assertCreated();
        $conversation = DB::table('conversations')->value('id');
        $this->as($this->receiver)->postJson("/api/v1/conversations/$conversation/request/accept")->assertSuccessful();

        $cases = [1 => [40, 20], 6 => [20, 40], 8 => [20, 40], 3 => [40, 20]];
        foreach ($cases as $orientation => [$width, $height]) {
            $upload = UploadedFile::fake()->createWithContent('camera.jpg', $this->cameraJpeg($orientation));
            $message = $this->as($this->sender)->post('/api/v1/users/'.$this->receiver->id.'/messages', [
                'request_id' => (string) Str::uuid(), 'image' => $upload,
            ], ['Accept' => 'application/json'])->assertCreated()->json('data.message');
            $served = $this->as($this->receiver)->get($message['image'])->assertOk()->assertHeader('Content-Type', 'image/jpeg');
            $bytes = $served->streamedContent() ?: $served->getContent();
            $this->assertClean($bytes, "message photo, orientation $orientation");
            [$w, $h] = getimagesizefromstring($bytes);
            $this->assertSame([$width, $height], [$w, $h], "orientation $orientation is applied to the pixels");
        }
    }

    public function test_post_photos_avatars_and_covers_are_clean_too(): void
    {
        $city = City::where('slug', 'alanya')->value('id');
        $post = $this->as($this->sender)->post('/api/v1/posts', [
            'body' => 'Sahilde', 'type' => 'moment', 'city_id' => $city, 'visibility' => 'city', 'is_anonymous' => 0, 'request_id' => (string) Str::uuid(),
            'media' => [UploadedFile::fake()->createWithContent('camera.jpg', $this->cameraJpeg(6))],
        ], ['Accept' => 'application/json'])->assertCreated()->json('data');
        $bytes = $this->as($this->receiver)->get($post['media'][0]['url'])->assertOk();
        $content = $bytes->streamedContent() ?: $bytes->getContent();
        $this->assertClean($content, 'post photo');
        $this->assertSame([20, 40], array_slice(getimagesizefromstring($content), 0, 2));

        foreach (['avatar' => 'profile/avatar', 'cover' => 'profile/cover'] as $field => $route) {
            $response = $this->as($this->sender)->post("/api/v1/$route", [$field => UploadedFile::fake()->createWithContent('me.jpg', $this->cameraJpeg(6, true, 400, 200))],
                ['Accept' => 'application/json']);
            $response->assertSuccessful();
            $url = $response->json($field === 'avatar' ? 'data.avatar' : 'data.cover_image');
            $this->assertNotEmpty($url, $field);
            $served = $this->get($url)->assertOk();
            $content = $served->streamedContent() ?: $served->getContent();
            $this->assertClean($content, $field);
            $this->assertSame([200, 400], array_slice(getimagesizefromstring($content), 0, 2), "$field is upright");
        }
    }
}
