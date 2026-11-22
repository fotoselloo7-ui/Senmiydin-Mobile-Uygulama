<?php

namespace Tests\Feature;

use App\Accounts\EraseAccount;
use App\Models\City;
use App\Models\MapNote;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\Support\FakeMedia;
use Tests\TestCase;

/** One optional photo per map note (digital letter): privacy, public lifetime, archive, repost and cleanup. */
class MapNoteImageTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $city;

    private User $ada;

    private User $ece;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Carbon::setTestNow(Carbon::parse('2026-11-15 12:00:00', 'UTC'));
        $this->city = City::where('slug', 'alanya')->value('id');
        $make = fn (string $name) => User::create(['name' => ucfirst($name), 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => '1995-01-01', 'password' => 'TestPassword1234', 'city_id' => $this->city, 'nearby_visible' => true, 'active_city_id' => $this->city]);
        $this->ada = $make('ada');
        $this->ece = $make('ece');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function as(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    private function note(?UploadedFile $image, array $extra = [], ?User $as = null)
    {
        return $this->as($as ?? $this->ada)->post('/api/v1/map-notes', [
            'body' => 'Seni burada gördüm, yarın yine buradayım.', 'is_anonymous' => 0, 'city_id' => $this->city,
            'latitude' => 36.5446, 'longitude' => 32.0021, 'request_id' => (string) Str::uuid(), ...($image ? ['image' => $image] : []), ...$extra,
        ], ['Accept' => 'application/json']);
    }

    private function photo(string $name = 'kamera.jpg'): UploadedFile
    {
        return UploadedFile::fake()->createWithContent($name, FakeMedia::jpegWithExif());
    }

    public function test_a_letter_with_a_photo_is_stored_re_encoded_under_a_random_name_and_served_by_id(): void
    {
        $data = $this->note($this->photo('IMG_2026.jpg'))->assertCreated()->json('data');
        $this->assertSame('/api/v1/map-notes/'.$data['id'].'/image', $data['image']);
        $path = DB::table('map_notes')->find($data['id'])->image_path;
        $this->assertMatchesRegularExpression('#^map-notes/[0-9a-f-]{36}\.jpg$#', $path);
        $this->assertStringNotContainsString('IMG_2026', $path);
        $bytes = Storage::disk('local')->get($path);
        $this->assertSame("\xFF\xD8", substr($bytes, 0, 2));
        foreach (['Exif', 'GPSLatitude', 'Pixel', "\xFF\xE1"] as $needle) {
            $this->assertStringNotContainsString($needle, $bytes, "$needle was removed");
        }
        $served = $this->as($this->ece)->get($data['image'])->assertOk()->assertHeader('Content-Type', 'image/jpeg');
        $this->assertStringContainsString('no-store', $served->headers->get('Cache-Control'));
        // The JSON never carries a file name or path.
        $this->assertStringNotContainsString('.jpg', json_encode($data));
        $this->assertStringNotContainsString('map-notes/', str_replace('/api/v1/map-notes/', '', json_encode($data)));
        $this->assertArrayNotHasKey('image_path', $data);
        // Detail and marker group views show the same URL.
        $this->as($this->ece)->getJson('/api/v1/map-notes/'.$data['id'])->assertJsonPath('data.note.image', $data['image']);
        $this->as($this->ece)->getJson('/api/v1/map/notes/'.$data['group'])->assertJsonPath('data.items.0.image', $data['image']);
        $this->as($this->ada)->getJson('/api/v1/my/map-notes/'.$data['id'])->assertJsonPath('data.note.image', $data['image']);
    }

    public function test_a_letter_without_a_photo_is_unchanged_and_its_image_route_is_404(): void
    {
        $data = $this->note(null)->assertCreated()->assertJsonPath('data.image', null)->json('data');
        $this->as($this->ece)->get('/api/v1/map-notes/'.$data['id'].'/image')->assertNotFound();
        $json = $this->as($this->ada)->postJson('/api/v1/map-notes', ['body' => 'Sadece yazı notu.', 'is_anonymous' => false, 'city_id' => $this->city,
            'latitude' => 36.5446, 'longitude' => 32.0021, 'request_id' => (string) Str::uuid()])->assertCreated();
        $this->assertNull($json->json('data.image'));
    }

    public function test_malformed_svg_fake_and_double_extension_files_are_rejected(): void
    {
        $this->withoutMiddleware(\Illuminate\Routing\Middleware\ThrottleRequests::class);
        $bad = [
            'garbage.jpg' => random_bytes(500),
            'text.png' => 'just some text pretending to be an image',
            'vector.svg' => '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><script>alert(1)</script></svg>',
            'vector.png' => '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>',
            'shell.php' => '<?php system($_GET["x"]);',
            'gif.gif' => "GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xFF\xFF\xFF!\xF9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;",
        ];
        foreach ($bad as $name => $content) {
            $this->note(UploadedFile::fake()->createWithContent($name, $content))->assertUnprocessable()->assertJsonValidationErrors('image');
        }
        // A real photo hiding behind a double extension is refused too, even though its name is never used.
        $this->note($this->photo('evil.php.jpg'))->assertUnprocessable()->assertJsonValidationErrors('image');
        $this->note($this->photo('trick.svg.png'))->assertUnprocessable();
        $this->assertDatabaseCount('map_notes', 0);
        $this->assertSame([], Storage::disk('local')->allFiles());
        // Oversized dimensions are refused as well.
        $huge = imagecreatetruecolor(5001, 10);
        ob_start();
        imagejpeg($huge);
        $this->note(UploadedFile::fake()->createWithContent('wide.jpg', ob_get_clean()))->assertUnprocessable();
    }

    public function test_an_anonymous_letter_with_a_photo_leaks_no_identity_or_device_metadata(): void
    {
        $data = $this->note($this->photo('Pixel6a_ada_home.jpg'), ['is_anonymous' => 1])->assertCreated()->json('data');
        $this->assertNull($data['author']);
        $payload = json_encode($data);
        foreach (['"username"', 'user_id', 'email', 'Pixel6a', 'ada_home'] as $needle) {
            $this->assertStringNotContainsString($needle, $payload, $needle);
        }
        $seen = $this->as($this->ece)->getJson('/api/v1/map-notes/'.$data['id'])->json('data.note');
        $this->assertNull($seen['author']);
        $this->assertArrayNotHasKey('user_id', $seen);
        $bytes = $this->as($this->ece)->get($seen['image'])->streamedContent();
        $this->assertStringNotContainsString('Pixel', $bytes);
        $this->assertStringNotContainsString('GPS', $bytes);
    }

    public function test_the_photo_is_public_only_while_the_letter_is_and_the_owner_keeps_it_in_the_archive(): void
    {
        $this->withoutMiddleware(\Illuminate\Routing\Middleware\ThrottleRequests::class);
        $data = $this->note($this->photo())->assertCreated()->json('data');
        $url = $data['image'];
        $this->as($this->ece)->get($url)->assertOk();

        // Taken off the map by the owner: others lose the photo, the owner keeps it.
        $this->as($this->ada)->postJson('/api/v1/map-notes/'.$data['id'].'/archive')->assertOk();
        $this->as($this->ece)->get($url)->assertNotFound();
        $this->as($this->ada)->get($url)->assertOk();
        $this->as($this->ada)->getJson('/api/v1/my/map-notes/'.$data['id'])->assertJsonPath('data.note.image', $url);

        // A second letter simply expires after 7 days.
        $second = $this->note($this->photo())->assertCreated()->json('data');
        $this->as($this->ece)->get($second['image'])->assertOk();
        Carbon::setTestNow(now()->addDays(7)->addMinute());
        $this->as($this->ece)->get($second['image'])->assertNotFound();
        $this->as($this->ada)->get($second['image'])->assertOk();
        $this->as($this->ada)->getJson('/api/v1/my/map-notes/'.$second['id'])->assertJsonPath('data.note.state', 'expired')->assertJsonPath('data.note.image', $second['image']);
        // Blocked viewers and strangers never get it.
        $third = $this->note($this->photo())->assertCreated()->json('data');
        DB::table('user_blocks')->insert(['blocker_id' => $this->ece->id, 'blocked_id' => $this->ada->id, 'created_at' => now()]);
        $this->as($this->ece)->get($third['image'])->assertNotFound();
        $this->flushHeaders();
        $this->app['auth']->forgetGuards();
        $this->getJson($third['image'])->assertUnauthorized();
    }

    public function test_a_repost_keeps_the_photo_with_its_own_copy_and_the_historical_date(): void
    {
        $data = $this->note($this->photo())->assertCreated()->json('data');
        $this->as($this->ada)->postJson('/api/v1/map-notes/'.$data['id'].'/archive')->assertOk();
        Carbon::setTestNow(now()->addDay());
        $fresh = $this->as($this->ada)->postJson('/api/v1/map-notes/'.$data['id'].'/repost', ['request_id' => (string) Str::uuid()])->assertCreated()->json('data');
        $this->assertNotNull($fresh['image']);
        $this->assertNotSame($data['image'], $fresh['image']);
        $this->assertSame($data['occurred_at'], $fresh['occurred_at'], 'The letter keeps its real date.');
        $this->assertTrue($fresh['republished']);
        $oldPath = DB::table('map_notes')->find($data['id'])->image_path;
        $newPath = DB::table('map_notes')->find($fresh['id'])->image_path;
        $this->assertNotSame($oldPath, $newPath);
        Storage::disk('local')->assertExists([$oldPath, $newPath]);
        $this->as($this->ece)->get($fresh['image'])->assertOk();
        // Deleting the old publication does not touch the new one.
        $this->as($this->ada)->deleteJson('/api/v1/map-notes/'.$data['id'])->assertOk();
        Storage::disk('local')->assertMissing($oldPath);
        Storage::disk('local')->assertExists($newPath);
    }

    public function test_permanent_delete_retention_purge_and_account_deletion_remove_the_files(): void
    {
        $this->withoutMiddleware(\Illuminate\Routing\Middleware\ThrottleRequests::class);
        $one = $this->note($this->photo())->assertCreated()->json('data');
        $path = DB::table('map_notes')->find($one['id'])->image_path;
        Storage::disk('local')->assertExists($path);
        $this->as($this->ada)->deleteJson('/api/v1/map-notes/'.$one['id'])->assertOk();
        $this->assertDatabaseMissing('map_notes', ['id' => $one['id']]);
        Storage::disk('local')->assertMissing($path);

        // A reported letter is only soft-deleted; its photo goes when the retention purge removes the row.
        $two = $this->note($this->photo())->assertCreated()->json('data');
        $twoPath = DB::table('map_notes')->find($two['id'])->image_path;
        DB::table('reports')->insert(['reporter_id' => $this->ece->id, 'target_type' => 'map_note', 'target_id' => $two['id'], 'reason' => 'spam', 'status' => 'pending', 'created_at' => now()]);
        $this->as($this->ada)->deleteJson('/api/v1/map-notes/'.$two['id'])->assertOk();
        $this->as($this->ece)->get($two['image'])->assertNotFound();
        Storage::disk('local')->assertExists($twoPath);
        Carbon::setTestNow(now()->addDays(31));
        $this->assertSame(1, MapNote::purgeExpired());
        Storage::disk('local')->assertMissing($twoPath);

        // Account deletion queues every remaining photo and clears the path.
        Carbon::setTestNow(Carbon::parse('2026-11-15 12:00:00', 'UTC'));
        $three = $this->note($this->photo())->assertCreated()->json('data');
        $threePath = DB::table('map_notes')->find($three['id'])->image_path;
        app(EraseAccount::class)->erase($this->ada->fresh());
        $this->assertNull(DB::table('map_notes')->find($three['id'])->image_path);
        $this->assertDatabaseHas('media_deletions', ['path' => $threePath]);
        $this->as($this->ece)->get($three['image'])->assertNotFound();
        $this->artisan('media:cleanup')->assertExitCode(0);
        Storage::disk('local')->assertMissing($threePath);
    }

    public function test_replies_stay_text_only_and_an_idempotent_retry_does_not_store_a_second_file(): void
    {
        $data = $this->note($this->photo())->assertCreated()->json('data');
        $reply = $this->as($this->ece)->post('/api/v1/map-notes/'.$data['id'].'/replies', [
            'body' => 'Ben de oradaydım.', 'request_id' => (string) Str::uuid(), 'image' => $this->photo(),
        ], ['Accept' => 'application/json'])->assertCreated()->json('data');
        $this->assertArrayNotHasKey('image', $reply);
        $this->assertSame(1, count(Storage::disk('local')->allFiles()));

        $request = (string) Str::uuid();
        $first = $this->note($this->photo(), ['request_id' => $request])->assertCreated()->json('data');
        $again = $this->note($this->photo(), ['request_id' => $request])->assertOk()->json('data');
        $this->assertSame($first['id'], $again['id']);
        $this->assertSame(2, count(Storage::disk('local')->allFiles()), 'The retry stored nothing extra.');
    }
}
