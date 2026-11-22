<?php

namespace Tests\Feature;

use App\Accounts\MediaCleanup;
use App\Models\City;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Cover photos are held to the same standard as avatars. */
class CoverSecurityTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private function member(string $username): array
    {
        $token = $this->postJson('/api/v1/auth/register', [
            'name' => ucfirst($username).' Test', 'username' => $username, 'email' => $username.'@example.test',
            'password' => 'GeciciSifre123', 'birth_date' => '1998-04-12',
            'city_id' => City::where('name', 'Alanya')->value('id'), 'accepted_terms' => true,
        ])->assertCreated()->json('data.token');

        return [User::where('username', $username)->firstOrFail(), $token];
    }

    private function as(string $token): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($token);
    }

    /** A cover-sized JPEG carrying the repository's GPS EXIF (APP1) segment under an identifying filename. */
    private function jpegWithGpsExif(): UploadedFile
    {
        $source = file_get_contents(base_path('tests/Fixtures/gps-image.jpg'));
        $offset = strpos($source, "\xFF\xE1");
        $this->assertNotFalse($offset, 'fixture has no APP1 segment');
        $segment = substr($source, $offset, 2 + unpack('n', substr($source, $offset + 2, 2))[1]);
        $this->assertStringContainsString('Exif', $segment);
        $canvas = imagecreatetruecolor(480, 200);
        ob_start();
        imagejpeg($canvas);
        $plain = ob_get_clean();
        $path = tempnam(sys_get_temp_dir(), 'cover');
        file_put_contents($path, "\xFF\xD8".$segment.substr($plain, 2));
        $this->assertStringContainsString('TEST-PRIVATE-GPS', file_get_contents($path));

        return new UploadedFile($path, 'original-private-place.jpg', 'image/jpeg', null, true);
    }

    public function test_cover_is_reencoded_without_exif_gps_original_name_or_executable_payload(): void
    {
        $disk = Storage::fake(config('mobile.avatar_disk'));
        [, $token] = $this->member('owner');
        $gps = $this->jpegWithGpsExif();
        $url = $this->as($token)->postJson('/api/v1/profile/cover', ['cover' => $gps])->assertOk()->json('data.cover_image');

        $this->assertStringNotContainsString('original-private-place', $url);
        $bytes = $disk->get('covers/'.basename($url));
        $this->assertStringNotContainsString('TEST-PRIVATE-GPS', $bytes);
        $this->assertStringNotContainsString('Exif', $bytes);
        $this->assertNotFalse(imagecreatefromstring($bytes));
        $this->assertSame('image/jpeg', getimagesizefromstring($bytes)['mime']);
    }

    public function test_cover_rejects_fake_mismatched_malformed_svg_oversized_and_unauthenticated_uploads(): void
    {
        $disk = Storage::fake(config('mobile.avatar_disk'));
        [, $token] = $this->member('owner');
        $upload = fn (UploadedFile $file) => $this->as($token)->postJson('/api/v1/profile/cover', ['cover' => $file]);

        $upload(UploadedFile::fake()->createWithContent('cover.jpg', '<?php echo 1; ?>'))->assertUnprocessable();
        $upload(UploadedFile::fake()->createWithContent('cover.png', "GIF89a\x01\x00\x01\x00"))->assertUnprocessable();
        $upload(UploadedFile::fake()->createWithContent('cover.svg', '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>'))->assertUnprocessable();
        $upload(UploadedFile::fake()->createWithContent('cover.php.jpg', '<?php system($_GET[0]); ?>'))->assertUnprocessable();
        // A real JPEG signature followed by garbage is rejected as an unreadable photo, never stored.
        $upload(UploadedFile::fake()->createWithContent('cover.jpg', "\xFF\xD8\xFF\xE0".str_repeat("\x00", 40)))->assertUnprocessable();
        $upload(UploadedFile::fake()->image('wide.jpg', 5001, 200))->assertUnprocessable();
        $upload(UploadedFile::fake()->image('tall.jpg', 400, 5001))->assertUnprocessable();
        $upload(UploadedFile::fake()->image('big.jpg', 1000, 500)->size(20481))->assertUnprocessable();
        $this->assertSame([], $disk->allFiles());

        $this->flushHeaders();
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/profile/cover', ['cover' => UploadedFile::fake()->image('c.jpg', 640, 240)])->assertUnauthorized();
        $this->deleteJson('/api/v1/profile/cover')->assertUnauthorized();
    }

    public function test_only_the_owner_changes_a_cover_and_only_active_bound_files_are_served(): void
    {
        $disk = Storage::fake(config('mobile.avatar_disk'));
        [$owner, $ownerToken] = $this->member('owner');
        [, $otherToken] = $this->member('other');
        $url = $this->as($ownerToken)->postJson('/api/v1/profile/cover', ['cover' => UploadedFile::fake()->image('c.jpg', 640, 240)])
            ->assertOk()->json('data.cover_image');

        // Another account's delete never touches the owner's file.
        $this->as($otherToken)->deleteJson('/api/v1/profile/cover')->assertOk()->assertJsonPath('data.cover_image', null);
        $disk->assertExists('covers/'.basename($url));
        $this->flushHeaders()->get($url)->assertOk()->assertHeader('X-Content-Type-Options', 'nosniff');

        // Traversal, non-uuid names and unbound files are not servable.
        $this->get('/api/v1/covers/..%2F..%2Fapp.jpg')->assertNotFound();
        $this->get('/api/v1/covers/not-a-uuid.jpg')->assertNotFound();
        $this->get('/api/v1/covers/'.Str::uuid().'.php')->assertNotFound();
        $orphan = (string) Str::uuid();
        $disk->put('covers/'.$orphan.'.jpg', 'orphan');
        $this->get('/api/v1/covers/'.$orphan.'.jpg')->assertNotFound();

        // Suspended or banned owners stop being served and cannot write.
        $owner->forceFill(['account_status' => 'suspended'])->save();
        $this->get($url)->assertNotFound();
        $this->as($ownerToken)->postJson('/api/v1/profile/cover', ['cover' => UploadedFile::fake()->image('d.jpg', 640, 240)])->assertUnauthorized();
        $owner->forceFill(['account_status' => 'banned'])->save();
        $this->get($url)->assertNotFound();
        $owner->forceFill(['account_status' => 'active'])->save();
        $this->get($url)->assertOk();
    }

    public function test_account_erasure_removes_the_cover_file_and_its_public_url(): void
    {
        $disk = Storage::fake(config('mobile.avatar_disk'));
        [$owner, $token] = $this->member('owner');
        $url = $this->as($token)->postJson('/api/v1/profile/cover', ['cover' => UploadedFile::fake()->image('c.jpg', 640, 240)])
            ->assertOk()->json('data.cover_image');
        $path = 'covers/'.basename($url);
        $disk->assertExists($path);

        $this->as($token)->deleteJson('/api/v1/auth/account', ['password' => 'GeciciSifre123', 'confirmation' => 'SİL'])->assertOk();
        $this->assertNull($owner->fresh()->cover_image);
        $this->assertSame(0, app(MediaCleanup::class)->run());
        $disk->assertMissing($path);
        $this->flushHeaders()->get($url)->assertNotFound();
    }
}
