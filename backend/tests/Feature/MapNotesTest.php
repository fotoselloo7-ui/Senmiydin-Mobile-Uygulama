<?php

namespace Tests\Feature;

use App\Administration\Settings;
use App\Models\Admin;
use App\Models\City;
use App\Models\MapNote;
use App\Models\MapNoteReply;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class MapNotesTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $alanya;

    private User $ada;

    private User $ece;

    private User $kaan;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-11-14 12:00:00', 'UTC'));
        $this->alanya = City::where('slug', 'alanya')->value('id');
        $this->ada = $this->user('ada');
        $this->ece = $this->user('ece');
        $this->kaan = $this->user('kaan');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function user(string $name, array $extra = []): User
    {
        return User::create(['name' => ucfirst($name).' Test', 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => '1995-01-01', 'password' => 'TestPassword1234', 'city_id' => $this->alanya, ...$extra]);
    }

    private function as(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    private function note(User $user, array $extra = []): array
    {
        $payload = [...['body' => 'Çok güzeldin kırmızı başlıklı kız. Yarın 11:00\'de burada olacağım.', 'is_anonymous' => false,
            'city_id' => $this->alanya, 'latitude' => 36.5446, 'longitude' => 32.0021, 'request_id' => (string) Str::uuid()], ...$extra];

        return $this->as($user)->postJson('/api/v1/map-notes', $payload)->assertCreated()->json('data');
    }

    private function locate(User $user, float $lat, float $lng, ?int $city = null, ?string $at = null): void
    {
        DB::table('user_locations')->upsert([['user_id' => $user->id, 'city_id' => $city ?? $this->alanya, 'latitude' => $lat, 'longitude' => $lng,
            'accuracy' => 20, 'recorded_at' => $at ?? now(), 'visibility' => false, 'created_at' => now(), 'updated_at' => now()]],
            ['user_id'], ['city_id', 'latitude', 'longitude', 'accuracy', 'recorded_at', 'visibility', 'updated_at']);
    }

    public function test_create_note_snaps_to_the_server_grid_expires_in_seven_days_and_never_leaks_the_raw_point(): void
    {
        $response = $this->as($this->ada)->postJson('/api/v1/map-notes', [
            'body' => '  Bugün burada seni gördüm.  ', 'is_anonymous' => false, 'city_id' => $this->alanya,
            'latitude' => 36.5446, 'longitude' => 32.0021,
        ])->assertCreated();
        $data = $response->json('data');
        $this->assertSame('Bugün burada seni gördüm.', $data['body']);
        $this->assertEquals(36.5445, $data['latitude']);
        $this->assertEquals(32.002, $data['longitude']);
        $this->assertSame(now()->addDays(7)->toISOString(), $data['expires_at']);
        $this->assertStringNotContainsString('36.5446', $response->getContent());
        $this->assertStringNotContainsString('32.0021', $response->getContent());
        $row = DB::table('map_notes')->first();
        $this->assertEquals(36.5445, (float) $row->approx_latitude);
        $this->assertEquals(32.002, (float) $row->approx_longitude);
        $this->assertSame(0, DB::table('posts')->count(), 'A map note is never a post.');
        $this->assertSame(0, DB::table('app_notifications')->count());
        // Notes never enter the home feed.
        $this->as($this->ece)->getJson('/api/v1/feed')->assertOk()->assertJsonCount(0, 'data.items');
    }

    public function test_notes_use_their_own_fine_grid_and_stay_within_the_stated_distance_of_the_selected_point(): void
    {
        $grid = (float) config('map_notes.location_grid');
        $this->assertSame(0.0005, $grid);
        $this->assertSame(0.005, (float) config('location.post_grid'), 'Ordinary posts keep their coarse privacy grid.');
        $this->assertNotSame($grid, (float) config('location.post_grid'));

        // The cell is 50-100 m across, measured on real coordinates in Alanya (36.5 N).
        $north = \App\Location\Geo::distance(36.545, 32.0, 36.545 + $grid, 32.0);
        $east = \App\Location\Geo::distance(36.545, 32.0, 36.545, 32.0 + $grid);
        $this->assertGreaterThanOrEqual(50, $north);
        $this->assertLessThanOrEqual(100, $north);
        $this->assertGreaterThanOrEqual(40, $east);
        $this->assertLessThanOrEqual(100, $east);
        // Half a cell diagonally is the worst case the snap can move a selection (~36 m here).
        $worst = hypot($north / 2, $east / 2);
        $this->assertLessThan(40, $worst);

        $this->as($this->ada);
        $checked = 0;
        for ($lat = 36.5301; $lat < 36.5599; $lat += 0.00737) {
            for ($lng = 31.9917; $lng < 32.0199; $lng += 0.00713) {
                $created = $this->postJson('/api/v1/map-notes', ['body' => 'Konum '.$checked, 'city_id' => $this->alanya,
                    'latitude' => $lat, 'longitude' => $lng, 'request_id' => (string) Str::uuid()]);
                if ($created->status() === 429) {
                    $this->flushHeaders();
                    $this->app['cache']->flush();
                    $this->as($this->ada);
                    $created = $this->postJson('/api/v1/map-notes', ['body' => 'Konum '.$checked, 'city_id' => $this->alanya,
                        'latitude' => $lat, 'longitude' => $lng, 'request_id' => (string) Str::uuid()]);
                }
                $created->assertCreated();
                $stored = DB::table('map_notes')->orderByDesc('id')->first();
                $distance = \App\Location\Geo::distance($lat, $lng, (float) $stored->approx_latitude, (float) $stored->approx_longitude);
                $this->assertLessThanOrEqual($worst + 1, $distance, "Selection ({$lat}, {$lng}) moved {$distance} m");
                $this->assertEqualsWithDelta($created->json('data.latitude'), (float) $stored->approx_latitude, 0.000001);
                $this->assertEqualsWithDelta($created->json('data.longitude'), (float) $stored->approx_longitude, 0.000001);
                $this->assertEqualsWithDelta(0.0, fmod(round((float) $stored->approx_latitude / $grid, 6), 1.0), 0.0001);
                $this->assertStringNotContainsString((string) $lat, json_encode($created->json()));
                $checked++;
            }
        }
        $this->assertGreaterThan(10, $checked);
    }

    public function test_the_reported_placement_case_snaps_to_a_nearby_point_where_the_old_grid_moved_it_hundreds_of_metres(): void
    {
        // Real device values from the Pixel 6a reproduction: selected (36.43841, 32.20663).
        [$lat, $lng] = [36.438407, 32.206634];
        $old = [\App\Location\Geo::grid($lat, 0.005), \App\Location\Geo::grid($lng, 0.005)];
        $this->assertSame([36.44, 32.205], $old);
        $oldShift = \App\Location\Geo::distance($lat, $lng, $old[0], $old[1]);
        $this->assertGreaterThan(200, $oldShift, 'The coarse post grid displaced this selection by about 230 m.');

        $data = $this->as($this->ada)->postJson('/api/v1/map-notes', ['body' => 'Yer testi', 'city_id' => $this->alanya,
            'latitude' => $lat, 'longitude' => $lng, 'request_id' => (string) Str::uuid()])->assertCreated()->json('data');
        $this->assertEquals(36.4385, $data['latitude']);
        $this->assertEquals(32.2065, $data['longitude']);
        $this->assertSame('36.43850_32.20650', $data['group']);
        $this->assertLessThan(25, \App\Location\Geo::distance($lat, $lng, $data['latitude'], $data['longitude']));

        $markers = $this->getJson('/api/v1/map/notes?city_id='.$this->alanya)->assertOk()->json('data.items');
        $this->assertCount(1, $markers);
        $this->assertSame($data['group'], $markers[0]['group']);
        $this->assertEquals($data['latitude'], $markers[0]['latitude']);
        $this->assertEquals($data['longitude'], $markers[0]['longitude']);
        $this->getJson('/api/v1/map/notes/'.$data['group'])->assertOk()->assertJsonPath('data.items.0.id', $data['id']);
    }

    public function test_grouping_follows_the_fine_grid_and_notes_stored_on_the_old_coarse_grid_keep_working(): void
    {
        // Two selections inside one cell, one in the neighbouring cell.
        $this->note($this->ada, ['latitude' => 36.54510, 'longitude' => 32.00110]);
        $this->note($this->ece, ['latitude' => 36.54520, 'longitude' => 32.00120]);
        $this->note($this->ece, ['latitude' => 36.54610, 'longitude' => 32.00110]);
        // A note created before this change sits on a multiple of the old 0.005 grid.
        DB::table('map_notes')->insert(['user_id' => $this->kaan->id, 'city_id' => $this->alanya, 'body' => 'Eski ızgara',
            'is_anonymous' => false, 'approx_latitude' => 36.555, 'approx_longitude' => 32.005, 'place_label' => 'Alanya · Yaklaşık bölge',
            'expires_at' => now()->addDays(7), 'created_at' => now(), 'updated_at' => now()]);

        $items = collect($this->as($this->kaan)->getJson('/api/v1/map/notes?city_id='.$this->alanya)->assertOk()->json('data.items'))->keyBy('group');
        $this->assertCount(3, $items);
        $this->assertSame(2, $items['36.54500_32.00100']['count']);
        $this->assertSame(1, $items['36.54600_32.00100']['count']);
        $this->assertSame(1, $items['36.55500_32.00500']['count']);
        $this->getJson('/api/v1/map/notes/36.54500_32.00100')->assertJsonPath('data.count', 2)->assertJsonCount(2, 'data.items');
        $this->getJson('/api/v1/map/notes/36.55500_32.00500')->assertJsonPath('data.count', 1);
        $this->assertSame(['moment', 'confession', 'thought', 'travel', 'encounter'], \App\Models\Post::TYPES);
    }

    public function test_validation_empty_long_and_wrong_city_are_rejected_with_user_language(): void
    {
        $this->as($this->ada)->postJson('/api/v1/map-notes', ['body' => '   ', 'city_id' => $this->alanya, 'latitude' => 36.54, 'longitude' => 32.0])
            ->assertUnprocessable()->assertJsonValidationErrors('body');
        $this->postJson('/api/v1/map-notes', ['body' => str_repeat('a', 701), 'city_id' => $this->alanya, 'latitude' => 36.54, 'longitude' => 32.0])
            ->assertUnprocessable()->assertJsonValidationErrors('body');
        $this->postJson('/api/v1/map-notes', ['body' => str_repeat('a', 700), 'city_id' => $this->alanya, 'latitude' => 36.54, 'longitude' => 32.0, 'request_id' => (string) Str::uuid()])
            ->assertCreated();
        // Ankara coordinates with Alanya selected.
        $this->postJson('/api/v1/map-notes', ['body' => 'Yanlış şehir', 'city_id' => $this->alanya, 'latitude' => 39.9208, 'longitude' => 32.8541])
            ->assertUnprocessable()->assertJsonValidationErrors('latitude')
            ->assertJsonPath('errors.latitude.0', 'Seçtiğin nokta bu şehirde görünmüyor. Haritada şehrinin içinde bir yer seç.');
        $this->postJson('/api/v1/map-notes', ['body' => 'Hatalı koordinat', 'city_id' => $this->alanya, 'latitude' => 120, 'longitude' => 32])->assertUnprocessable();
        $this->assertSame(1, DB::table('map_notes')->count());
    }

    public function test_request_id_makes_create_and_reply_idempotent(): void
    {
        $id = (string) Str::uuid();
        $first = $this->note($this->ada, ['request_id' => $id]);
        $again = $this->as($this->ada)->postJson('/api/v1/map-notes', ['body' => 'Aynı istek', 'city_id' => $this->alanya,
            'latitude' => 36.5446, 'longitude' => 32.0021, 'request_id' => $id])->assertOk()->json('data');
        $this->assertSame($first['id'], $again['id']);
        $this->assertSame(1, DB::table('map_notes')->count());
        $reply = (string) Str::uuid();
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$first['id'].'/replies', ['body' => 'Merhaba', 'request_id' => $reply])->assertCreated();
        $this->postJson('/api/v1/map-notes/'.$first['id'].'/replies', ['body' => 'Merhaba', 'request_id' => $reply])->assertCreated();
        $this->assertSame(1, DB::table('map_note_replies')->count());
        $this->assertSame(1, DB::table('app_notifications')->where('type', 'map_note_reply')->count());
    }

    public function test_open_notes_show_the_author_without_private_profile_fields_and_anonymous_notes_leak_nothing(): void
    {
        $open = $this->note($this->ada);
        $anonymous = $this->note($this->ada, ['is_anonymous' => true, 'body' => 'Belki bir gün tekrar görüşürüz.', 'latitude' => 36.5601]);
        $this->as($this->ece);
        $shown = $this->getJson('/api/v1/map-notes/'.$open['id'])->assertOk()->json('data.note');
        $this->assertSame('ada', $shown['author']['username']);
        foreach (['city', 'interests', 'occupation_school', 'email'] as $field) {
            $this->assertArrayNotHasKey($field, $shown['author']);
        }
        $this->assertFalse($shown['mine']);

        $response = $this->getJson('/api/v1/map-notes/'.$anonymous['id'])->assertOk();
        $note = $response->json('data.note');
        $this->assertNull($note['author']);
        $this->assertTrue($note['is_anonymous']);
        foreach (['user_id', 'username', 'name', 'avatar', 'email'] as $key) {
            $this->assertArrayNotHasKey($key, $note);
        }
        foreach (['ada', 'Ada Test', 'ada@example.test'] as $needle) {
            $this->assertStringNotContainsString($needle, $response->getContent());
        }
        $point = $this->getJson('/api/v1/map/notes/36.56000_32.00200')->assertOk();
        foreach (['ada', 'Ada Test', 'user_id'] as $needle) {
            $this->assertStringNotContainsString($needle, $point->getContent());
        }
        $this->assertTrue($this->as($this->ada)->getJson('/api/v1/map-notes/'.$anonymous['id'])->json('data.note.mine'));
    }

    public function test_map_groups_notes_by_approximate_grid_point_and_lists_them_newest_first_with_pagination(): void
    {
        foreach ([[36.54510, 32.00110], [36.54520, 32.00120], [36.54490, 32.00090]] as $i => [$lat, $lng]) {
            Carbon::setTestNow(now()->addMinutes(5));
            $this->note($i % 2 ? $this->ece : $this->ada, ['latitude' => $lat, 'longitude' => $lng, 'body' => 'Not '.($i + 1)]);
        }
        $this->note($this->kaan, ['latitude' => 36.6021, 'longitude' => 32.1019, 'body' => 'Uzak not']);

        $map = $this->as($this->ece)->getJson('/api/v1/map/notes?city_id='.$this->alanya)->assertOk()->json('data');
        $this->assertFalse($map['location_required']);
        $this->assertCount(2, $map['items']);
        $groups = collect($map['items'])->keyBy('group');
        $this->assertSame(3, $groups['36.54500_32.00100']['count']);
        $this->assertSame(1, $groups['36.60200_32.10200']['count']);
        foreach ($map['items'] as $marker) {
            $this->assertEqualsCanonicalizing(['group', 'latitude', 'longitude', 'count', 'newest_at', 'distance_meters'], array_keys($marker));
        }
        $this->assertStringNotContainsString('36.5441', json_encode($map));

        $page = $this->getJson('/api/v1/map/notes/36.54500_32.00100')->assertOk()->json('data');
        $this->assertSame(3, $page['count']);
        $this->assertSame(['Not 3', 'Not 2', 'Not 1'], array_column($page['items'], 'body'));
        $this->assertNull($page['next_page']);

        // 25 notes at the same point: 20 per page, newest first, stable across pages.
        for ($i = 4; $i <= 25; $i++) {
            Carbon::setTestNow(now()->addMinute());
            DB::table('map_notes')->insert(['user_id' => $this->ada->id, 'city_id' => $this->alanya, 'body' => 'Not '.$i, 'is_anonymous' => false,
                'approx_latitude' => 36.545, 'approx_longitude' => 32.001, 'place_label' => 'Alanya · Yaklaşık bölge',
                'expires_at' => now()->addDays(7), 'created_at' => now(), 'updated_at' => now()]);
        }
        $first = $this->getJson('/api/v1/map/notes/36.54500_32.00100')->json('data');
        $this->assertCount(20, $first['items']);
        $this->assertSame(25, $first['count']);
        $this->assertSame(2, $first['next_page']);
        $this->assertSame('Not 25', $first['items'][0]['body']);
        $second = $this->getJson('/api/v1/map/notes/36.54500_32.00100?page=2')->json('data');
        $this->assertCount(5, $second['items']);
        $this->assertNull($second['next_page']);
        $this->assertSame('Not 1', $second['items'][4]['body']);
        $this->getJson('/api/v1/map/notes/not-a-group')->assertNotFound();
    }

    public function test_map_radius_filter_matches_the_existing_map_behaviour(): void
    {
        $this->note($this->ada, ['latitude' => 36.545, 'longitude' => 32.0]);
        $this->note($this->ada, ['latitude' => 36.62, 'longitude' => 32.15]);
        $this->locate($this->ece, 36.544, 32.0);
        $this->as($this->ece);
        $this->getJson('/api/v1/map/notes?radius=5000')->assertOk()->assertJsonCount(1, 'data.items');
        $this->getJson('/api/v1/map/notes?city_id='.$this->alanya)->assertJsonCount(2, 'data.items');
        $this->getJson('/api/v1/map/notes?radius=5000&use_location=0')->assertJsonPath('data.location_required', true);
    }

    public function test_notes_expire_exactly_seven_days_after_creation_and_replies_never_extend_it(): void
    {
        $note = $this->note($this->ada);
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Notunu aldım.'])->assertCreated();
        $this->as($this->ece);

        Carbon::setTestNow(Carbon::parse('2026-11-21 11:59:00', 'UTC'));
        $this->getJson('/api/v1/map/notes?city_id='.$this->alanya)->assertJsonCount(1, 'data.items');
        $this->getJson('/api/v1/map-notes/'.$note['id'])->assertOk()->assertJsonPath('data.note.can_reply', true);
        // A reply 1 minute before the deadline does not push it back.
        $this->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Son dakika.'])->assertCreated();

        Carbon::setTestNow(Carbon::parse('2026-11-21 12:00:01', 'UTC'));
        $this->getJson('/api/v1/map/notes?city_id='.$this->alanya)->assertJsonCount(0, 'data.items');
        $this->getJson('/api/v1/map/notes/36.54450_32.00200')->assertOk()->assertJsonCount(0, 'data.items');
        $this->getJson('/api/v1/map-notes/'.$note['id'])->assertNotFound();
        $this->getJson('/api/v1/map-notes/'.$note['id'].'/replies')->assertNotFound();
        $this->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Çok geç.'])
            ->assertUnprocessable()->assertJsonPath('errors.body.0', 'Bu not artık yanıt kabul etmiyor.');
        $this->assertSame(2, DB::table('map_note_replies')->count());
    }

    public function test_expiry_never_destroys_the_owners_archive_but_removed_rows_are_purged_after_the_retention_window(): void
    {
        $registered = collect(app(\Illuminate\Console\Scheduling\Schedule::class)->events())
            ->first(fn ($event) => str_contains($event->command, 'map-notes:purge'));
        $this->assertNotNull($registered, 'map-notes:purge must be scheduled.');
        $this->assertSame('0 0 * * *', $registered->expression);

        $old = $this->note($this->ada);
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$old['id'].'/replies', ['body' => 'Eski not cevabı'])->assertCreated();
        $moderated = $this->note($this->ada, ['request_id' => (string) Str::uuid()]);
        MapNote::whereKey($moderated['id'])->update(['moderated_at' => now()]);
        Carbon::setTestNow(now()->addDays(8));
        $fresh = $this->note($this->ada, ['request_id' => (string) Str::uuid()]);
        $this->artisan('map-notes:purge')->assertExitCode(0);
        $this->assertNotNull(MapNote::withTrashed()->find($old['id']));

        // Months later: the expired letter and its thread are still the owner's (public visibility is a separate rule).
        Carbon::setTestNow(now()->addDays(config('map_notes.retention_days') + 90));
        $this->artisan('map-notes:purge')->assertExitCode(0);
        $this->assertNotNull(MapNote::withTrashed()->find($old['id']), 'An expired letter lives on in Mektuplarım → Arşiv.');
        $this->assertSame(1, DB::table('map_note_replies')->count(), 'Its replies are kept as history.');
        $this->assertNull(MapNote::withTrashed()->find($moderated['id']), 'Moderation rows still leave after the audit window.');
        $this->assertNotNull(MapNote::withTrashed()->find($fresh['id']));
        $this->assertSame(0, $this->as($this->ece)->getJson('/api/v1/map/notes?city_id='.$this->alanya)->json('data.items.0.count') ?? 0, 'Never public again after expiry.');
    }

    public function test_replies_are_single_level_oldest_first_open_or_anonymous_and_notify_the_owner_without_identity(): void
    {
        $note = $this->note($this->ada, ['is_anonymous' => true]);
        $order = [];
        foreach ([[$this->ece, 'O kişi bendim.', false], [$this->kaan, 'Ciddi misin? :)', true], [$this->ece, 'Evet.', true]] as $i => [$user, $body, $anonymous]) {
            Carbon::setTestNow(now()->addMinutes(7));
            $this->as($user)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => $body, 'is_anonymous' => $anonymous])
                ->assertCreated()->assertJsonPath('data.is_anonymous', $anonymous);
            $order[] = $body;
        }
        $detail = $this->as($this->kaan)->getJson('/api/v1/map-notes/'.$note['id'])->assertOk()->assertJsonPath('data.note.reply_count', 3);
        $replies = $detail->json('data.replies.items');
        $this->assertSame($order, array_column($replies, 'body'), 'Oldest to newest, like a conversation.');
        $this->assertSame('ece', $replies[0]['author']['username']);
        $this->assertNull($replies[1]['author']);
        $this->assertNull($replies[2]['author']);
        $this->assertTrue($replies[1]['mine']);
        $this->assertFalse($replies[2]['mine']);
        foreach ([1, 2] as $i) {
            foreach (['user_id', 'username', 'name', 'avatar'] as $key) {
                $this->assertArrayNotHasKey($key, $replies[$i]);
            }
        }
        $this->assertStringNotContainsString('kaan', json_encode(array_slice($replies, 1, 1)));

        // The owner of an anonymous note can reply but is never unmasked; the thread only says the author wrote it.
        $own = $this->as($this->ada)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Sen kimsin?', 'is_anonymous' => false])
            ->assertCreated()->json('data');
        $this->assertNull($own['author']);
        $this->assertTrue($own['is_anonymous']);
        $this->assertTrue($own['from_note_author']);
        $this->assertStringNotContainsString('ada', json_encode($own));

        // Owner notification: one per foreign reply, anonymous or not, no actor, same target.
        $inbox = $this->as($this->ada)->getJson('/api/v1/notifications')->assertOk()->json('data.items');
        $this->assertCount(3, $inbox);
        foreach ($inbox as $item) {
            $this->assertSame('map_note_reply', $item['type']);
            $this->assertSame('/map-note', $item['route']);
            $this->assertSame($note['id'], $item['entity_id']);
            $this->assertNull($item['actor']);
            $this->assertSame('Notuna bir cevap geldi.', $item['text']);
            $this->assertTrue($item['available']);
            $this->assertStringNotContainsString('kaan', json_encode($item));
        }
        $this->assertSame(0, DB::table('app_notifications')->where('user_id', $this->kaan->id)->count());
        // Nested replies do not exist.
        $this->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'x', 'parent_id' => 1])->assertCreated();
        $this->assertSame(0, \Illuminate\Support\Facades\Schema::hasColumn('map_note_replies', 'parent_id') ? 1 : 0);
    }

    public function test_reply_validation_pagination_and_own_deletion(): void
    {
        $note = $this->note($this->ada);
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => ''])->assertUnprocessable();
        $this->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => str_repeat('b', 501)])->assertUnprocessable();
        for ($i = 1; $i <= 22; $i++) {
            Carbon::setTestNow(now()->addMinute());
            DB::table('map_note_replies')->insert(['map_note_id' => $note['id'], 'user_id' => $this->kaan->id, 'body' => 'Yanıt '.$i,
                'is_anonymous' => false, 'created_at' => now(), 'updated_at' => now()]);
        }
        $first = $this->getJson('/api/v1/map-notes/'.$note['id'].'/replies')->json('data');
        $this->assertCount(20, $first['items']);
        $this->assertSame(2, $first['next_page']);
        $this->assertSame('Yanıt 1', $first['items'][0]['body']);
        $second = $this->getJson('/api/v1/map-notes/'.$note['id'].'/replies?page=2')->json('data');
        $this->assertSame(['Yanıt 21', 'Yanıt 22'], array_column($second['items'], 'body'));

        $mine = $this->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Benim cevabım'])->json('data.id');
        $this->as($this->kaan)->deleteJson('/api/v1/map-note-replies/'.$mine)->assertForbidden();
        $this->as($this->ece)->deleteJson('/api/v1/map-note-replies/'.$mine)->assertOk();
        $this->assertNull(MapNoteReply::find($mine));
        $this->getJson('/api/v1/map-notes/'.$note['id'])->assertJsonPath('data.note.reply_count', 22);
    }

    public function test_only_the_owner_deletes_a_note_and_deleted_notes_leave_the_map_and_their_notifications_become_unavailable(): void
    {
        $note = $this->note($this->ada);
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Cevap'])->assertCreated();
        $this->as($this->ece)->deleteJson('/api/v1/map-notes/'.$note['id'])->assertForbidden();
        $this->assertNotNull(MapNote::find($note['id']));
        $this->as($this->ada);
        $this->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.available', true);
        $this->deleteJson('/api/v1/map-notes/'.$note['id'])->assertOk();
        $this->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.available', false);
        $this->as($this->kaan);
        $this->getJson('/api/v1/map/notes?city_id='.$this->alanya)->assertJsonCount(0, 'data.items');
        $this->getJson('/api/v1/map-notes/'.$note['id'])->assertNotFound();
        $this->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Silinmiş nota'])->assertNotFound();
        $this->getJson('/api/v1/map-notes/'.$note['id'].'/replies')->assertNotFound();
        $this->assertSame(404, $this->as($this->ada)->deleteJson('/api/v1/map-notes/999999')->status());
    }

    public function test_nearby_notification_is_sent_once_to_eligible_users_inside_the_central_radius_only(): void
    {
        $inside = $this->user('inside');
        $outside = $this->user('outside');
        $otherCity = $this->user('ankara', ['city_id' => City::where('slug', 'ankara')->value('id')]);
        $optedOut = $this->user('optedout', ['push_preferences' => ['map_note_nearby' => false]]);
        $stale = $this->user('stale');
        $blocker = $this->user('blocker');
        $suspended = $this->user('suspended');
        $suspended->forceFill(['account_status' => 'suspended'])->save();
        $noHistory = $this->user('nohistory', ['location_history_enabled' => false]);
        $this->assertSame(1000, config('map_notes.nearby_notification_meters'));
        $this->locate($inside, 36.5470, 32.0010);
        $this->locate($noHistory, 36.5455, 32.0010);
        $this->locate($optedOut, 36.5460, 32.0000);
        $this->locate($blocker, 36.5450, 32.0000);
        $this->locate($suspended, 36.5450, 32.0000);
        $this->locate($outside, 36.5700, 32.0300);
        $this->locate($otherCity, 36.5450, 32.0000, City::where('slug', 'ankara')->value('id'));
        $this->locate($stale, 36.5450, 32.0000, null, now()->subHours(2)->toDateTimeString());
        $this->locate($this->ada, 36.5450, 32.0000);
        DB::table('user_blocks')->insert(['blocker_id' => $blocker->id, 'blocked_id' => $this->ada->id, 'created_at' => now()]);

        $note = $this->note($this->ada, ['is_anonymous' => true]);
        $notified = DB::table('app_notifications')->where('type', 'map_note_nearby')->orderBy('user_id')->pluck('user_id')->all();
        $this->assertEqualsCanonicalizing([$inside->id, $noHistory->id], $notified);
        $this->assertSame(0, DB::table('app_notifications')->where('user_id', $this->ada->id)->count(), 'No self notification.');

        $item = $this->as($inside)->getJson('/api/v1/notifications')->assertOk()->json('data.items.0');
        $this->assertSame('map_note_nearby', $item['type']);
        $this->assertSame('Yakınına bir not bırakıldı.', $item['text']);
        $this->assertSame('Birisi bulunduğun bölgede dijital bir not bıraktı.', $item['subtitle']);
        $this->assertSame('/map-note', $item['route']);
        $this->assertSame($note['id'], $item['entity_id']);
        $this->assertNull($item['actor']);
        $this->assertTrue($item['available']);
        foreach (['ada', 'latitude', 'longitude', '36.54', 'user_id'] as $needle) {
            $this->assertStringNotContainsString($needle, json_encode($item));
        }

        // Once only: map opens, location updates, replies and a repeated create request never notify again.
        $count = DB::table('app_notifications')->where('type', 'map_note_nearby')->count();
        $this->as($inside)->getJson('/api/v1/map/notes?city_id='.$this->alanya)->assertOk();
        $this->putJson('/api/v1/location', ['latitude' => 36.547, 'longitude' => 32.001, 'accuracy' => 20])->assertOk();
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Cevap'])->assertCreated();
        $this->as($this->ada)->postJson('/api/v1/map-notes', ['body' => 'x', 'city_id' => $this->alanya, 'latitude' => 36.5446,
            'longitude' => 32.0021, 'request_id' => DB::table('map_notes')->value('request_id')])->assertOk();
        $this->assertSame($count, DB::table('app_notifications')->where('type', 'map_note_nearby')->count());
    }

    public function test_nearby_radius_comes_from_central_config_and_notification_preferences_can_be_changed_in_profile(): void
    {
        $near = $this->user('near');
        $mid = $this->user('mid');
        $this->locate($near, 36.5450, 32.0000);
        $this->locate($mid, 36.5500, 32.0000); // ~550 m from the snapped point
        config(['map_notes.nearby_notification_meters' => 300]);
        $this->note($this->ada, ['request_id' => (string) Str::uuid()]);
        $this->assertSame([$near->id], DB::table('app_notifications')->where('type', 'map_note_nearby')->pluck('user_id')->all());
        config(['map_notes.nearby_notification_meters' => 1000]);
        $this->note($this->ada, ['request_id' => (string) Str::uuid(), 'latitude' => 36.5451]);
        $this->assertSame(1, DB::table('app_notifications')->where('user_id', $mid->id)->count());

        $profile = $this->as($near)->getJson('/api/v1/profile')->assertOk()
            ->assertJsonPath('data.push_preferences.map_note_nearby', true)->assertJsonPath('data.push_preferences.map_note_reply', true);
        $this->assertSame(true, $profile->json('data.push_preferences.map_note_nearby'));
        $this->putJson('/api/v1/profile', ['push_preferences' => ['map_note_nearby' => false]])->assertOk()
            ->assertJsonPath('data.push_preferences.map_note_nearby', false)->assertJsonPath('data.push_preferences.map_note_reply', true);
        $before = DB::table('app_notifications')->where('user_id', $near->id)->count();
        $this->as($this->ada)->postJson('/api/v1/map-notes', ['body' => 'Üçüncü', 'city_id' => $this->alanya, 'latitude' => 36.5451,
            'longitude' => 32.0, 'request_id' => (string) Str::uuid()])->assertCreated();
        $this->assertSame($before, DB::table('app_notifications')->where('user_id', $near->id)->count());
        // The reply notification has its own switch.
        $this->as($near)->putJson('/api/v1/profile', ['push_preferences' => ['map_note_reply' => false]])->assertOk();
        $mine = $this->note($near, ['request_id' => (string) Str::uuid()]);
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$mine['id'].'/replies', ['body' => 'Cevap'])->assertCreated();
        $this->assertSame(0, DB::table('app_notifications')->where('user_id', $near->id)->where('type', 'map_note_reply')->count());
    }

    public function test_block_hides_notes_replies_and_notifications_both_ways_and_unblock_restores_normal_behaviour(): void
    {
        $note = $this->note($this->ada);
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Ece cevabı'])->assertCreated();
        $this->as($this->kaan)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Kaan cevabı', 'is_anonymous' => true])->assertCreated();
        $this->assertSame(2, DB::table('app_notifications')->where('user_id', $this->ada->id)->count());
        $ecesNote = $this->note($this->ece, ['latitude' => 36.60, 'longitude' => 32.10]);

        $this->as($this->ada)->putJson('/api/v1/blocks/'.$this->ece->id)->assertOk();
        // Ada no longer sees Ece's reply or note, nor Ece's notification.
        $this->getJson('/api/v1/map-notes/'.$ecesNote['id'])->assertNotFound();
        $this->assertSame(['Kaan cevabı'], array_column($this->getJson('/api/v1/map-notes/'.$note['id'])->json('data.replies.items'), 'body'));
        $this->getJson('/api/v1/map-notes/'.$note['id'])->assertJsonPath('data.note.reply_count', 1);
        $this->assertCount(1, $this->getJson('/api/v1/map/notes?city_id='.$this->alanya)->json('data.items'));
        $this->assertCount(1, $this->getJson('/api/v1/notifications')->json('data.items'));
        // Ece no longer sees Ada's note, cannot reply, cannot report it.
        $this->as($this->ece);
        $this->getJson('/api/v1/map-notes/'.$note['id'])->assertNotFound();
        $this->getJson('/api/v1/map/notes/36.54450_32.00200')->assertJsonCount(0, 'data.items');
        $this->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Yine de'])->assertNotFound();
        $this->postJson('/api/v1/reports', ['target_type' => 'map_note', 'target_id' => $note['id'], 'reason' => 'spam'])->assertNotFound();
        // A third party still sees both.
        $this->as($this->kaan)->getJson('/api/v1/map-notes/'.$note['id'])->assertJsonPath('data.note.reply_count', 2);
        // Blocked users do not receive nearby notifications.
        $this->locate($this->ece, 36.545, 32.0);
        $this->note($this->ada, ['request_id' => (string) Str::uuid(), 'body' => 'Yeni not']);
        $this->assertSame(0, DB::table('app_notifications')->where('user_id', $this->ece->id)->where('type', 'map_note_nearby')->count());

        $this->as($this->ada)->deleteJson('/api/v1/blocks/'.$this->ece->id)->assertOk();
        $this->getJson('/api/v1/map-notes/'.$ecesNote['id'])->assertOk();
        $this->assertCount(2, $this->getJson('/api/v1/map-notes/'.$note['id'])->json('data.replies.items'));
        $this->as($this->ece)->getJson('/api/v1/map-notes/'.$note['id'])->assertOk();
    }

    public function test_content_guard_rejects_banned_terms_links_and_duplicates_for_notes_and_replies(): void
    {
        app(Settings::class)->save(['moderation_banned_words' => "yasakli\nkufurlu", 'moderation_max_links' => 1, 'moderation_comment_repeats' => 2]);
        $this->as($this->ada);
        $make = fn (string $body, string $at = '36.5446') => $this->postJson('/api/v1/map-notes', ['body' => $body, 'city_id' => $this->alanya,
            'latitude' => (float) $at, 'longitude' => 32.0021, 'request_id' => (string) Str::uuid()]);
        $make('Bu bir yasakli kelime içeriyor')->assertUnprocessable()->assertJsonValidationErrors('body');
        $make('Bakın https://a.example ve https://b.example')->assertUnprocessable()->assertJsonValidationErrors('body');
        $make('Aynı not')->assertCreated();
        $make('aynı   NOT')->assertCreated();
        $make('Aynı not')->assertUnprocessable()->assertJsonValidationErrors('body');
        $note = DB::table('map_notes')->value('id');
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note.'/replies', ['body' => 'kufurlu bir cevap'])->assertUnprocessable()->assertJsonValidationErrors('body');
        $this->postJson('/api/v1/map-notes/'.$note.'/replies', ['body' => 'Tekrar'])->assertCreated();
        $this->postJson('/api/v1/map-notes/'.$note.'/replies', ['body' => 'Tekrar'])->assertCreated();
        $this->postJson('/api/v1/map-notes/'.$note.'/replies', ['body' => 'Tekrar'])->assertUnprocessable();
    }

    public function test_note_creation_and_replies_are_rate_limited(): void
    {
        $this->as($this->ada);
        for ($i = 1; $i <= 8; $i++) {
            $this->postJson('/api/v1/map-notes', ['body' => 'Not numarası '.$i, 'city_id' => $this->alanya, 'latitude' => 36.5446, 'longitude' => 32.0021])->assertCreated();
        }
        $this->postJson('/api/v1/map-notes', ['body' => 'Dokuzuncu not', 'city_id' => $this->alanya, 'latitude' => 36.5446, 'longitude' => 32.0021])->assertStatus(429);
        $note = DB::table('map_notes')->value('id');
        $this->as($this->ece);
        for ($i = 1; $i <= 10; $i++) {
            $this->postJson('/api/v1/map-notes/'.$note.'/replies', ['body' => 'Yanıt numarası '.$i])->assertCreated();
        }
        $this->postJson('/api/v1/map-notes/'.$note.'/replies', ['body' => 'Fazla hızlı yanıt'])->assertStatus(429);
    }

    public function test_reports_cover_notes_and_replies_but_never_your_own_content_and_admin_sees_the_real_owner(): void
    {
        $note = $this->note($this->ada, ['is_anonymous' => true]);
        $reply = $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Anonim cevap', 'is_anonymous' => true])->json('data.id');
        $this->postJson('/api/v1/reports', ['target_type' => 'map_note', 'target_id' => $note['id'], 'reason' => 'harassment'])->assertCreated();
        $this->postJson('/api/v1/reports', ['target_type' => 'map_note', 'target_id' => $note['id'], 'reason' => 'harassment'])->assertOk();
        $this->as($this->ada)->postJson('/api/v1/reports', ['target_type' => 'map_note_reply', 'target_id' => $reply, 'reason' => 'spam'])->assertCreated();
        $this->postJson('/api/v1/reports', ['target_type' => 'map_note', 'target_id' => $note['id'], 'reason' => 'spam'])->assertUnprocessable();
        $this->as($this->ece)->postJson('/api/v1/reports', ['target_type' => 'map_note_reply', 'target_id' => $reply, 'reason' => 'spam'])->assertUnprocessable();
        $this->postJson('/api/v1/reports', ['target_type' => 'map_note_reply', 'target_id' => 999999, 'reason' => 'spam'])->assertNotFound();
        $this->assertSame(2, DB::table('reports')->count());

        $admin = Admin::create(['name' => 'Yönetici', 'email' => 'admin@example.test', 'password' => 'Secret1234!', 'role' => 'super_admin']);
        $this->actingAs($admin, 'admin');
        $reportId = DB::table('reports')->where('target_type', 'map_note')->value('id');
        $this->get('/admin/reports/'.$reportId)->assertOk()->assertSee('Çok güzeldin')->assertSee('Ada Test')->assertSee('Notu incele');
        $replyReport = DB::table('reports')->where('target_type', 'map_note_reply')->value('id');
        $this->get('/admin/reports/'.$replyReport)->assertOk()->assertSee('Anonim cevap')->assertSee('Ece Test');
    }

    public function test_admin_sees_anonymous_owners_removes_notes_and_replies_with_audit_and_the_map_updates(): void
    {
        $anonymous = $this->note($this->ada, ['is_anonymous' => true]);
        $second = $this->note($this->kaan, ['request_id' => (string) Str::uuid(), 'body' => 'İkinci not']);
        $reply = $this->as($this->ece)->postJson('/api/v1/map-notes/'.$anonymous['id'].'/replies', ['body' => 'Gizli cevap', 'is_anonymous' => true])->json('data.id');
        $publicView = $this->getJson('/api/v1/map-notes/'.$anonymous['id'])->assertOk()->getContent();
        $this->assertStringNotContainsString('Ada Test', $publicView);
        $this->assertStringNotContainsString('Ece Test', $publicView);
        $this->assertCount(1, $this->getJson('/api/v1/map/notes?city_id='.$this->alanya)->json('data.items') ?? []);

        $admin = Admin::create(['name' => 'Yönetici', 'email' => 'admin@example.test', 'password' => 'Secret1234!', 'role' => 'super_admin']);
        $this->actingAs($admin, 'admin');
        $this->get('/admin/map-notes')->assertOk()->assertSee('Çok güzeldin')->assertSee('Anonim')->assertSee('İkinci not');
        $this->get('/admin/map-notes?status=active&anonymous=1')->assertOk()->assertSee('Çok güzeldin')->assertDontSee('İkinci not');
        $this->get('/admin/map-notes/'.$anonymous['id'])->assertOk()->assertSee('Ada Test')->assertSee('@ada')->assertSee('Ece Test')->assertSee('ANONİM');
        $this->get('/admin')->assertOk()->assertSee('Aktif harita notu');

        $this->post('/admin/map-note-replies/'.$reply.'/moderate', ['action' => 'remove', 'note' => 'Uygunsuz'])->assertRedirect();
        $this->assertNotNull(MapNoteReply::withTrashed()->find($reply)->moderated_at);
        $this->as($this->kaan)->getJson('/api/v1/map-notes/'.$anonymous['id'])->assertJsonPath('data.note.reply_count', 0);
        $this->actingAs($admin, 'admin');
        $this->post('/admin/map-notes/'.$anonymous['id'].'/moderate', ['action' => 'remove', 'note' => 'Kaldırıldı'])->assertRedirect();
        $this->as($this->kaan);
        $this->getJson('/api/v1/map-notes/'.$anonymous['id'])->assertNotFound();
        $map = $this->getJson('/api/v1/map/notes?city_id='.$this->alanya)->json('data.items');
        $this->assertCount(1, $map);
        $this->assertSame(1, $map[0]['count']);
        $this->assertDatabaseHas('admin_audit_logs', ['action' => 'map_note.remove', 'target_type' => 'map_note', 'target_id' => $anonymous['id']]);
        $this->assertDatabaseHas('admin_audit_logs', ['action' => 'map_note_reply.remove', 'target_type' => 'map_note_reply', 'target_id' => $reply]);
        $this->actingAs($admin, 'admin');
        $this->get('/admin/map-notes?status=removed')->assertOk()->assertSee('Çok güzeldin');
        $this->get('/admin/audit')->assertOk()->assertSee('Harita notu · kaldırıldı');
        $this->post('/admin/map-notes/'.$anonymous['id'].'/moderate', ['action' => 'restore'])->assertRedirect();
        $this->as($this->kaan)->getJson('/api/v1/map-notes/'.$anonymous['id'])->assertOk();
    }

    public function test_account_erasure_and_suspension_remove_notes_and_replies_from_public_view(): void
    {
        $note = $this->note($this->ada);
        $theirs = $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Cevap'])->json('data.id');
        $this->as($this->kaan)->getJson('/api/v1/map-notes/'.$note['id'])->assertOk()->assertJsonPath('data.note.reply_count', 1);
        $this->ece->forceFill(['account_status' => 'suspended'])->save();
        $this->getJson('/api/v1/map-notes/'.$note['id'])->assertJsonPath('data.note.reply_count', 0);
        $this->ece->forceFill(['account_status' => 'active'])->save();
        $this->as($this->ada)->deleteJson('/api/v1/auth/account', ['password' => 'TestPassword1234', 'confirmation' => 'SİL'])->assertOk();
        $this->as($this->kaan)->getJson('/api/v1/map-notes/'.$note['id'])->assertNotFound();
        $this->getJson('/api/v1/map/notes?city_id='.$this->alanya)->assertJsonCount(0, 'data.items');
        $this->assertSame('', MapNote::withTrashed()->find($note['id'])->body);
        $this->assertNotNull($theirs);
    }

    public function test_notification_types_are_registered_with_default_on_preferences_and_a_note_route(): void
    {
        $this->assertTrue(\App\Notifications\Inbox::DEFAULTS['map_note_nearby']);
        $this->assertTrue(\App\Notifications\Inbox::DEFAULTS['map_note_reply']);
        $this->assertSame('/map-note', \App\Notifications\Inbox::TYPES['map_note_nearby'][0]);
        $this->assertSame('/map-note', \App\Notifications\Inbox::TYPES['map_note_reply'][0]);
        // Separate from the history-based recommendation categories.
        $this->assertFalse(\App\Notifications\Inbox::DEFAULTS['location_match']);
        $this->assertFalse(\App\Notifications\Inbox::DEFAULTS['nearby_activity']);
        $this->assertSame(['moment', 'confession', 'thought', 'travel', 'encounter'], \App\Models\Post::TYPES);
    }
}
