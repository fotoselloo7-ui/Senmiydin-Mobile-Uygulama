<?php

namespace Tests\Feature;

use App\Administration\Announcements;
use App\Models\Admin;
use App\Models\City;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Announcements go out in batches of 100 (last_user_id cursor, published_at only when the last batch is done).
 * A batch is one transaction: stopping, failing or re-running it can never create a second notification.
 */
class AnnouncementBatchTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $city;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-11-15 12:00:00', 'UTC'));
        config(['push.driver' => 'none']);
        $this->city = City::where('slug', 'alanya')->value('id');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    /** @return list<int> ids */
    private function users(int $count, int $city = null): array
    {
        $rows = [];
        for ($i = 1; $i <= $count; $i++) {
            $rows[] = ['name' => "Kişi $i", 'username' => 'user'.$i.'x'.random_int(100, 999999), 'email' => "u$i-".random_int(100, 999999).'@example.test',
                'birth_date' => '1995-01-01', 'password' => 'x', 'city_id' => $city ?? $this->city, 'account_status' => 'active', 'created_at' => now(), 'updated_at' => now()];
        }
        DB::table('users')->insert($rows);

        return DB::table('users')->orderBy('id')->pluck('id')->all();
    }

    private function announcement(array $extra = []): int
    {
        return DB::table('announcements')->insertGetId(['title' => 'Duyuru', 'body' => 'Metin', 'target_type' => 'all', 'publish_at' => now()->subMinute(),
            'send_push' => false, 'show_in_app' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now(), ...$extra]);
    }

    private function counts(int $id): array
    {
        return DB::table('app_notifications')->where('announcement_id', $id)->selectRaw('user_id, count(*) as total')->groupBy('user_id')->pluck('total', 'user_id')->all();
    }

    public function test_more_than_a_hundred_recipients_are_paginated_by_the_last_user_cursor_and_each_gets_exactly_one(): void
    {
        $ids = $this->users(235);
        $id = $this->announcement();
        $service = app(Announcements::class);

        $this->assertTrue($service->publishBatch($id), 'Batch 1 of 3: more to come.');
        $row = DB::table('announcements')->find($id);
        $this->assertSame($ids[99], (int) $row->last_user_id);
        $this->assertNull($row->published_at, 'Not published until the last batch is done.');
        $this->assertSame(100, (int) $row->targeted_count);

        $this->assertTrue($service->publishBatch($id));
        $this->assertSame($ids[199], (int) DB::table('announcements')->find($id)->last_user_id);
        $this->assertFalse($service->publishBatch($id), 'Batch 3 is short: complete.');
        $row = DB::table('announcements')->find($id);
        $this->assertNotNull($row->published_at);
        $this->assertSame(235, (int) $row->targeted_count);
        $this->assertSame(235, (int) $row->delivered_count);

        $counts = $this->counts($id);
        $this->assertCount(235, $counts);
        $this->assertSame([1], array_values(array_unique($counts)), 'Exactly one notification each.');
        // Running again (scheduler overlap, retries) changes nothing.
        $this->assertFalse($service->publishBatch($id));
        $service->run();
        $this->assertSame(235, DB::table('app_notifications')->where('announcement_id', $id)->count());
    }

    public function test_exactly_two_hundred_recipients_finish_with_an_empty_last_batch(): void
    {
        $this->users(200);
        $id = $this->announcement();
        $service = app(Announcements::class);
        $this->assertTrue($service->publishBatch($id));
        $this->assertTrue($service->publishBatch($id));
        $this->assertFalse($service->publishBatch($id), 'The empty third batch completes it.');
        $this->assertSame(200, DB::table('app_notifications')->where('announcement_id', $id)->count());
        $this->assertNotNull(DB::table('announcements')->find($id)->published_at);
    }

    public function test_a_batch_that_dies_midway_rolls_back_completely_and_the_rerun_creates_no_duplicates(): void
    {
        $this->users(130);
        $id = $this->announcement();
        $service = app(Announcements::class);

        DB::beginTransaction();
        $service->publishBatch($id);
        $this->assertSame(100, DB::table('app_notifications')->where('announcement_id', $id)->count());
        DB::rollBack(); // the worker crashed before the batch committed

        $this->assertSame(0, DB::table('app_notifications')->where('announcement_id', $id)->count());
        $this->assertSame(0, (int) DB::table('announcements')->find($id)->last_user_id, 'The cursor did not move.');

        while ($service->publishBatch($id)) {
            // keep going
        }
        $counts = $this->counts($id);
        $this->assertCount(130, $counts);
        $this->assertSame([1], array_values(array_unique($counts)));
        $row = DB::table('announcements')->find($id);
        $this->assertSame(130, (int) $row->targeted_count);
        $this->assertSame(130, (int) $row->delivered_count);
    }

    public function test_disabling_expiring_and_scheduling_stop_the_run_and_resuming_continues_from_the_cursor(): void
    {
        $this->users(150);
        $service = app(Announcements::class);
        $future = $this->announcement(['publish_at' => now()->addHour()]);
        $expired = $this->announcement(['expires_at' => now()->subSecond()]);
        $disabled = $this->announcement(['is_active' => false]);
        $service->run();
        foreach ([$future, $expired, $disabled] as $skipped) {
            $this->assertSame(0, DB::table('app_notifications')->where('announcement_id', $skipped)->count());
        }
        // The future one starts only when its time comes.
        Carbon::setTestNow(now()->addHours(2));
        $service->run();
        $this->assertSame(100, DB::table('app_notifications')->where('announcement_id', $future)->count());
        $cursor = (int) DB::table('announcements')->find($future)->last_user_id;
        $this->assertGreaterThan(0, $cursor);

        // Switched off between two batches: nothing more goes out...
        DB::table('announcements')->where('id', $future)->update(['is_active' => false]);
        $service->run();
        $this->assertSame(100, DB::table('app_notifications')->where('announcement_id', $future)->count());
        // ...and switched back on, it continues after the cursor without repeating anyone.
        DB::table('announcements')->where('id', $future)->update(['is_active' => true]);
        $service->run();
        $counts = $this->counts($future);
        $this->assertCount(150, $counts);
        $this->assertSame([1], array_values(array_unique($counts)));
        $this->assertNotNull(DB::table('announcements')->find($future)->published_at);
    }

    public function test_city_targeting_and_location_targeting_page_through_only_their_own_people(): void
    {
        $other = City::where('slug', '!=', 'alanya')->value('id');
        $this->users(120, $other);
        $mine = array_slice($this->users(110), 120);
        $id = $this->announcement(['target_type' => 'city', 'city_id' => $this->city]);
        $service = app(Announcements::class);
        while ($service->publishBatch($id)) {
        }
        $this->assertSame(110, DB::table('app_notifications')->where('announcement_id', $id)->count());
        $this->assertSame([], array_diff(array_keys($this->counts($id)), $mine));

        // Location: 120 fresh samples inside, 30 outside, 20 stale.
        DB::table('app_notifications')->delete();
        $users = DB::table('users')->orderBy('id')->pluck('id')->all();
        $rows = [];
        foreach (array_slice($users, 0, 170) as $i => $user) {
            $inside = $i < 120;
            $stale = $i >= 150;
            $rows[] = ['user_id' => $user, 'city_id' => $this->city, 'latitude' => $inside || $stale ? 36.5447 : 36.5800, 'longitude' => 32.0021, 'accuracy' => 20,
                'recorded_at' => $stale ? now()->subHours(3) : now(), 'visibility' => false, 'created_at' => now(), 'updated_at' => now()];
        }
        DB::table('user_locations')->insert($rows);
        $location = $this->announcement(['target_type' => 'location', 'target_latitude' => 36.5446, 'target_longitude' => 32.0021, 'target_radius_m' => 1000]);
        while ($service->publishBatch($location)) {
        }
        $this->assertSame(array_slice($users, 0, 120), array_map('intval', array_keys($this->counts($location))));
    }

    public function test_admin_create_disable_and_schedule_are_audited_and_scheduled_ones_wait(): void
    {
        $admin = Admin::create(['name' => 'Yönetici', 'email' => 'admin@example.test', 'password' => 'Secret1234!', 'role' => 'super_admin']);
        $this->users(3);
        $this->actingAs($admin, 'admin')->from('/admin/announcements')->post('/admin/announcements', [
            'title' => 'Planlı', 'body' => 'Metin', 'title_en' => 'Scheduled', 'body_en' => 'Text', 'target_type' => 'all', 'send_push' => 0, 'show_in_app' => 1,
            'publish_at' => '2026-11-16T10:00', 'expires_at' => '2026-11-17T10:00',
        ])->assertRedirect('/admin/announcements')->assertSessionHasNoErrors();
        $id = (int) DB::table('announcements')->value('id');
        $this->assertSame(0, DB::table('app_notifications')->where('announcement_id', $id)->count(), 'Not before its time.');
        $this->assertDatabaseHas('admin_audit_logs', ['admin_id' => $admin->id, 'action' => 'announcement.create', 'target_id' => $id]);

        Carbon::setTestNow(Carbon::parse('2026-11-16 12:00:00', 'Europe/Istanbul'));
        app(Announcements::class)->run();
        $this->assertSame(3, DB::table('app_notifications')->where('announcement_id', $id)->count());

        $this->post('/admin/announcements/'.$id, ['is_active' => 0])->assertRedirect();
        $this->assertDatabaseHas('admin_audit_logs', ['admin_id' => $admin->id, 'action' => 'announcement.update', 'target_id' => $id]);
        // After expiry the notification explains itself as unavailable.
        $user = DB::table('app_notifications')->where('announcement_id', $id)->value('user_id');
        $this->assertFalse((bool) \App\Notifications\Targets::available(\App\Models\User::find($user), DB::table('app_notifications')->where('announcement_id', $id)->where('user_id', $user)->get())[
            DB::table('app_notifications')->where('announcement_id', $id)->where('user_id', $user)->value('id')]);
    }
}
