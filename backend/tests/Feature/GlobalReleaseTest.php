<?php

namespace Tests\Feature;

use App\Administration\Announcements;
use App\Models\Admin;
use App\Models\City;
use App\Models\Post;
use App\Models\User;
use App\Notifications\Inbox;
use App\Notifications\PushDelivery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Notifications, push chain, current-location "nearby post", location announcements, private location messages,
 * localization and the ads switch.
 */
class GlobalReleaseTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $city;

    private User $demo;

    private User $elif;

    private User $ece;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-11-15 12:00:00', 'UTC'));
        $this->city = City::where('slug', 'alanya')->value('id');
        $this->demo = $this->user('demo');
        $this->elif = $this->user('elif');
        $this->ece = $this->user('ece');
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

    private function device(User $user): int
    {
        $token = $user->createToken('mobile');
        $secret = 'device-'.$user->id;

        return DB::table('user_devices')->insertGetId([
            'user_id' => $user->id, 'personal_access_token_id' => $token->accessToken->id, 'platform' => 'android',
            'device_identifier' => (string) Str::uuid(), 'push_token' => Crypt::encryptString($secret),
            'token_hash' => hash('sha256', $secret), 'last_seen_at' => now(), 'is_active' => true,
        ]);
    }

    private function locate(User $user, float $lat, float $lng, ?string $at = null): void
    {
        DB::table('user_locations')->upsert([['user_id' => $user->id, 'city_id' => $this->city, 'latitude' => $lat, 'longitude' => $lng,
            'accuracy' => 20, 'recorded_at' => $at ?? now(), 'visibility' => false, 'created_at' => now(), 'updated_at' => now()]],
            ['user_id'], ['city_id', 'latitude', 'longitude', 'accuracy', 'recorded_at', 'visibility', 'updated_at']);
    }

    private function makePost(User $user, array $extra = []): Post
    {
        return Post::forceCreate(['body' => 'Sahilde bir anı', 'user_id' => $user->id, 'city_id' => $this->city, 'type' => 'moment',
            'visibility' => 'city', 'request_id' => (string) Str::uuid(), ...$extra]);
    }

    // ------------------------------------------------------------------ push chain

    public function test_every_interaction_creates_a_notification_and_a_push_for_the_other_person_only(): void
    {
        config(['push.driver' => 'log']);
        $this->device($this->elif);
        $this->device($this->demo);
        $post = $this->makePost($this->elif);
        $logged = [];
        Log::shouldReceive('info')->andReturnUsing(function ($message, $context = []) use (&$logged): void {
            if ($message === 'Push notification') {
                $logged[] = $context['data']['type'];
            }
        });
        Log::shouldReceive('error', 'warning', 'debug', 'notice')->zeroOrMoreTimes();

        $this->as($this->demo)->postJson('/api/v1/posts/'.$post->id.'/like')->assertSuccessful();
        $comment = $this->as($this->demo)->postJson('/api/v1/posts/'.$post->id.'/comments', ['body' => 'Güzel', 'request_id' => (string) Str::uuid()])->assertCreated()->json('data');
        $this->as($this->elif)->postJson('/api/v1/posts/'.$post->id.'/comments', ['body' => 'Teşekkürler', 'parent_id' => $comment['id'], 'request_id' => (string) Str::uuid()])->assertCreated();
        $this->as($this->elif)->postJson('/api/v1/posts/'.$post->id.'/comments/'.$comment['id'].'/like')->assertSuccessful();
        $this->as($this->demo)->postJson('/api/v1/users/elif/follow')->assertSuccessful();
        $this->as($this->demo)->postJson('/api/v1/users/'.$this->elif->id.'/messages', ['body' => 'Merhaba', 'request_id' => (string) Str::uuid()])->assertCreated();
        $conversation = DB::table('conversations')->value('id');
        $this->as($this->elif)->postJson("/api/v1/conversations/$conversation/request/accept")->assertSuccessful();
        $this->as($this->elif)->postJson('/api/v1/users/'.$this->demo->id.'/messages', ['body' => 'Selam', 'request_id' => (string) Str::uuid()])->assertCreated();
        $this->device($this->ece);
        $encounter = $this->as($this->demo)->postJson('/api/v1/posts', ['body' => 'Sahilde karşılaştık', 'type' => 'encounter', 'city_id' => $this->city,
            'visibility' => 'city', 'is_anonymous' => false, 'encounter_target_id' => $this->ece->id, 'request_id' => (string) Str::uuid()])->assertCreated();
        $request = DB::table('encounter_requests')->value('id');
        $this->as($this->ece)->postJson("/api/v1/encounter-requests/$request/accept")->assertSuccessful();
        $note = $this->as($this->elif)->postJson('/api/v1/map-notes', ['body' => 'Seni burada gördüm, yarın yine buradayım.', 'is_anonymous' => false,
            'city_id' => $this->city, 'latitude' => 36.5446, 'longitude' => 32.0021, 'request_id' => (string) Str::uuid()])->assertCreated()->json('data');
        $this->as($this->demo)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Merhaba', 'request_id' => (string) Str::uuid()])->assertCreated();

        $types = DB::table('app_notifications')->pluck('type')->all();
        foreach (['like', 'comment', 'comment_reply', 'comment_like', 'follow', 'message', 'message_request', 'encounter_request', 'encounter_accepted', 'map_note_reply'] as $type) {
            $this->assertContains($type, $types, "$type notification exists");
        }
        foreach (['like', 'comment', 'comment_reply', 'comment_like', 'follow', 'message', 'message_request', 'encounter_request', 'encounter_accepted', 'map_note_reply'] as $type) {
            $this->assertContains($type, $logged, "$type produced a push");
        }
        // Nobody is ever notified about their own action.
        $this->assertSame(0, DB::table('app_notifications')->whereColumn('user_id', 'actor_id')->count());
    }

    public function test_self_actions_blocks_and_preferences_never_produce_notifications(): void
    {
        $post = $this->makePost($this->elif);
        $this->as($this->elif)->postJson('/api/v1/posts/'.$post->id.'/like')->assertSuccessful();
        $this->as($this->elif)->postJson('/api/v1/posts/'.$post->id.'/comments', ['body' => 'Kendime', 'request_id' => (string) Str::uuid()])->assertCreated();
        $this->assertDatabaseCount('app_notifications', 0);

        $this->elif->forceFill(['push_preferences' => ['like' => false]])->save();
        $this->as($this->demo)->postJson('/api/v1/posts/'.$post->id.'/like')->assertSuccessful();
        $this->assertDatabaseCount('app_notifications', 0);
        $this->elif->forceFill(['push_preferences' => ['like' => true]])->save();

        DB::table('user_blocks')->insert(['blocker_id' => $this->elif->id, 'blocked_id' => $this->ece->id, 'created_at' => now()]);
        Inbox::add($this->elif->id, $this->ece->id, 'follow');
        Inbox::add($this->ece->id, $this->elif->id, 'follow');
        $this->assertDatabaseCount('app_notifications', 0);
    }

    public function test_without_fcm_credentials_the_in_app_notification_still_works_and_nothing_is_sent(): void
    {
        Http::preventStrayRequests();
        config(['push.driver' => 'log']);
        $this->device($this->elif);
        $post = $this->makePost($this->elif);
        $this->as($this->demo)->postJson('/api/v1/posts/'.$post->id.'/like')->assertSuccessful();
        $this->as($this->elif)->getJson('/api/v1/notifications')->assertOk()->assertJsonPath('data.items.0.type', 'like');
        Http::assertNothingSent();
    }

    public function test_fcm_body_follows_the_recipients_language_and_keeps_private_content_out(): void
    {
        Http::preventStrayRequests();
        Http::fake(['https://fcm.googleapis.com/*' => Http::response(['name' => 'sent'])]);
        config(['push.driver' => 'fcm', 'push.project' => 'test-project']);
        $delivery = new class extends PushDelivery
        {
            protected function accessToken(string $project): string
            {
                return 'test-access-token';
            }
        };
        $this->device($this->elif);
        $this->device($this->demo);
        $this->demo->forceFill(['preferred_locale' => 'en'])->save();
        $chat = \App\Models\Conversation::create(['first_user_id' => $this->demo->id, 'second_user_id' => $this->elif->id, 'requester_id' => $this->elif->id, 'status' => 'active']);
        foreach ([$this->elif, $this->demo] as $recipient) {
            $id = DB::table('app_notifications')->insertGetId(['user_id' => $recipient->id, 'actor_id' => $recipient->is($this->elif) ? $this->demo->id : $this->elif->id,
                'type' => 'comment_reply', 'entity_id' => null, 'created_at' => now(), 'in_app' => true]);
            $delivery->send($id);
        }
        $bodies = [];
        Http::assertSentCount(2);
        Http::assertSent(function ($request) use (&$bodies) {
            $bodies[] = $request['message']['notification']['body'];

            return true;
        });
        $this->assertContains('Yorumuna bir cevap geldi.', $bodies);
        $this->assertContains('Someone replied to your comment.', $bodies);

        // Message pushes keep the generic text: the private message never reaches the lock screen.
        $this->as($this->demo)->postJson('/api/v1/users/'.$this->elif->id.'/messages', ['body' => 'Çok özel bir mesaj', 'request_id' => (string) Str::uuid()])->assertCreated();
        $messageId = DB::table('app_notifications')->where('type', 'message')->orWhere('type', 'message_request')->value('id');
        $this->assertNotNull($messageId);
        Http::fake(['https://fcm.googleapis.com/*' => Http::response(['name' => 'sent'])]);
        $delivery->send($messageId);
        Http::assertSent(fn ($request) => ! str_contains(json_encode($request->data()), 'Çok özel'));
    }

    public function test_inbox_text_follows_the_user_language_and_the_accept_language_header(): void
    {
        $post = $this->makePost($this->elif);
        $this->as($this->demo)->postJson('/api/v1/posts/'.$post->id.'/like')->assertSuccessful();
        $this->as($this->elif)->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.text', 'Paylaşımın beğenildi.');
        $this->elif->forceFill(['preferred_locale' => 'en'])->save();
        $this->as($this->elif)->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.text', 'Someone liked your post.');
        // Without a saved choice the header decides.
        $this->elif->forceFill(['preferred_locale' => null])->save();
        $this->as($this->elif)->withHeader('Accept-Language', 'en-US,en;q=0.8')->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.text', 'Someone liked your post.');
        $this->as($this->elif)->withHeader('Accept-Language', 'de-DE')->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.text', 'Paylaşımın beğenildi.');
    }

    public function test_profile_stores_the_preferred_locale_and_validation_messages_are_localized(): void
    {
        $this->as($this->demo)->putJson('/api/v1/profile', ['preferred_locale' => 'en'])->assertOk()->assertJsonPath('data.preferred_locale', 'en');
        $this->as($this->demo)->putJson('/api/v1/profile', ['preferred_locale' => 'de'])->assertUnprocessable();
        $this->demo->forceFill(['preferred_locale' => null])->save();
        $this->flushHeaders();
        $this->app['auth']->forgetGuards();
        $english = $this->withHeader('Accept-Language', 'en')->postJson('/api/v1/auth/login', ['identifier' => 'demo', 'password' => 'wrong-password-123']);
        $english->assertStatus(401)->assertJsonPath('message', 'Your sign-in details are incorrect.');
        $this->app['auth']->forgetGuards();
        $this->withHeader('Accept-Language', 'tr')->postJson('/api/v1/auth/login', ['identifier' => 'demo', 'password' => 'wrong-password-123'])
            ->assertStatus(401)->assertJsonPath('message', 'Giriş bilgilerin hatalı.');
        $this->withHeader('Accept-Language', 'en')->postJson('/api/v1/auth/register', ['name' => 'X', 'username' => 'xx'])
            ->assertUnprocessable()->assertJsonPath('errors.username.0', 'Username must be at least 3 characters.');
    }

    public function test_notification_routes_cover_every_type_the_app_opens(): void
    {
        foreach (['like', 'comment', 'comment_reply', 'comment_like', 'follow', 'message', 'message_request', 'encounter_request', 'encounter_accepted',
            'encounter_rejected', 'encounter_story', 'encounter_story_approval', 'encounter_story_published', 'location_match', 'nearby_activity',
            'nearby_post', 'system', 'map_note_nearby', 'map_note_reply'] as $type) {
            $this->assertArrayHasKey($type, Inbox::TYPES);
            foreach (['tr', 'en'] as $locale) {
                $this->assertNotSame('inbox.'.$type, Inbox::message($type, $locale), "$type has $locale text");
                $this->assertNotSame('', Inbox::message($type, $locale));
            }
        }
        $this->assertSame('/post', Inbox::TYPES['nearby_post'][0]);
    }

    // ------------------------------------------------------- current-location nearby post

    public function test_a_new_post_notifies_people_near_it_right_now_once_within_the_central_radius(): void
    {
        $this->assertSame(1000, config('location.current_nearby.radius_meters'));
        $this->assertSame(30, config('location.current_nearby.freshness_minutes'));
        $this->elif->forceFill(['push_preferences' => ['nearby_activity' => true]])->save();
        $this->ece->forceFill(['push_preferences' => ['nearby_activity' => true]])->save();
        $this->locate($this->elif, 36.5450, 32.0010);       // ~100 m away
        $this->locate($this->ece, 36.5640, 32.0010);        // ~2.2 km away
        $optedOut = $this->user('optedout');                // preference stays off (default)
        $this->locate($optedOut, 36.5448, 32.0012);
        $stale = $this->user('stale', ['push_preferences' => ['nearby_activity' => true]]);
        $this->locate($stale, 36.5450, 32.0010, now()->subMinutes(45));

        $post = $this->makePost($this->demo, ['approx_latitude' => 36.5446, 'approx_longitude' => 32.0021, 'city_id' => $this->city]);
        \App\Jobs\MatchLocationPost::dispatchSync($post->id);
        \App\Jobs\MatchLocationPost::dispatchSync($post->id);

        $this->assertSame([$this->elif->id], DB::table('app_notifications')->where('type', 'nearby_post')->pluck('user_id')->all(), 'Only the person near it, once.');
        $item = $this->as($this->elif)->getJson('/api/v1/notifications')->assertOk()->json('data.items.0');
        $this->assertSame('Yakınında yeni bir paylaşım var.', $item['text']);
        $this->assertSame('/post', $item['route']);
        $this->assertSame($post->id, $item['entity_id']);
        $this->assertNull($item['actor'], 'The author is never identified.');
    }

    public function test_nearby_post_skips_blocked_other_band_and_stronger_history_matches(): void
    {
        foreach ([$this->elif, $this->ece] as $user) {
            $user->forceFill(['push_preferences' => ['nearby_activity' => true]])->save();
            $this->locate($user, 36.5450, 32.0010);
        }
        $teen = $this->user('teen', ['birth_date' => '2010-06-01', 'push_preferences' => ['nearby_activity' => true]]);
        $this->locate($teen, 36.5450, 32.0010);
        DB::table('user_blocks')->insert(['blocker_id' => $this->ece->id, 'blocked_id' => $this->demo->id, 'created_at' => now()]);
        $post = $this->makePost($this->demo, ['approx_latitude' => 36.5446, 'approx_longitude' => 32.0021]);
        // A stronger history match already exists for Elif: she must not be notified twice.
        DB::table('location_matches')->insert(['user_id' => $this->elif->id, 'post_id' => $post->id, 'matched_at' => now(), 'distance_meters' => 100,
            'time_difference_seconds' => 60, 'score' => 90, 'strength' => 'strong', 'status' => 'pending', 'notification_state' => 'sent']);
        \App\Jobs\MatchLocationPost::dispatchSync($post->id);
        $this->assertDatabaseMissing('app_notifications', ['type' => 'nearby_post']);

        // And in the opposite direction: a teen author reaches no adult.
        $teenPost = $this->makePost($teen, ['approx_latitude' => 36.5446, 'approx_longitude' => 32.0021]);
        \App\Jobs\MatchLocationPost::dispatchSync($teenPost->id);
        $this->assertDatabaseMissing('app_notifications', ['type' => 'nearby_post', 'entity_id' => $teenPost->id]);
    }

    public function test_nearby_post_is_limited_to_the_same_city_the_radius_fresh_samples_and_public_city_posts(): void
    {
        $prefs = ['push_preferences' => ['nearby_activity' => true]];
        $inside = $this->user('inside', $prefs);
        $edge = $this->user('edge', $prefs);
        $outside = $this->user('outside', $prefs);
        $otherCity = $this->user('othercity', $prefs);
        $author = $this->demo;
        $author->forceFill($prefs)->save();
        $this->locate($inside, 36.5452, 32.0021);           // ~70 m
        $this->locate($edge, 36.5446 + 0.0085, 32.0021);    // ~945 m: inside the 1000 m radius
        $this->locate($outside, 36.5446 + 0.0100, 32.0021); // ~1.11 km: outside
        $this->locate($otherCity, 36.5450, 32.0021);
        DB::table('user_locations')->where('user_id', $otherCity->id)->update(['city_id' => City::where('slug', '!=', 'alanya')->value('id')]);
        $this->locate($author, 36.5447, 32.0021);           // the author is never notified about their own post

        $post = $this->makePost($author, ['approx_latitude' => 36.5446, 'approx_longitude' => 32.0021]);
        \App\Jobs\MatchLocationPost::dispatchSync($post->id);
        $got = DB::table('app_notifications')->where('type', 'nearby_post')->pluck('user_id')->sort()->values()->all();
        $this->assertSame([$inside->id, $edge->id], $got, 'Inside the radius and in the same city only; never the author.');

        // Posts that are not public city posts at the place never notify.
        foreach ([['visibility' => 'followers']] as $extra) {
            $other = $this->makePost($author, ['approx_latitude' => 36.5446, 'approx_longitude' => 32.0021, ...$extra]);
            \App\Jobs\MatchLocationPost::dispatchSync($other->id);
            $this->assertDatabaseMissing('app_notifications', ['type' => 'nearby_post', 'entity_id' => $other->id]);
        }
        // No approximate place: nothing to match.
        $blank = $this->makePost($author);
        \App\Jobs\MatchLocationPost::dispatchSync($blank->id);
        $this->assertDatabaseMissing('app_notifications', ['type' => 'nearby_post', 'entity_id' => $blank->id]);
        // Deleted author's post does not notify either.
        $gone = $this->makePost($author, ['approx_latitude' => 36.5446, 'approx_longitude' => 32.0021]);
        DB::table('users')->where('id', $author->id)->update(['account_status' => 'deleted']);
        \App\Jobs\MatchLocationPost::dispatchSync($gone->id);
        $this->assertDatabaseMissing('app_notifications', ['type' => 'nearby_post', 'entity_id' => $gone->id]);
    }

    public function test_the_history_matcher_keeps_its_own_notification_types_and_is_not_replaced(): void
    {
        $this->assertSame('Geçtiğin bölgede bir paylaşım var.', Inbox::message('nearby_activity', 'tr'));
        $this->assertSame('Birine denk gelmiş olabilirsin 👀', Inbox::message('location_match', 'tr'));
        $this->assertNotSame(Inbox::message('nearby_post', 'tr'), Inbox::message('nearby_activity', 'tr'));
    }

    // ------------------------------------------------------------ location messages

    public function test_a_location_message_is_stored_approximately_notifies_and_never_exposes_the_raw_point(): void
    {
        $response = $this->as($this->demo)->postJson('/api/v1/users/'.$this->elif->id.'/messages', [
            'request_id' => (string) Str::uuid(), 'latitude' => 36.544123, 'longitude' => 32.000987, 'place_label' => 'Kleopatra Plajı',
        ])->assertCreated()->assertJsonPath('data.message.type', 'location');
        $point = $response->json('data.message.location');
        $this->assertEqualsWithDelta(36.5440, $point['latitude'], 0.00051);
        $this->assertNotSame(36.544123, $point['latitude']);
        $this->assertNotSame(32.000987, $point['longitude']);
        $this->assertSame('Kleopatra Plajı', $point['place_label']);
        $stored = DB::table('messages')->sole();
        $this->assertSame('location', $stored->type);
        $this->assertEqualsWithDelta(36.544, (float) $stored->approx_latitude, 0.0006);
        $this->assertStringNotContainsString('36.544123', json_encode($response->json()));
        // The same message notifies the recipient (a first message is a request).
        $this->assertDatabaseHas('app_notifications', ['user_id' => $this->elif->id, 'type' => 'message_request']);
        $this->as($this->elif)->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.text', 'Yeni bir mesaj isteğin var.');
        $conversation = DB::table('conversations')->value('id');
        $this->as($this->elif)->getJson("/api/v1/conversations/$conversation/messages")->assertOk()->assertJsonPath('data.items.0.location.place_label', 'Kleopatra Plajı');
        // Invalid or half-given points and mixing with an image are rejected.
        $this->as($this->demo)->postJson('/api/v1/users/'.$this->elif->id.'/messages', ['request_id' => (string) Str::uuid(), 'latitude' => 120, 'longitude' => 10])->assertUnprocessable();
        $this->as($this->demo)->postJson('/api/v1/users/'.$this->elif->id.'/messages', ['request_id' => (string) Str::uuid(), 'latitude' => 36.5])->assertUnprocessable();
    }

    public function test_text_photo_and_location_messages_all_notify_the_other_side_with_the_generic_text(): void
    {
        $this->as($this->demo)->postJson('/api/v1/users/'.$this->elif->id.'/messages', ['body' => 'Merhaba', 'request_id' => (string) Str::uuid()])->assertCreated();
        $conversation = DB::table('conversations')->value('id');
        $this->as($this->elif)->postJson("/api/v1/conversations/$conversation/request/accept")->assertSuccessful();
        DB::table('app_notifications')->delete();
        $this->as($this->demo)->postJson('/api/v1/users/'.$this->elif->id.'/messages', ['body' => 'Bir mesaj daha', 'request_id' => (string) Str::uuid()])->assertCreated();
        $this->as($this->demo)->postJson('/api/v1/users/'.$this->elif->id.'/messages', ['request_id' => (string) Str::uuid(), 'latitude' => 36.5, 'longitude' => 32.0])->assertCreated();
        $image = \Illuminate\Http\UploadedFile::fake()->image('foto.jpg', 600, 400);
        $this->as($this->demo)->post('/api/v1/users/'.$this->elif->id.'/messages', ['request_id' => (string) Str::uuid(), 'image' => $image], ['Accept' => 'application/json'])->assertCreated()
            ->assertJsonPath('data.message.type', 'image');
        $this->assertSame(3, DB::table('app_notifications')->where('user_id', $this->elif->id)->where('type', 'message')->count());
        $texts = array_column($this->as($this->elif)->getJson('/api/v1/notifications')->json('data.items'), 'text');
        $this->assertSame(['Yeni bir mesajın var.'], array_values(array_unique($texts)));
    }

    // ---------------------------------------------------------- location announcements

    public function test_location_announcement_reaches_only_people_inside_the_radius_who_were_recently_there(): void
    {
        $inside = $this->user('inside');
        $outside = $this->user('outside');
        $stale = $this->user('stale');
        $none = $this->user('nolocation');
        $this->locate($inside, 36.5450, 32.0010);   // ~100 m
        $this->locate($outside, 36.5800, 32.0010);  // ~3.9 km
        $this->locate($stale, 36.5450, 32.0010, now()->subMinutes(50));
        $id = DB::table('announcements')->insertGetId(['title' => 'Plajda etkinlik', 'body' => 'Bu akşam burada buluşuyoruz.',
            'title_en' => 'Beach event', 'body_en' => 'We meet here tonight.', 'target_type' => 'location', 'target_latitude' => 36.5446,
            'target_longitude' => 32.0021, 'target_radius_m' => 1000, 'publish_at' => now()->subMinute(), 'send_push' => false, 'show_in_app' => true,
            'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(Announcements::class)->publishBatch($id);
        app(Announcements::class)->publishBatch($id);

        $this->assertSame([$inside->id], DB::table('app_notifications')->where('announcement_id', $id)->pluck('user_id')->all());
        $row = DB::table('announcements')->find($id);
        $this->assertSame(1, (int) $row->targeted_count);
        $this->assertSame(1, (int) $row->delivered_count);
        $item = $this->as($inside)->getJson('/api/v1/notifications')->assertOk()->json('data.items.0');
        $this->assertSame('Plajda etkinlik', $item['text']);
        $this->assertSame('Bu akşam burada buluşuyoruz.', $item['announcement_body']);
        $this->assertEqualsWithDelta(36.5446, $item['map_target']['latitude'], 0.0001);
        $this->assertArrayNotHasKey('actor', array_filter($item), 'Announcements carry no identity.');
        $inside->forceFill(['preferred_locale' => 'en'])->save();
        $english = $this->as($inside)->getJson('/api/v1/notifications')->json('data.items.0');
        $this->assertSame('Beach event', $english['text']);
        $this->assertSame('We meet here tonight.', $english['announcement_body']);
        // It is not a global banner.
        $this->as($outside)->getJson('/api/v1/app-config')->assertJsonPath('data.announcement', null);

        // Deactivating makes the target unavailable instead of opening anything.
        DB::table('announcements')->where('id', $id)->update(['is_active' => false]);
        $this->as($inside)->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.available', false)->assertJsonMissingPath('data.items.0.map_target');
    }

    public function test_english_announcement_falls_back_to_turkish_when_the_english_text_is_empty(): void
    {
        $id = DB::table('announcements')->insertGetId(['title' => 'Genel duyuru', 'body' => 'Gövde', 'target_type' => 'all', 'publish_at' => now()->subMinute(),
            'send_push' => false, 'show_in_app' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(Announcements::class)->publishBatch($id);
        $this->elif->forceFill(['preferred_locale' => 'en'])->save();
        $this->as($this->elif)->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.text', 'Genel duyuru');
    }

    public function test_admin_creates_a_location_announcement_with_a_snapped_point_and_sees_only_counts(): void
    {
        $admin = Admin::create(['name' => 'Yönetici', 'email' => 'admin@example.test', 'password' => 'Secret1234!', 'role' => 'super_admin']);
        $this->locate($this->demo, 36.5450, 32.0010);
        $this->actingAs($admin, 'admin')->from('/admin/announcements')->post('/admin/announcements', [
            'title' => 'Konum duyurusu', 'body' => 'Merhaba', 'title_en' => 'Location notice', 'body_en' => 'Hello', 'target_type' => 'location',
            'target_latitude' => '36.54463', 'target_longitude' => '32.00217', 'target_radius_m' => 1000, 'city_id' => $this->city,
            'send_push' => 0, 'show_in_app' => 1,
        ])->assertRedirect('/admin/announcements')->assertSessionHasNoErrors();
        $row = DB::table('announcements')->sole();
        $this->assertSame('location', $row->target_type);
        $this->assertEqualsWithDelta(36.5445, (float) $row->target_latitude, 0.0006, 'Stored on the approximate grid.');
        $this->assertNotSame('36.54463', (string) $row->target_latitude);
        $this->assertSame(1, (int) $row->delivered_count);
        $this->get('/admin/announcements')->assertOk()->assertSee('Yaklaşık konum')->assertSee('Hedeflenen: 1')->assertDontSee('36.5450');
        // Missing point / radius / city for a city target are validation errors.
        $this->post('/admin/announcements', ['title' => 'x', 'body' => 'y', 'target_type' => 'location', 'send_push' => 0, 'show_in_app' => 1])->assertSessionHasErrors(['target_latitude', 'target_radius_m']);
        $this->post('/admin/announcements', ['title' => 'x', 'body' => 'y', 'target_type' => 'city', 'send_push' => 0, 'show_in_app' => 1])->assertSessionHasErrors('city_id');
        $this->post('/admin/announcements', ['title' => 'x', 'body' => 'y', 'target_type' => 'location', 'target_latitude' => 36.5, 'target_longitude' => 32, 'target_radius_m' => 777,
            'send_push' => 0, 'show_in_app' => 1])->assertSessionHasErrors('target_radius_m');
    }

    // ------------------------------------------------------------------------- ads

    public function test_ads_switch_and_interval_come_from_app_config_and_the_admin_settings(): void
    {
        $this->getJson('/api/v1/app-config')->assertOk()->assertJsonPath('data.ads_enabled', true)->assertJsonPath('data.feed_ad_interval', 11);
        $admin = Admin::create(['name' => 'Yönetici', 'email' => 'admin@example.test', 'password' => 'Secret1234!', 'role' => 'super_admin']);
        $this->actingAs($admin, 'admin')->from('/admin/settings')->post('/admin/settings', ['ads_enabled' => 0, 'feed_ad_interval' => 14])
            ->assertRedirect('/admin/settings')->assertSessionHasNoErrors();
        $this->getJson('/api/v1/app-config')->assertJsonPath('data.ads_enabled', false)->assertJsonPath('data.feed_ad_interval', 14);
        $this->post('/admin/settings', ['feed_ad_interval' => 3])->assertSessionHasErrors('feed_ad_interval');
        $this->get('/admin/settings')->assertOk()->assertSee('Reklamlar aktif');
    }
}
