<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\EncounterRequest;
use App\Models\Post;
use App\Models\User;
use App\Notifications\Inbox;
use App\Notifications\PushDelivery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Master notification matrix: every notification type is checked for the database row, in-app visibility, the
 * preference switch, push eligibility, target availability, blocking, self notification, locale and tap route.
 */
class NotificationMatrixTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private const TYPES = [
        'like', 'comment', 'comment_reply', 'comment_like', 'follow', 'message', 'message_request',
        'encounter_request', 'encounter_accepted', 'encounter_rejected', 'encounter_story', 'encounter_story_approval',
        'encounter_story_published', 'location_match', 'nearby_activity', 'nearby_post', 'map_note_nearby', 'map_note_reply',
        'system',
    ];

    /** Automatic recommendations are opt-in: these two are off until the person switches them on. */
    private const OPT_IN = ['location_match' => true, 'nearby_activity' => true];

    private int $city;

    private User $recipient;

    private User $actor;

    /** @var array<string,int|null> entity id each type points at (a real, reachable target) */
    private array $entity = [];

    private int $announcement;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-11-15 12:00:00', 'UTC'));
        Http::preventStrayRequests();
        Http::fake(['https://fcm.googleapis.com/*' => Http::response(['name' => 'sent'])]);
        config(['push.driver' => 'fcm', 'push.project' => 'test-project']);
        $this->city = City::where('slug', 'alanya')->value('id');
        $this->recipient = $this->user('recipient', ['preferred_locale' => 'tr', 'location_history_enabled' => true, 'city_discovery' => true, 'encounter_suggestions' => true, 'push_preferences' => self::OPT_IN]);
        $this->actor = $this->user('actor');
        $this->buildTargets();
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function user(string $name, array $extra = []): User
    {
        return User::create(['name' => ucfirst($name).' Test', 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => '1995-01-01', 'password' => 'TestPassword1234', 'city_id' => $this->city, ...$extra]);
    }

    private function as(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    private function delivery(): PushDelivery
    {
        return new class extends PushDelivery
        {
            protected function accessToken(string $project): string
            {
                return 'test-access-token';
            }
        };
    }

    private function device(User $user): void
    {
        $token = $user->createToken('mobile');
        $secret = 'device-'.$user->id;
        DB::table('user_devices')->insert([
            'user_id' => $user->id, 'personal_access_token_id' => $token->accessToken->id, 'platform' => 'android',
            'device_identifier' => (string) Str::uuid(), 'push_token' => Crypt::encryptString($secret),
            'token_hash' => hash('sha256', $secret), 'last_seen_at' => now(), 'is_active' => true,
        ]);
    }

    /** Real, reachable targets owned by the recipient so "available" can be proven true as well as false. */
    private function buildTargets(): void
    {
        $post = Post::forceCreate(['body' => 'Sahilde bir anı', 'user_id' => $this->recipient->id, 'city_id' => $this->city, 'type' => 'moment',
            'visibility' => 'city', 'request_id' => (string) Str::uuid()]);
        $comment = DB::table('post_comments')->insertGetId(['post_id' => $post->id, 'user_id' => $this->recipient->id, 'body' => 'Benim yorumum', 'created_at' => now(), 'updated_at' => now()]);
        $reply = DB::table('post_comments')->insertGetId(['post_id' => $post->id, 'user_id' => $this->actor->id, 'parent_id' => $comment, 'body' => 'Yanıt', 'created_at' => now(), 'updated_at' => now()]);
        $conversation = DB::table('conversations')->insertGetId(['first_user_id' => $this->recipient->id, 'second_user_id' => $this->actor->id,
            'requester_id' => $this->actor->id, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $request = EncounterRequest::create(['requester_id' => $this->actor->id, 'target_user_id' => $this->recipient->id, 'status' => 'accepted'])->id;
        $note = $this->as($this->recipient)->postJson('/api/v1/map-notes', ['body' => 'Seni burada gördüm yarın yine buradayım.', 'is_anonymous' => false,
            'city_id' => $this->city, 'latitude' => 36.5446, 'longitude' => 32.0021, 'request_id' => (string) Str::uuid()])->assertCreated()->json('data.id');
        $this->announcement = DB::table('announcements')->insertGetId(['title' => 'Duyuru', 'body' => 'Metin', 'title_en' => 'Notice', 'body_en' => 'Text',
            'is_active' => true, 'target_type' => 'all', 'publish_at' => now()->subHour(), 'send_push' => true, 'show_in_app' => true, 'created_at' => now(), 'updated_at' => now()]);

        foreach (self::TYPES as $type) {
            $this->entity[$type] = match (true) {
                in_array($type, ['like', 'comment', 'location_match', 'nearby_activity', 'nearby_post'], true) => $post->id,
                $type === 'comment_reply' => $reply,
                $type === 'comment_like' => $comment,
                in_array($type, ['message', 'message_request'], true) => $conversation,
                str_starts_with($type, 'encounter_') => $request,
                str_starts_with($type, 'map_note') => $note,
                default => null,
            };
        }
    }

    private function add(string $type, ?User $actor = null, bool $inApp = true, bool $push = false): ?int
    {
        $before = DB::table('app_notifications')->max('id') ?? 0;
        Inbox::add($this->recipient->id, $type === 'system' ? null : ($actor ?? $this->actor)->id, $type, $this->entity[$type] ?? null, $inApp, $push,
            $type === 'system' ? $this->announcement : null);

        return DB::table('app_notifications')->where('id', '>', $before)->where('type', $type)->value('id');
    }

    private function items(): array
    {
        return $this->as($this->recipient)->getJson('/api/v1/notifications')->assertOk()->json('data.items');
    }

    private function pushFor(int $id): ?array
    {
        $before = count(Http::recorded());
        $this->delivery()->send($id);
        $sent = array_slice(Http::recorded()->all(), $before);

        return $sent === [] ? null : $sent[0][0]->data()['message'];
    }

    public function test_every_type_is_stored_listed_routed_and_available_with_the_right_text(): void
    {
        foreach (self::TYPES as $type) {
            $id = $this->add($type);
            $this->assertNotNull($id, "$type: database row");
            $item = collect($this->items())->firstWhere('id', $id);
            $this->assertNotNull($item, "$type: visible in the in-app list");
            $this->assertSame(Inbox::TYPES[$type][0], $item['route'], "$type: tap route");
            $this->assertSame($type === 'system' ? 'Duyuru' : Inbox::message($type, 'tr'), $item['text'], "$type: Turkish text");
            $this->assertTrue($item['available'], "$type: a reachable target is available");
            $this->assertFalse($item['read'], "$type: unread");
            // Location based notices and map notes never carry an identity.
            if (in_array($type, ['nearby_activity', 'nearby_post', 'map_note_nearby', 'map_note_reply', 'system'], true)) {
                $this->assertNull($item['actor'], "$type: no actor identity");
            }
        }
        $this->assertSame(count(self::TYPES), DB::table('app_notifications')->where('user_id', $this->recipient->id)->count());
    }

    public function test_an_unreachable_target_is_listed_as_unavailable_for_every_target_type(): void
    {
        foreach (self::TYPES as $type) {
            if (in_array($type, ['follow', 'system'], true)) {
                continue;
            }
            $this->entity[$type] = 987654;
            $id = $this->add($type);
            $item = collect($this->items())->firstWhere('id', $id);
            $this->assertFalse($item['available'], "$type: deleted/unknown target is safe");
            $this->assertSame(Inbox::TYPES[$type][0], $item['route']);
        }
        // Follow points at the actor: gone when the actor is blocked (hidden) or erased.
        $id = $this->add('follow');
        DB::table('users')->where('id', $this->actor->id)->update(['account_status' => 'deleted']);
        $this->assertNull(collect($this->items())->firstWhere('id', $id)['actor'] ?? null);
        $this->assertFalse(collect($this->items())->firstWhere('id', $id)['available']);
    }

    public function test_english_recipients_get_english_in_app_text_and_english_push_bodies(): void
    {
        $this->recipient->forceFill(['preferred_locale' => 'en'])->save();
        $this->device($this->recipient);
        foreach (self::TYPES as $type) {
            $id = $this->add($type);
            $item = collect($this->items())->firstWhere('id', $id);
            $expected = $type === 'system' ? 'Notice' : Inbox::message($type, 'en');
            $this->assertSame($expected, $item['text'], "$type: English in-app text");
            $message = $this->pushFor($id);
            $this->assertNotNull($message, "$type: push sent");
            $this->assertSame($expected, $message['notification']['body'], "$type: English push body");
            $this->assertSame($type, $message['data']['type']);
            $this->assertSame(Inbox::TYPES[$type][0], $message['data']['route'], "$type: push carries the tap route");
        }
    }

    public function test_an_unset_language_follows_the_language_the_app_last_sent_for_both_inbox_and_push(): void
    {
        $this->recipient->forceFill(['preferred_locale' => null])->save();
        $this->device($this->recipient);
        $this->as($this->recipient)->withHeader('Accept-Language', 'en-GB')->getJson('/api/v1/notifications')->assertOk();
        $this->assertSame('en', $this->recipient->fresh()->last_locale);
        $id = $this->add('like');
        $this->assertSame('Someone liked your post.', $this->pushFor($id)['notification']['body']);
        $this->assertSame('Someone liked your post.', $this->as($this->recipient)->withHeader('Accept-Language', 'en-GB')->getJson('/api/v1/notifications')->json('data.items.0.text'));
        // A saved choice always wins over the header and the last seen language.
        $this->recipient->forceFill(['preferred_locale' => 'tr'])->save();
        $this->assertSame('Paylaşımın beğenildi.', $this->pushFor($this->add('like'))['notification']['body']);
    }

    public function test_push_is_sent_only_for_eligible_notifications(): void
    {
        $this->device($this->recipient);
        foreach (self::TYPES as $type) {
            $id = $this->add($type);
            $this->assertNotNull($this->pushFor($id), "$type: eligible");
            // Already read: no push.
            DB::table('app_notifications')->where('id', $id)->update(['read_at' => now()]);
            $this->assertNull($this->pushFor($id), "$type: read notifications are not pushed");
        }
        // Without an active device nothing is sent.
        DB::table('user_devices')->update(['is_active' => false]);
        $this->assertNull($this->pushFor($this->add('follow')));
    }

    public function test_push_only_notifications_stay_out_of_the_in_app_list_but_open_by_id(): void
    {
        foreach (self::TYPES as $type) {
            $id = $this->add($type, inApp: false);
            $this->assertNotNull($id, "$type: stored");
            $this->assertNull(collect($this->items())->firstWhere('id', $id), "$type: not in the in-app list");
            $this->as($this->recipient)->getJson('/api/v1/notifications/'.$id)->assertOk()->assertJsonPath('data.type', $type)
                ->assertJsonPath('data.route', Inbox::TYPES[$type][0]);
        }
    }

    public function test_the_preference_switch_gates_every_type_in_the_database_and_in_push(): void
    {
        $this->device($this->recipient);
        foreach (self::TYPES as $type) {
            $category = Inbox::category($type);
            $this->recipient->forceFill(['push_preferences' => [$category => false] + self::OPT_IN])->save();
            $this->assertNull($this->add($type), "$type: switched off ($category) creates nothing");
            $this->recipient->forceFill(['push_preferences' => [$category => true] + self::OPT_IN])->save();
            $id = $this->add($type);
            $this->assertNotNull($id, "$type: switched on ($category) creates it");
            // Turned off after creation: the push is suppressed as well.
            $this->recipient->forceFill(['push_preferences' => [$category => false]])->save();
            $this->assertNull($this->pushFor($id), "$type: push respects the switch");
            $this->recipient->forceFill(['push_preferences' => self::OPT_IN])->save();
        }
        $this->assertSame('nearby_activity', Inbox::category('nearby_post'));
        $this->assertSame('comment', Inbox::category('comment_reply'));
        $this->assertSame('like', Inbox::category('comment_like'));
        $this->assertSame('encounter', Inbox::category('encounter_story_published'));
    }

    public function test_history_based_types_also_need_their_own_opt_ins(): void
    {
        $this->recipient->forceFill(['location_history_enabled' => false])->save();
        $this->assertNull($this->add('location_match'));
        $this->assertNull($this->add('nearby_activity'));
        $this->recipient->forceFill(['location_history_enabled' => true, 'city_discovery' => false, 'encounter_suggestions' => false])->save();
        $this->assertNull($this->add('nearby_activity'));
        $this->assertNull($this->add('location_match'));
        $this->recipient->forceFill(['city_discovery' => true, 'encounter_suggestions' => true])->save();
        $this->assertNotNull($this->add('nearby_activity'));
        $this->assertNotNull($this->add('location_match'));
    }

    public function test_self_blocked_and_inactive_actors_never_notify_and_old_ones_are_hidden_and_not_pushed(): void
    {
        $this->device($this->recipient);
        foreach (self::TYPES as $type) {
            if ($type === 'system') {
                continue;
            }
            $this->assertNull($this->add($type, $this->recipient), "$type: self notification");
        }
        $existing = $this->add('like');
        DB::table('user_blocks')->insert(['blocker_id' => $this->recipient->id, 'blocked_id' => $this->actor->id, 'created_at' => now()]);
        foreach (self::TYPES as $type) {
            if ($type === 'system') {
                continue;
            }
            $this->assertNull($this->add($type), "$type: blocked actor");
        }
        $this->assertNull(collect($this->items())->firstWhere('id', $existing), 'An old notification from a blocked actor is hidden.');
        $this->assertNull($this->pushFor($existing), 'and is never pushed');
        DB::table('user_blocks')->delete();
        $other = $this->user('inactive');
        DB::table('users')->where('id', $other->id)->update(['account_status' => 'suspended']);
        $this->assertNull($this->add('follow', $other), 'inactive actor');
        // A deleted recipient receives nothing.
        DB::table('users')->where('id', $this->recipient->id)->update(['account_status' => 'deleted']);
        $this->assertNull($this->add('follow'));
    }

    public function test_marking_read_and_unread_counts_follow_the_list(): void
    {
        foreach (['like', 'follow', 'message'] as $type) {
            $this->add($type);
        }
        $this->as($this->recipient)->getJson('/api/v1/unread-counts')->assertJsonPath('data.notifications', 3);
        $first = $this->items()[0]['id'];
        $this->as($this->recipient)->putJson('/api/v1/notifications/'.$first.'/read')->assertOk();
        $this->as($this->recipient)->getJson('/api/v1/unread-counts')->assertJsonPath('data.notifications', 2);
        $this->as($this->recipient)->putJson('/api/v1/notifications/read')->assertOk();
        $this->as($this->recipient)->getJson('/api/v1/unread-counts')->assertJsonPath('data.notifications', 0);
        // Somebody else's notification can never be opened or marked.
        $stranger = $this->user('stranger');
        $this->as($stranger)->getJson('/api/v1/notifications/'.$first)->assertNotFound();
        $this->as($stranger)->putJson('/api/v1/notifications/'.$first.'/read')->assertNotFound();
    }
}
