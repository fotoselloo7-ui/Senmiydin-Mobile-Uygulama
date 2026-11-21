<?php

namespace Tests\Feature;

use App\Accounts\EraseAccount;
use App\Models\Admin;
use App\Models\City;
use App\Models\MapNote;
use App\Models\Memory;
use App\Models\Place;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\Support\FakeMedia;
use Tests\TestCase;

/**
 * Anılar (memories): independent owner-curated snapshots with 0–5 photos, four visibility levels decided on the server,
 * created from a map note, a post or directly, and kept apart from their source.
 */
class MemoriesTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $alanya;

    private int $antalya;

    private User $ada;

    private User $ece;

    private User $kaan;

    private User $mert;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Carbon::setTestNow(Carbon::parse('2026-11-21 12:00:00', 'UTC'));
        $this->withoutMiddleware(\Illuminate\Routing\Middleware\ThrottleRequests::class);
        $this->alanya = City::where('slug', 'alanya')->value('id');
        $this->antalya = City::where('slug', 'antalya')->value('id');
        $this->ada = $this->user('ada', $this->alanya);
        $this->ece = $this->user('ece', $this->alanya);
        $this->kaan = $this->user('kaan', $this->alanya);
        $this->mert = $this->user('mert', $this->antalya);
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function user(string $name, int $city, string $birth = '1995-01-01'): User
    {
        return User::create(['name' => ucfirst($name).' Test', 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => $birth, 'password' => 'TestPassword1234', 'city_id' => $city, 'nearby_visible' => true]);
    }

    private function as(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    private function photo(string $name = 'kamera.jpg', int $width = 64, int $height = 48): UploadedFile
    {
        return UploadedFile::fake()->createWithContent($name, FakeMedia::jpegWithExif($width, $height));
    }

    /** @param  list<UploadedFile>  $photos */
    private function make(array $extra = [], array $photos = [], ?User $as = null)
    {
        $payload = ['body' => 'Sahilde yürüdüğümüz akşam.', 'occurred_at' => '2026-08-14T17:30:00Z', 'city_id' => $this->alanya,
            'request_id' => (string) Str::uuid(), ...$extra];
        if ($photos !== []) {
            $payload['media'] = $photos;
        }

        return $this->as($as ?? $this->ada)->post('/api/v1/memories', $payload, ['Accept' => 'application/json']);
    }

    private function create(array $extra = [], array $photos = [], ?User $as = null): array
    {
        return $this->make($extra, $photos, $as)->assertCreated()->json('data');
    }

    private function follow(User $who, User $whom): void
    {
        DB::table('user_follows')->insert(['follower_id' => $who->id, 'followed_id' => $whom->id, 'created_at' => now()]);
    }

    private function note(array $extra = [], ?UploadedFile $image = null): array
    {
        return $this->as($this->ada)->post('/api/v1/map-notes', [
            'body' => 'Seni burada gördüm, yarın yine buradayım.', 'is_anonymous' => 0, 'city_id' => $this->alanya,
            'latitude' => 36.54463, 'longitude' => 32.00211, 'request_id' => (string) Str::uuid(), ...($image ? ['image' => $image] : []), ...$extra,
        ], ['Accept' => 'application/json'])->assertCreated()->json('data');
    }

    // ---------------------------------------------------------------------------------------------------------------
    // CRUD
    // ---------------------------------------------------------------------------------------------------------------

    public function test_a_memory_is_created_listed_edited_and_deleted_by_its_owner(): void
    {
        $memory = $this->create(['visibility' => 'public']);
        $this->assertSame('Sahilde yürüdüğümüz akşam.', $memory['body']);
        $this->assertSame('2026-08-14T17:30:00.000000Z', $memory['occurred_at']);
        $this->assertTrue($memory['mine']);
        $this->assertSame('public', $memory['visibility']);
        $this->assertSame('Alanya', $memory['city']['name']);
        $this->assertSame('Alanya', $memory['place_label']);
        $this->assertSame([], $memory['media']);

        $this->as($this->ada)->getJson('/api/v1/users/ada/memories')->assertOk()->assertJsonCount(1, 'data.items')->assertJsonPath('data.items.0.id', $memory['id']);
        $this->as($this->ada)->getJson('/api/v1/memories/'.$memory['id'])->assertOk()->assertJsonPath('data.body', 'Sahilde yürüdüğümüz akşam.');

        $edited = $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'], [
            'body' => 'Sahilde yürüdük, dondurma yedik.', 'occurred_at' => '2026-08-15T10:00:00Z', 'visibility' => 'followers',
        ])->assertOk()->json('data');
        $this->assertSame('Sahilde yürüdük, dondurma yedik.', $edited['body']);
        $this->assertSame('followers', $edited['visibility']);
        $this->assertSame('2026-08-15T10:00:00.000000Z', $edited['occurred_at']);

        $this->as($this->ada)->deleteJson('/api/v1/memories/'.$memory['id'])->assertOk();
        $this->assertDatabaseMissing('memories', ['id' => $memory['id']]);
        $this->as($this->ada)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
    }

    public function test_only_the_owner_can_edit_hide_or_delete_and_a_memory_needs_text_or_a_photo(): void
    {
        $memory = $this->create(['visibility' => 'public']);
        $this->as($this->ece)->postJson('/api/v1/memories/'.$memory['id'], ['body' => 'Benim'])->assertNotFound();
        $this->as($this->ece)->postJson('/api/v1/memories/'.$memory['id'].'/hide')->assertNotFound();
        $this->as($this->ece)->deleteJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        $this->assertDatabaseHas('memories', ['id' => $memory['id'], 'body' => 'Sahilde yürüdüğümüz akşam.']);

        $this->make(['body' => '   '])->assertStatus(422)->assertJsonValidationErrors('body');
        $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'], ['body' => ''])->assertStatus(422);
        // A photo alone is a valid memory.
        $this->make(['body' => ''], [$this->photo()])->assertCreated();
    }

    public function test_hide_and_show_keep_the_memory_for_its_owner_only(): void
    {
        $memory = $this->create(['visibility' => 'public']);
        $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertOk();

        $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'].'/hide')->assertOk()->assertJsonPath('data.is_hidden', true);
        $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        $this->as($this->ece)->getJson('/api/v1/users/ada/memories')->assertJsonCount(0, 'data.items');
        $this->as($this->ada)->getJson('/api/v1/users/ada/memories')->assertJsonCount(1, 'data.items')->assertJsonPath('data.items.0.is_hidden', true);

        $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'].'/unhide')->assertOk()->assertJsonPath('data.is_hidden', false);
        $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertOk();
    }

    public function test_the_list_is_paginated_twenty_at_a_time_newest_event_first(): void
    {
        foreach (range(1, 25) as $day) {
            $this->create(['body' => "Anı $day", 'occurred_at' => Carbon::parse('2025-01-01 10:00:00', 'UTC')->addDays($day)->toISOString()]);
        }
        $first = $this->as($this->ada)->getJson('/api/v1/users/ada/memories')->assertOk()->json('data');
        $this->assertCount(20, $first['items']);
        $this->assertSame(2, $first['next_page']);
        $this->assertSame('Anı 25', $first['items'][0]['body']);
        $this->assertSame('Anı 6', $first['items'][19]['body']);
        $second = $this->as($this->ada)->getJson('/api/v1/users/ada/memories?page=2')->assertOk()->json('data');
        $this->assertCount(5, $second['items']);
        $this->assertNull($second['next_page']);
        $this->assertSame('Anı 1', $second['items'][4]['body']);
    }

    // ---------------------------------------------------------------------------------------------------------------
    // Photos
    // ---------------------------------------------------------------------------------------------------------------

    public function test_zero_to_five_photos_in_the_order_they_were_given_and_never_a_sixth(): void
    {
        $this->assertCount(0, $this->create()['media']);
        $five = $this->create([], array_map(fn ($i) => $this->photo("p$i.jpg", 40 + $i * 10, 48), range(0, 4)))['media'];
        $this->assertCount(5, $five);
        $this->assertSame([40, 50, 60, 70, 80], array_column($five, 'width'));
        $this->assertSame(round(40 / 48, 4), $five[0]['aspect_ratio']);

        $this->make([], array_map(fn () => $this->photo(), range(0, 5)))->assertStatus(422)->assertJsonValidationErrors('media');
        $this->assertSame(2, Memory::count());
    }

    public function test_photos_can_be_reordered_removed_and_added_while_editing(): void
    {
        $memory = $this->create([], [$this->photo('a.jpg', 40, 40), $this->photo('b.jpg', 50, 40), $this->photo('c.jpg', 60, 40)]);
        [$a, $b, $c] = array_column($memory['media'], 'id');

        $reordered = $this->as($this->ada)->post('/api/v1/memories/'.$memory['id'], ['layout' => ['m'.$c, 'm'.$a, 'm'.$b]], ['Accept' => 'application/json'])
            ->assertOk()->json('data.media');
        $this->assertSame([$c, $a, $b], array_column($reordered, 'id'));

        $cPath = DB::table('memory_media')->find($c)->path;
        Storage::disk('local')->assertExists($cPath);
        $changed = $this->as($this->ada)->post('/api/v1/memories/'.$memory['id'], [
            'layout' => ['m'.$a, 'n0', 'm'.$b], 'media' => [$this->photo('d.jpg', 90, 40)],
        ], ['Accept' => 'application/json'])->assertOk()->json('data.media');
        $this->assertCount(3, $changed);
        $this->assertSame([$a, $b], [$changed[0]['id'], $changed[2]['id']]);
        $this->assertSame(90, $changed[1]['width']);
        Storage::disk('local')->assertMissing($cPath);
        $this->assertDatabaseMissing('memory_media', ['id' => $c]);

        // Someone else's photo id (or a made up one) can never be woven into the layout.
        $other = $this->create([], [$this->photo()], $this->ece)['media'][0]['id'];
        $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'], ['layout' => ['m'.$other]])->assertStatus(422);
        $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'], ['layout' => ['m'.$a, 'm'.$a]])->assertStatus(422);
        $this->assertCount(3, $this->as($this->ada)->getJson('/api/v1/memories/'.$memory['id'])->json('data.media'));

        // Removing every photo of a memory that has text is fine; a memory without text and photos is not.
        $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'], ['layout' => []])->assertOk()->assertJsonCount(0, 'data.media');
        $this->assertSame(0, DB::table('memory_media')->where('memory_id', $memory['id'])->count());
    }

    public function test_uploads_go_through_the_secure_pipeline_and_get_a_thumbnail(): void
    {
        $memory = $this->create([], [$this->photo('IMG_2026.jpg', 1200, 900)]);
        $row = DB::table('memory_media')->find($memory['media'][0]['id']);
        $this->assertMatchesRegularExpression('#^memories/[0-9a-f-]{36}\.jpg$#', $row->path);
        $this->assertMatchesRegularExpression('#^memories/[0-9a-f-]{36}\.jpg$#', $row->thumb_path);
        $this->assertStringNotContainsString('IMG_2026', $row->path);
        $bytes = Storage::disk('local')->get($row->path);
        $this->assertSame("\xFF\xD8", substr($bytes, 0, 2));
        foreach (['Exif', 'GPSLatitude', 'Pixel', "\xFF\xE1"] as $needle) {
            $this->assertStringNotContainsString($needle, $bytes, "$needle was removed");
        }
        [$thumbWidth, $thumbHeight] = getimagesizefromstring(Storage::disk('local')->get($row->thumb_path));
        $this->assertSame([480, 360], [$thumbWidth, $thumbHeight]);
        $this->assertLessThan(strlen($bytes), strlen(Storage::disk('local')->get($row->thumb_path)));
        $this->assertSame([1200, 900], [$row->width, $row->height]);
        // The profile list asks for the thumbnail; the viewer for the full photo.
        $this->assertStringEndsWith('/thumb', $memory['media'][0]['thumb_url']);
        $this->as($this->ada)->get($memory['media'][0]['thumb_url'])->assertOk()->assertHeader('Content-Type', 'image/jpeg');
        $this->as($this->ada)->get($memory['media'][0]['url'])->assertOk()->assertHeader('X-Content-Type-Options', 'nosniff');
    }

    public function test_svg_fakes_double_extensions_and_oversized_files_are_rejected(): void
    {
        $svg = UploadedFile::fake()->createWithContent('x.svg', '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>');
        $fake = UploadedFile::fake()->createWithContent('x.jpg', '<?php echo 1;');
        $double = UploadedFile::fake()->createWithContent('evil.php.jpg', FakeMedia::jpegWithExif());
        $png = UploadedFile::fake()->createWithContent('x.svg.png', FakeMedia::jpegWithExif());
        foreach ([$svg, $fake, $double, $png] as $file) {
            $this->make([], [$file])->assertStatus(422)->assertJsonValidationErrors('media.0');
        }
        $this->make([], [UploadedFile::fake()->image('wide.jpg', 3000, 100)])->assertStatus(422);
        $this->make([], [UploadedFile::fake()->create('big.jpg', 6000, 'image/jpeg')])->assertStatus(422);
        $this->assertSame(0, Memory::count());
        $this->assertSame([], Storage::disk('local')->allFiles());
    }

    // ---------------------------------------------------------------------------------------------------------------
    // Sources
    // ---------------------------------------------------------------------------------------------------------------

    public function test_a_map_note_becomes_an_independent_snapshot_that_outlives_the_note(): void
    {
        $note = $this->note(image: $this->photo('not.jpg', 80, 60));
        $noteRow = DB::table('map_notes')->find($note['id']);

        $prefill = $this->as($this->ada)->getJson('/api/v1/memories/prefill?source_type=map_note&source_id='.$note['id'])->assertOk()->json('data');
        $this->assertNull($prefill['existing']);
        $this->assertSame('Seni burada gördüm, yarın yine buradayım.', $prefill['prefill']['body']);
        $this->assertSame('Alanya', $prefill['prefill']['city']['name']);
        $this->assertSame(['s'.$note['id']], array_column($prefill['prefill']['media'], 'ref'));
        $this->assertSame($note['occurred_at'], $prefill['prefill']['occurred_at']);

        $memory = $this->create(['source_type' => 'map_note', 'source_id' => $note['id'], 'body' => $prefill['prefill']['body'],
            'occurred_at' => $prefill['prefill']['occurred_at'], 'layout' => ['s'.$note['id']], 'visibility' => 'public']);
        $this->assertCount(1, $memory['media']);
        $row = DB::table('memory_media')->find($memory['media'][0]['id']);
        $this->assertNotSame($noteRow->image_path, $row->path, 'the memory owns its own copy of the photo');
        Storage::disk('local')->assertExists($row->path);

        // Editing the memory never touches the note.
        $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'], ['body' => 'Değişti', 'occurred_at' => '2020-01-01T00:00:00Z'])->assertOk();
        $after = DB::table('map_notes')->find($note['id']);
        $this->assertSame($noteRow->body, $after->body);
        $this->assertSame($noteRow->occurred_at, $after->occurred_at);

        // The note leaves the map (archive), expires, is permanently deleted: the memory stays whole.
        $this->as($this->ada)->postJson('/api/v1/map-notes/'.$note['id'].'/archive')->assertOk();
        $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertOk();
        Carbon::setTestNow(now()->addDays(60));
        $this->as($this->ada)->deleteJson('/api/v1/map-notes/'.$note['id'])->assertOk();
        $this->assertDatabaseMissing('map_notes', ['id' => $note['id']]);
        Storage::disk('local')->assertMissing($noteRow->image_path);
        Storage::disk('local')->assertExists($row->path);
        $this->as($this->ece)->get($memory['media'][0]['url'])->assertOk();
        $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertOk()->assertJsonPath('data.body', 'Değişti');
    }

    public function test_a_post_becomes_a_memory_without_changing_the_post_and_survives_its_deletion(): void
    {
        $post = $this->as($this->ada)->post('/api/v1/posts', [
            'body' => 'Kaleden gün batımı.', 'type' => 'moment', 'city_id' => $this->alanya, 'visibility' => 'city', 'is_anonymous' => 0,
            'request_id' => (string) Str::uuid(), 'media' => [$this->photo('a.jpg', 50, 50), $this->photo('b.jpg', 60, 50)],
        ], ['Accept' => 'application/json'])->assertCreated()->json('data');
        $postBefore = Post::find($post['id'])->only('body', 'visibility', 'occurred_at', 'place_label');

        $prefill = $this->as($this->ada)->getJson('/api/v1/memories/prefill?source_type=post&source_id='.$post['id'])->assertOk()->json('data.prefill');
        $this->assertSame('Kaleden gün batımı.', $prefill['body']);
        $this->assertCount(2, $prefill['media']);

        $memory = $this->create(['source_type' => 'post', 'source_id' => $post['id'], 'body' => $prefill['body'],
            'occurred_at' => $prefill['occurred_at'], 'layout' => array_column($prefill['media'], 'ref')]);
        $this->assertSame([50, 60], array_column($memory['media'], 'width'));
        $this->assertSame('post', $memory['source_type']);
        $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'], ['body' => 'Başka'])->assertOk();
        $this->assertSame($postBefore, Post::find($post['id'])->only('body', 'visibility', 'occurred_at', 'place_label'));

        $this->as($this->ada)->deleteJson('/api/v1/posts/'.$post['id'])->assertOk();
        $this->as($this->ada)->getJson('/api/v1/memories/'.$memory['id'])->assertOk()->assertJsonCount(2, 'data.media');
        $this->as($this->ada)->get($memory['media'][1]['url'])->assertOk();
    }

    public function test_the_same_source_is_never_copied_twice(): void
    {
        $note = $this->note();
        $first = $this->create(['source_type' => 'map_note', 'source_id' => $note['id']]);
        $again = $this->make(['source_type' => 'map_note', 'source_id' => $note['id']])->assertOk()->json('data');
        $this->assertSame($first['id'], $again['id']);
        $this->assertSame(1, Memory::count());

        $prefill = $this->as($this->ada)->getJson('/api/v1/memories/prefill?source_type=map_note&source_id='.$note['id'])->json('data');
        $this->assertSame($first['id'], $prefill['existing']['id']);
        $mine = $this->as($this->ada)->getJson('/api/v1/my/map-notes')->json('data.items.0');
        $this->assertSame($first['id'], $mine['memory_id']);

        // The same request id is idempotent, and once the memory is deleted the source can be added again.
        $key = (string) Str::uuid();
        $one = $this->create(['request_id' => $key, 'body' => 'Tek']);
        $two = $this->make(['request_id' => $key, 'body' => 'Tek'])->assertOk()->json('data');
        $this->assertSame($one['id'], $two['id']);
        $this->as($this->ada)->deleteJson('/api/v1/memories/'.$first['id'])->assertOk();
        $third = $this->create(['source_type' => 'map_note', 'source_id' => $note['id']]);
        $this->assertNotSame($first['id'], $third['id']);
        $this->assertSame($third['id'], $this->as($this->ada)->getJson('/api/v1/my/map-notes')->json('data.items.0.memory_id'));
    }

    public function test_only_your_own_content_can_be_a_source_and_an_anonymous_source_starts_private(): void
    {
        $note = $this->note(['is_anonymous' => 1]);
        $this->as($this->ece)->getJson('/api/v1/memories/prefill?source_type=map_note&source_id='.$note['id'])->assertNotFound();
        $this->make(['source_type' => 'map_note', 'source_id' => $note['id']], [], $this->ece)->assertNotFound();
        $this->as($this->ada)->putJson('/api/v1/profile', ['memory_default_visibility' => 'public'])->assertOk();
        $this->as($this->ada)->getJson('/api/v1/memories/prefill?source_type=map_note&source_id='.$note['id'])
            ->assertJsonPath('data.prefill.visibility', 'private');
        $this->assertSame('public', $this->as($this->ada)->getJson('/api/v1/memories/prefill?source_type=map_note&source_id='.$this->note()['id'])->json('data.prefill.visibility'));
    }

    // ---------------------------------------------------------------------------------------------------------------
    // Visibility
    // ---------------------------------------------------------------------------------------------------------------

    public function test_private_memories_are_for_the_owner_only(): void
    {
        $memory = $this->create(['visibility' => 'private'], [$this->photo()]);
        foreach ([$this->ece, $this->kaan, $this->mert] as $viewer) {
            $this->as($viewer)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
            $this->as($viewer)->getJson('/api/v1/users/ada/memories')->assertOk()->assertJsonCount(0, 'data.items');
            $this->as($viewer)->get($memory['media'][0]['url'])->assertNotFound();
            $this->as($viewer)->get($memory['media'][0]['thumb_url'])->assertNotFound();
        }
        $this->as($this->ada)->get($memory['media'][0]['url'])->assertOk();
    }

    public function test_followers_only_memories_need_a_follow(): void
    {
        $memory = $this->create(['visibility' => 'followers'], [$this->photo()]);
        $this->as($this->kaan)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        $this->as($this->kaan)->get($memory['media'][0]['url'])->assertNotFound();

        $this->follow($this->ece, $this->ada);
        $seen = $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertOk()->json('data');
        $this->assertFalse($seen['mine']);
        $this->as($this->ece)->getJson('/api/v1/users/ada/memories')->assertJsonCount(1, 'data.items');
        $this->as($this->ece)->get($memory['media'][0]['url'])->assertOk();

        // Following the other way round does not count, and unfollowing closes it again.
        $this->follow($this->ada, $this->kaan);
        $this->as($this->kaan)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        DB::table('user_follows')->where('follower_id', $this->ece->id)->delete();
        $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
    }

    public function test_public_memories_are_visible_to_everyone_signed_in_and_nobody_else(): void
    {
        $memory = $this->create(['visibility' => 'public'], [$this->photo()]);
        foreach ([$this->ece, $this->kaan, $this->mert] as $viewer) {
            $this->as($viewer)->getJson('/api/v1/memories/'.$memory['id'])->assertOk()->assertJsonPath('data.author.username', 'ada');
            $this->as($viewer)->get($memory['media'][0]['url'])->assertOk();
        }
        $this->app['auth']->forgetGuards();
        $this->withHeaders([])->flushHeaders();
        $this->getJson('/api/v1/memories/'.$memory['id'])->assertUnauthorized();
        $this->get($memory['media'][0]['url'], ['Accept' => 'application/json'])->assertUnauthorized();
    }

    public function test_area_memories_open_only_to_people_in_that_area_and_never_through_a_manual_city_choice(): void
    {
        $memory = $this->create(['visibility' => 'area', 'city_id' => $this->alanya], [$this->photo()]);
        // Same home area: yes. Another area: no.
        $this->as($this->kaan)->getJson('/api/v1/memories/'.$memory['id'])->assertOk();
        $this->as($this->kaan)->get($memory['media'][0]['url'])->assertOk();
        $this->as($this->mert)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        $this->as($this->mert)->get($memory['media'][0]['url'])->assertNotFound();

        // Browsing the city by hand does not put you there.
        $this->mert->forceFill(['active_city_id' => $this->alanya, 'active_city_source' => 'manual'])->save();
        $this->as($this->mert)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        // The device really being in the area does.
        $this->mert->forceFill(['active_city_source' => 'device'])->save();
        $this->as($this->mert)->getJson('/api/v1/memories/'.$memory['id'])->assertOk();

        // A hidden area memory is closed to everyone but its owner.
        $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'].'/hide')->assertOk();
        $this->as($this->kaan)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        $this->as($this->ada)->getJson('/api/v1/memories/'.$memory['id'])->assertOk();
    }

    public function test_area_visibility_needs_an_area_and_new_memories_start_with_the_default_without_rewriting_old_ones(): void
    {
        $this->as($this->ada)->postJson('/api/v1/memories', ['body' => 'x', 'occurred_at' => '2026-01-01T10:00:00Z',
            'request_id' => (string) Str::uuid(), 'visibility' => 'area'])->assertStatus(422)->assertJsonValidationErrors('visibility');

        $this->assertSame('private', $this->as($this->ada)->getJson('/api/v1/profile')->json('data.memory_default_visibility'));
        $old = $this->create(['body' => 'Birinci anı']);
        $this->assertSame('private', $old['visibility']);

        $this->as($this->ada)->putJson('/api/v1/profile', ['memory_default_visibility' => 'followers'])->assertOk()->assertJsonPath('data.memory_default_visibility', 'followers');
        $this->assertSame('followers', $this->create(['body' => 'İkinci anı'])['visibility']);
        $this->assertSame('private', DB::table('memories')->find($old['id'])->visibility, 'changing the default never rewrites old memories');
        $this->assertSame('public', $this->create(['body' => 'Üçüncü anı', 'visibility' => 'public'])['visibility'], 'every memory can still choose its own');

        $this->as($this->ada)->putJson('/api/v1/profile', ['memory_default_visibility' => 'area'])->assertOk();
        $this->assertSame('area', $this->create(['body' => 'Dördüncü anı'])['visibility']);
        $this->as($this->ada)->putJson('/api/v1/profile', ['memory_default_visibility' => 'everyone'])->assertStatus(422);
    }

    public function test_blocking_beats_every_visibility_in_both_directions(): void
    {
        $memories = [];
        foreach (['public', 'followers', 'area'] as $visibility) {
            $memories[$visibility] = $this->create(['visibility' => $visibility], [$this->photo()]);
        }
        $this->follow($this->ece, $this->ada);
        foreach ($memories as $memory) {
            $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertOk();
        }

        $this->as($this->ece)->putJson('/api/v1/blocks/'.$this->ada->id)->assertOk();
        foreach ($memories as $memory) {
            $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
            $this->as($this->ece)->get($memory['media'][0]['url'])->assertNotFound();
        }
        $this->as($this->ece)->getJson('/api/v1/users/ada/memories')->assertNotFound();
        $this->as($this->ece)->postJson('/api/v1/reports', ['target_type' => 'memory', 'target_id' => $memories['public']['id'], 'reason' => 'spam'])->assertNotFound();

        // The blocked side: the owner blocks the viewer afterwards.
        $this->as($this->ece)->deleteJson('/api/v1/blocks/'.$this->ada->id)->assertOk();
        $this->as($this->ada)->putJson('/api/v1/blocks/'.$this->kaan->id)->assertOk();
        foreach ($memories as $memory) {
            $this->as($this->kaan)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        }
        $this->as($this->kaan)->getJson('/api/v1/users/ada/memories')->assertNotFound();
        // Unblocked people are unaffected.
        $this->as($this->mert)->getJson('/api/v1/memories/'.$memories['public']['id'])->assertOk();
    }

    public function test_the_teen_and_adult_bands_never_see_each_others_memories(): void
    {
        $teen = $this->user('teena', $this->alanya, '2010-06-01');
        $teenFriend = $this->user('teenb', $this->alanya, '2009-03-01');
        $this->follow($this->ece, $this->ada);
        $this->follow($teenFriend, $teen);
        $adult = $this->create(['visibility' => 'public'], [$this->photo()]);
        $young = $this->create(['visibility' => 'public'], [$this->photo()], $teen);
        $youngFollowers = $this->create(['visibility' => 'followers'], [], $teen);

        $this->as($teen)->getJson('/api/v1/memories/'.$adult['id'])->assertNotFound();
        $this->as($teen)->get($adult['media'][0]['url'])->assertNotFound();
        $this->as($this->ece)->getJson('/api/v1/memories/'.$young['id'])->assertNotFound();
        $this->as($this->ece)->getJson('/api/v1/users/teena/memories')->assertNotFound();
        $this->as($this->ece)->get($young['media'][0]['url'])->assertNotFound();
        // Inside the band everything works as usual.
        $this->as($teenFriend)->getJson('/api/v1/memories/'.$young['id'])->assertOk();
        $this->as($teenFriend)->getJson('/api/v1/memories/'.$youngFollowers['id'])->assertOk();
        // A cross-band follow cannot be used to get around it.
        DB::table('user_follows')->insert(['follower_id' => $this->ece->id, 'followed_id' => $teen->id, 'created_at' => now()]);
        $this->as($this->ece)->getJson('/api/v1/memories/'.$youngFollowers['id'])->assertNotFound();
    }

    public function test_a_suspended_or_erased_owner_disappears_for_everyone(): void
    {
        $memory = $this->create(['visibility' => 'public']);
        $this->ada->forceFill(['account_status' => 'suspended'])->save();
        $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        $this->as($this->ece)->getJson('/api/v1/users/ada/memories')->assertNotFound();
    }

    // ---------------------------------------------------------------------------------------------------------------
    // Privacy of the response
    // ---------------------------------------------------------------------------------------------------------------

    public function test_no_exact_location_or_internal_field_ever_leaves_the_server(): void
    {
        $note = $this->note(image: $this->photo());
        $memory = $this->create(['source_type' => 'map_note', 'source_id' => $note['id'], 'visibility' => 'public', 'layout' => ['s'.$note['id']]]);
        $row = DB::table('memories')->find($memory['id']);
        // What is stored internally is the grid snapped note point, not the typed coordinate, and it is not published.
        $this->assertNotNull($row->approx_latitude);
        $this->assertNotSame(36.54463, (float) $row->approx_latitude);

        $bodies = [
            $this->as($this->ada)->getJson('/api/v1/memories/'.$memory['id'])->getContent(),
            $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->getContent(),
            $this->as($this->ece)->getJson('/api/v1/users/ada/memories')->getContent(),
            $this->as($this->ada)->getJson('/api/v1/memories/prefill?source_type=map_note&source_id='.$note['id'])->getContent(),
        ];
        foreach ($bodies as $json) {
            foreach (['latitude', 'longitude', 'approx', '36.54', '32.00', 'content_hash', 'request_id', 'moderated_at', 'location_history', 'deleted_at', '"lat"', '"lng"'] as $forbidden) {
                $this->assertStringNotContainsString($forbidden, $json, "$forbidden must not be in a memory response");
            }
        }
        // Visibility, hidden state and the kind of source are the owner's business only.
        $others = $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->json('data');
        $this->assertNull($others['visibility']);
        $this->assertNull($others['is_hidden']);
        $this->assertNull($others['source_type']);
        $this->assertFalse($others['mine']);
        $this->assertSame('map_note', $this->as($this->ada)->getJson('/api/v1/memories/'.$memory['id'])->json('data.source_type'));
    }

    public function test_a_chosen_place_decides_the_area_and_keeps_its_label(): void
    {
        $place = Place::create(['provider' => 'osm', 'provider_place_id' => '77', 'city_id' => $this->antalya, 'type' => 'suburb', 'name' => 'Lara',
            'country_code' => 'tr', 'country_name' => 'Türkiye', 'admin1' => 'Antalya', 'display_name' => 'Lara, Antalya', 'latitude' => 36.85612, 'longitude' => 30.78451]);
        $memory = $this->create(['place_id' => $place->id, 'city_id' => $this->alanya, 'visibility' => 'area']);
        $this->assertSame('Antalya', $memory['city']['name'], 'the place decides the area');
        $this->assertSame($place->id, $memory['place']['id']);
        $this->assertStringContainsString('Lara', $memory['place_label']);
        $stored = DB::table('memories')->find($memory['id']);
        $this->assertSame(36.855, (float) $stored->approx_latitude, 'the place centre, snapped to the grid');
        $this->as($this->mert)->getJson('/api/v1/memories/'.$memory['id'])->assertOk();
        $this->as($this->kaan)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();

        $moved = $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'], ['city_id' => $this->alanya])->assertOk()->json('data');
        $this->assertSame('Alanya', $moved['city']['name']);
        $this->assertNull($moved['place']);
    }

    // ---------------------------------------------------------------------------------------------------------------
    // Report / moderation
    // ---------------------------------------------------------------------------------------------------------------

    public function test_visible_memories_can_be_reported_but_not_your_own_or_invisible_ones(): void
    {
        $public = $this->create(['visibility' => 'public']);
        $private = $this->create(['visibility' => 'private']);
        $this->as($this->ece)->postJson('/api/v1/reports', ['target_type' => 'memory', 'target_id' => $public['id'], 'reason' => 'inappropriate'])->assertCreated();
        $this->as($this->ece)->postJson('/api/v1/reports', ['target_type' => 'memory', 'target_id' => $public['id'], 'reason' => 'inappropriate'])->assertOk();
        $this->assertSame(1, DB::table('reports')->where('target_type', 'memory')->count());
        $this->as($this->ece)->postJson('/api/v1/reports', ['target_type' => 'memory', 'target_id' => $private['id'], 'reason' => 'spam'])->assertNotFound();
        $this->as($this->ada)->postJson('/api/v1/reports', ['target_type' => 'memory', 'target_id' => $public['id'], 'reason' => 'spam'])->assertStatus(422);
    }

    public function test_admins_see_the_real_owner_and_reports_remove_and_restore_with_an_audit_trail(): void
    {
        $memory = $this->create(['visibility' => 'followers', 'body' => 'Gizli bir akşam'], [$this->photo()]);
        $this->follow($this->ece, $this->ada);
        $this->as($this->ece)->postJson('/api/v1/reports', ['target_type' => 'memory', 'target_id' => $memory['id'], 'reason' => 'privacy'])->assertCreated();
        $reportId = DB::table('reports')->where('target_type', 'memory')->value('id');

        $admin = Admin::create(['name' => 'Yönetici', 'email' => 'admin@example.test', 'password' => 'Secret1234!', 'role' => 'super_admin']);
        $this->actingAs($admin, 'admin');
        $this->get('/admin/memories')->assertOk()->assertSee('Gizli bir akşam')->assertSee('@ada')->assertSee('1 şikâyet');
        $this->get('/admin/memories?visibility=followers&reported=1')->assertOk()->assertSee('Gizli bir akşam');
        $this->get('/admin/memories?visibility=public')->assertOk()->assertDontSee('Gizli bir akşam');
        $this->get('/admin/memories/'.$memory['id'])->assertOk()->assertSee('Ada Test')->assertSee('@ada')->assertSee('Takipçileri')->assertSee('Şikâyet #'.$reportId);
        $this->get('/admin/reports/'.$reportId)->assertOk()->assertSee('Anıyı incele');
        $mediaId = $memory['media'][0]['id'];
        $this->get('/admin/memory-media/'.$mediaId)->assertOk()->assertHeader('Content-Type', 'image/jpeg');
        $this->assertDatabaseHas('admin_audit_logs', ['action' => 'memory.media_viewed', 'target_type' => 'memory', 'target_id' => $memory['id']]);

        $this->post('/admin/memories/'.$memory['id'].'/moderate', ['action' => 'remove', 'note' => 'Gizlilik ihlali'])->assertRedirect();
        $this->assertDatabaseHas('admin_audit_logs', ['action' => 'memory.remove', 'target_type' => 'memory', 'target_id' => $memory['id']]);
        $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        $this->as($this->ada)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        $this->as($this->ada)->getJson('/api/v1/users/ada/memories')->assertJsonCount(0, 'data.items');
        $this->as($this->ada)->postJson('/api/v1/memories/'.$memory['id'], ['body' => 'Geri alayım'])->assertNotFound();
        $this->as($this->ece)->get($memory['media'][0]['url'])->assertNotFound();
        $this->actingAs($admin, 'admin');
        $this->get('/admin/memories?status=removed')->assertOk()->assertSee('Gizli bir akşam');

        $this->post('/admin/memories/'.$memory['id'].'/moderate', ['action' => 'restore', 'note' => 'Yanlış alarm'])->assertRedirect();
        $this->assertDatabaseHas('admin_audit_logs', ['action' => 'memory.restore', 'target_type' => 'memory', 'target_id' => $memory['id']]);
        $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertOk();
        $this->as($this->ece)->get($memory['media'][0]['url'])->assertOk();

        // The report screen's own "remove content" action works for memories too.
        $this->actingAs($admin, 'admin');
        $this->post('/admin/reports/'.$reportId, ['status' => 'resolved', 'action' => 'remove', 'note' => 'Kaldırıldı'])->assertRedirect();
        $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        $this->assertSame(2, DB::table('admin_audit_logs')->where('action', 'memory.remove')->count());
    }

    public function test_a_moderated_memory_is_purged_with_its_files_after_the_retention_window(): void
    {
        $memory = $this->create([], [$this->photo()]);
        $row = DB::table('memory_media')->find($memory['media'][0]['id']);
        $admin = Admin::create(['name' => 'Yönetici', 'email' => 'admin@example.test', 'password' => 'Secret1234!', 'role' => 'super_admin']);
        $this->actingAs($admin, 'admin');
        $this->post('/admin/memories/'.$memory['id'].'/moderate', ['action' => 'remove'])->assertRedirect();
        Storage::disk('local')->assertExists($row->path);
        $this->assertSame(0, Memory::purgeExpired());
        Carbon::setTestNow(now()->addDays(31));
        $this->assertSame(1, Memory::purgeExpired());
        Storage::disk('local')->assertMissing($row->path);
        Storage::disk('local')->assertMissing($row->thumb_path);
        $this->assertSame(0, DB::table('memory_media')->count());
    }

    // ---------------------------------------------------------------------------------------------------------------
    // Deleting, cleanup, account erasure
    // ---------------------------------------------------------------------------------------------------------------

    public function test_deleting_a_memory_removes_its_files_but_a_reported_one_waits_for_review(): void
    {
        $one = $this->create([], [$this->photo(), $this->photo()]);
        $files = DB::table('memory_media')->where('memory_id', $one['id'])->get()->flatMap(fn ($m) => [$m->path, $m->thumb_path])->all();
        $this->assertCount(4, $files);
        foreach ($files as $file) {
            Storage::disk('local')->assertExists($file);
        }
        $this->as($this->ada)->deleteJson('/api/v1/memories/'.$one['id'])->assertOk();
        foreach ($files as $file) {
            Storage::disk('local')->assertMissing($file);
        }
        $this->assertSame(0, DB::table('memory_media')->count());

        $two = $this->create(['visibility' => 'public'], [$this->photo()]);
        $this->as($this->ece)->postJson('/api/v1/reports', ['target_type' => 'memory', 'target_id' => $two['id'], 'reason' => 'spam'])->assertCreated();
        $kept = DB::table('memory_media')->where('memory_id', $two['id'])->value('path');
        $this->as($this->ada)->deleteJson('/api/v1/memories/'.$two['id'])->assertOk();
        $this->as($this->ece)->getJson('/api/v1/memories/'.$two['id'])->assertNotFound();
        $this->as($this->ece)->get($two['media'][0]['url'])->assertNotFound();
        Storage::disk('local')->assertExists($kept);
        Carbon::setTestNow(now()->addDays(31));
        $this->artisan('memories:purge')->assertExitCode(0);
        Storage::disk('local')->assertMissing($kept);
    }

    public function test_account_deletion_clears_every_memory_and_queues_its_files(): void
    {
        $memory = $this->create(['visibility' => 'public'], [$this->photo(), $this->photo()]);
        $this->create(['body' => 'İkinci']);
        $paths = DB::table('memory_media')->get()->flatMap(fn ($m) => [$m->path, $m->thumb_path])->all();
        $this->assertCount(4, $paths);
        $other = $this->create([], [$this->photo()], $this->ece);

        app(EraseAccount::class)->erase($this->ada->fresh());
        $this->assertSame(0, Memory::withTrashed()->where('user_id', $this->ada->id)->count());
        $this->assertSame(1, DB::table('memory_media')->count(), 'only the other account keeps its photos');
        foreach ($paths as $path) {
            $this->assertDatabaseHas('media_deletions', ['path' => $path]);
        }
        $this->as($this->ece)->getJson('/api/v1/memories/'.$memory['id'])->assertNotFound();
        $this->artisan('media:cleanup')->assertExitCode(0);
        foreach ($paths as $path) {
            Storage::disk('local')->assertMissing($path);
        }
        $this->as($this->ece)->get($other['media'][0]['url'])->assertOk();
    }

    public function test_media_routes_need_a_signed_in_account_and_an_existing_memory(): void
    {
        $memory = $this->create(['visibility' => 'public'], [$this->photo()]);
        $this->app['auth']->forgetGuards();
        $this->flushHeaders();
        $this->get($memory['media'][0]['url'], ['Accept' => 'application/json'])->assertUnauthorized();
        $this->as($this->ece)->get('/api/v1/memory-media/999999')->assertNotFound();
        $this->as($this->ece)->get('/api/v1/memory-media/999999/thumb')->assertNotFound();
    }
}
