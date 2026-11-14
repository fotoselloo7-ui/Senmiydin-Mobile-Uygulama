<?php

namespace Tests\Feature;

use App\Jobs\DeliverPush;
use App\Jobs\MatchLocationPost;
use App\Models\City;
use App\Models\Post;
use App\Models\User;
use App\Notifications\Inbox;
use App\Notifications\PushDelivery;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The real database queue and the scheduler: a failing push is retried with backoff, ends up in failed_jobs, can be
 * retried from there, never pushes twice, and every scheduled command is overlap-safe.
 */
class QueueSchedulerTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private User $recipient;

    private User $actor;

    private bool $providerDown = true;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-11-15 12:00:00', 'UTC'));
        $city = City::where('slug', 'alanya')->value('id');
        $make = fn (string $name) => User::create(['name' => ucfirst($name), 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => '1995-01-01', 'password' => 'TestPassword1234', 'city_id' => $city]);
        $this->recipient = $make('recipient');
        $this->actor = $make('actor');
        config(['queue.default' => 'database', 'push.driver' => 'fcm', 'push.project' => 'test-project']);
        $this->app->bind(PushDelivery::class, fn () => new class extends PushDelivery
        {
            protected function accessToken(string $project): string
            {
                return 'test-access-token';
            }
        });
        $token = $this->recipient->createToken('mobile');
        DB::table('user_devices')->insert(['user_id' => $this->recipient->id, 'personal_access_token_id' => $token->accessToken->id, 'platform' => 'android',
            'device_identifier' => (string) Str::uuid(), 'push_token' => Crypt::encryptString('device-secret'),
            'token_hash' => hash('sha256', 'device-secret'), 'last_seen_at' => now(), 'is_active' => true]);
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function work(): void
    {
        Artisan::call('queue:work', ['connection' => 'database', '--once' => true, '--queue' => 'default']);
    }

    private function fcmCalls(): int
    {
        return Http::recorded()->count();
    }

    public function test_a_failing_push_is_retried_with_backoff_lands_in_failed_jobs_and_can_be_retried_without_duplicates(): void
    {
        Http::preventStrayRequests();
        Http::fake(fn () => $this->providerDown ? Http::response(['error' => ['message' => 'down']], 503) : Http::response(['name' => 'sent']));
        Inbox::add($this->recipient->id, $this->actor->id, 'follow');
        $id = DB::table('app_notifications')->value('id');
        $this->assertSame(1, DB::table('jobs')->count(), 'The push is queued, not sent inside the request.');
        $this->assertSame(0, $this->fcmCalls());

        $this->work();
        $this->assertSame(1, $this->fcmCalls());
        $this->assertSame(1, DB::table('jobs')->count(), 'Released for a retry.');
        $this->assertSame(0, DB::table('failed_jobs')->count());
        $this->work(); // still inside the 10 s backoff: nothing is attempted
        $this->assertSame(1, $this->fcmCalls());

        Carbon::setTestNow(now()->addSeconds(11));
        $this->work();
        $this->assertSame(2, $this->fcmCalls());
        Carbon::setTestNow(now()->addMinutes(2));
        $this->work();
        $this->assertSame(3, $this->fcmCalls());
        $this->assertSame(0, DB::table('jobs')->count());
        $this->assertSame(1, DB::table('failed_jobs')->count(), 'After 3 tries it is parked in failed_jobs.');
        $this->assertNull(DB::table('app_notifications')->find($id)->pushed_at);
        $this->assertSame($id, (int) DB::table('app_notifications')->value('id'), 'The in-app notification is unaffected by the push failure.');

        // The provider recovers; retrying from failed_jobs delivers once.
        $this->providerDown = false;
        Artisan::call('queue:retry', ['id' => ['all']]);
        $this->assertSame(1, DB::table('jobs')->count());
        $before = $this->fcmCalls();
        $this->work();
        $this->assertSame($before + 1, $this->fcmCalls());
        $this->assertNotNull(DB::table('app_notifications')->find($id)->pushed_at);
        $this->assertSame(0, DB::table('failed_jobs')->count());

        // Idempotent: a duplicate dispatch (retry race, double click) does not push again.
        DeliverPush::dispatchSync($id);
        $this->work();
        $this->assertSame($before + 1, $this->fcmCalls());
    }

    public function test_an_expired_provider_token_disables_the_device_instead_of_failing_the_job(): void
    {
        Http::preventStrayRequests();
        Http::fake(['https://fcm.googleapis.com/*' => Http::response(['error' => ['details' => [['errorCode' => 'UNREGISTERED']]]], 404)]);
        Inbox::add($this->recipient->id, $this->actor->id, 'follow');
        $this->work();
        $this->assertSame(0, DB::table('failed_jobs')->count());
        $this->assertSame(0, (int) DB::table('user_devices')->value('is_active'));
    }

    public function test_the_location_matcher_job_is_idempotent_when_it_runs_twice(): void
    {
        $city = City::where('slug', 'alanya')->value('id');
        $this->recipient->forceFill(['push_preferences' => ['nearby_activity' => true]])->save();
        DB::table('user_locations')->insert(['user_id' => $this->recipient->id, 'city_id' => $city, 'latitude' => 36.5447, 'longitude' => 32.0021, 'accuracy' => 20,
            'recorded_at' => now(), 'visibility' => false, 'created_at' => now(), 'updated_at' => now()]);
        $post = Post::forceCreate(['body' => 'x', 'user_id' => $this->actor->id, 'city_id' => $city, 'type' => 'moment', 'visibility' => 'city',
            'request_id' => (string) Str::uuid(), 'approx_latitude' => 36.5446, 'approx_longitude' => 32.0021]);
        Http::fake(['https://fcm.googleapis.com/*' => Http::response(['name' => 'sent'])]);
        MatchLocationPost::dispatch($post->id);
        MatchLocationPost::dispatch($post->id);
        $this->work();
        $this->work();
        $this->assertSame(1, DB::table('app_notifications')->where('type', 'nearby_post')->count());
        // A job for a post that no longer exists is a quiet no-op.
        MatchLocationPost::dispatchSync(987654);
    }

    public function test_every_scheduled_command_is_registered_and_overlap_safe(): void
    {
        $events = collect(app(Schedule::class)->events());
        $names = $events->map(fn ($event) => $event->command ?? $event->description)->implode(' | ');
        foreach (['sanctum:prune-expired', 'posts:purge-deleted', 'location:purge', 'map-notes:purge', 'announcements.publish', 'media:cleanup',
            'oauth:revoke-deleted', 'devices:prune'] as $expected) {
            $this->assertStringContainsString($expected, $names, "$expected is scheduled");
        }
        foreach ($events as $event) {
            $this->assertTrue($event->withoutOverlapping, 'Overlap protection: '.($event->command ?? $event->description));
        }
    }

    public function test_cleanup_commands_run_twice_without_errors_and_only_remove_what_is_expired(): void
    {
        $city = City::where('slug', 'alanya')->value('id');
        DB::table('user_location_history')->insert([
            ['user_id' => $this->recipient->id, 'city_id' => $city, 'latitude' => 36.5, 'longitude' => 32.0, 'recorded_at' => now()->subDays(30)],
            ['user_id' => $this->recipient->id, 'city_id' => $city, 'latitude' => 36.5, 'longitude' => 32.0, 'recorded_at' => now()->subHour()],
        ]);
        DB::table('user_devices')->where('user_id', $this->recipient->id)->update(['is_active' => false, 'last_seen_at' => now()->subDays(40)]);
        foreach (['location:purge', 'devices:prune', 'map-notes:purge', 'posts:purge-deleted', 'media:cleanup'] as $command) {
            $this->assertContains(Artisan::call($command), [0], "$command succeeds");
            $this->assertContains(Artisan::call($command), [0], "$command is repeatable");
        }
        $this->assertSame(1, DB::table('user_location_history')->count(), 'Only the expired history row was purged.');
        $this->assertSame(0, DB::table('user_devices')->count(), 'The stale inactive device was pruned.');
    }
}
