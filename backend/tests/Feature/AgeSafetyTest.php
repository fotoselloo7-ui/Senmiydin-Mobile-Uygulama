<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\Post;
use App\Models\User;
use App\Safety\AgeSafety;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * TEEN (16–17) / ADULT (18+) separation: enforced on the server, derived from the birth date only.
 * "Teen" accounts only ever meet other teen accounts; adults only meet adults.
 */
class AgeSafetyTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $city;

    private User $teenA;

    private User $teenB;

    private User $adultA;

    private User $adultB;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-11-14 12:00:00', 'UTC'));
        $this->city = City::where('slug', 'alanya')->value('id');
        $this->teenA = $this->user('teena', '2010-06-01');   // 16
        $this->teenB = $this->user('teenb', '2009-03-01');   // 17
        $this->adultA = $this->user('adulta', '1995-01-01');
        $this->adultB = $this->user('adultb', '2000-05-05');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function user(string $name, string $birth, array $extra = []): User
    {
        return User::create(['name' => ucfirst($name).' Test', 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => $birth, 'password' => 'TestPassword1234', 'city_id' => $this->city, ...$extra]);
    }

    private function as(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    private function makePost(User $user, string $body): Post
    {
        return Post::forceCreate(['body' => $body, 'user_id' => $user->id, 'city_id' => $this->city, 'type' => 'moment',
            'visibility' => 'city', 'request_id' => (string) Str::uuid()]);
    }

    private function locate(User $user, float $lat, float $lng): void
    {
        $user->forceFill(['nearby_visible' => true, 'city_discovery' => true, 'active_city_id' => $this->city])->save();
        DB::table('user_locations')->upsert([['user_id' => $user->id, 'city_id' => $this->city, 'latitude' => $lat, 'longitude' => $lng,
            'accuracy' => 20, 'recorded_at' => now(), 'visibility' => true, 'created_at' => now(), 'updated_at' => now()]],
            ['user_id'], ['city_id', 'latitude', 'longitude', 'accuracy', 'recorded_at', 'visibility', 'updated_at']);
    }

    public function test_band_is_derived_from_the_birth_date_with_an_exact_eighteenth_birthday_boundary(): void
    {
        $this->assertSame('teen', AgeSafety::band('2010-06-01'));
        $this->assertSame('teen', AgeSafety::band('2008-11-15'), 'Turns 18 tomorrow: still a teen.');
        $this->assertSame('adult', AgeSafety::band('2008-11-14'), 'Turns 18 today: adult.');
        $this->assertSame('adult', AgeSafety::band('1990-01-01'));
        $this->assertSame('teen', AgeSafety::bandOf($this->teenA->id));
        $this->assertSame('adult', AgeSafety::bandOf($this->adultA->id));
    }

    public function test_the_band_cannot_be_changed_through_the_api(): void
    {
        $this->as($this->teenA)->putJson('/api/v1/profile', ['birth_date' => '1990-01-01', 'age_band' => 'adult'])->assertStatus(200);
        $this->assertSame('2010-06-01', $this->teenA->fresh()->birth_date->toDateString());
        $this->as($this->teenA)->getJson('/api/v1/profile')->assertJsonPath('data.age_band', 'teen');
    }

    public function test_registration_accepts_sixteen_and_rejects_fifteen(): void
    {
        $register = fn (string $birth, string $name) => $this->postJson('/api/v1/auth/register', [
            'name' => 'Yeni Kullanıcı', 'username' => $name, 'email' => $name.'@example.test', 'password' => 'TestPassword1234',
            'password_confirmation' => 'TestPassword1234', 'birth_date' => $birth, 'city_id' => $this->city,
            'accepted_terms' => true, 'device_name' => 'test',
        ]);
        $register(now('Europe/Istanbul')->subYears(15)->subDay()->toDateString(), 'onbes')->assertStatus(422)->assertJsonValidationErrors('birth_date');
        $register(now('Europe/Istanbul')->subYears(16)->toDateString(), 'onaltisi')->assertStatus(201);
        $this->assertFalse(User::where('username', 'onaltisi')->value('nearby_visible'), 'Teen nearby discovery stays off by default.');
    }

    public function test_user_search_and_profiles_stay_inside_the_band(): void
    {
        $this->as($this->teenA)->getJson('/api/v1/search?type=users&q=teenb')->assertOk()
            ->assertJsonCount(1, 'data.items')->assertJsonPath('data.items.0.username', 'teenb');
        $this->as($this->teenA)->getJson('/api/v1/search?type=users&q=adult')->assertOk()->assertJsonCount(0, 'data.items');
        $this->as($this->adultA)->getJson('/api/v1/search?type=users&q=teen')->assertOk()->assertJsonCount(0, 'data.items');
        $this->as($this->adultA)->getJson('/api/v1/search?type=users&q=adultb')->assertOk()->assertJsonCount(1, 'data.items');

        $this->as($this->teenA)->getJson('/api/v1/users/teenb')->assertOk();
        $this->as($this->teenA)->getJson('/api/v1/users/adulta')->assertNotFound();
        $this->as($this->adultA)->getJson('/api/v1/users/teena')->assertNotFound();
        $this->as($this->adultA)->getJson('/api/v1/users/adultb')->assertOk();
    }

    public function test_follow_followers_and_following_do_not_cross_bands(): void
    {
        $this->as($this->teenA)->postJson('/api/v1/users/teenb/follow')->assertSuccessful();
        $this->as($this->teenA)->postJson('/api/v1/users/adulta/follow')->assertNotFound();
        $this->as($this->adultA)->postJson('/api/v1/users/teena/follow')->assertNotFound();
        $this->as($this->adultA)->postJson('/api/v1/users/adultb/follow')->assertSuccessful();
        $this->assertDatabaseMissing('user_follows', ['follower_id' => $this->adultA->id, 'followed_id' => $this->teenA->id]);
        // A follow row that predates the separation never leaks across it.
        DB::table('user_follows')->insert(['follower_id' => $this->adultA->id, 'followed_id' => $this->teenA->id, 'created_at' => now()]);
        $names = fn (User $viewer, string $user, string $list) => array_column($this->as($viewer)->getJson("/api/v1/users/$user/$list")->assertOk()->json('data.items'), 'username');
        $this->assertNotContains('adulta', $names($this->teenA, 'teena', 'followers'));
        $this->assertNotContains('teena', $names($this->adultA, 'adulta', 'following'));
        $this->assertContains('adultb', $names($this->adultA, 'adulta', 'following'));
    }

    public function test_feed_posts_and_comments_stay_inside_the_band(): void
    {
        $teenPost = $this->makePost($this->teenA, 'Genç gönderisi');
        $adultPost = $this->makePost($this->adultA, 'Yetişkin gönderisi');

        $bodies = fn (User $viewer) => array_column($this->as($viewer)->getJson('/api/v1/feed')->assertOk()->json('data.items'), 'body');
        $this->assertContains('Genç gönderisi', $bodies($this->teenB));
        $this->assertNotContains('Yetişkin gönderisi', $bodies($this->teenB));
        $this->assertContains('Yetişkin gönderisi', $bodies($this->adultB));
        $this->assertNotContains('Genç gönderisi', $bodies($this->adultB));

        $this->as($this->adultB)->getJson('/api/v1/posts/'.$teenPost->id)->assertNotFound();
        $this->as($this->teenB)->getJson('/api/v1/posts/'.$adultPost->id)->assertNotFound();
        $this->as($this->adultB)->postJson('/api/v1/posts/'.$teenPost->id.'/comments', ['body' => 'Merhaba', 'request_id' => (string) Str::uuid()])->assertNotFound();
        $this->as($this->adultB)->postJson('/api/v1/posts/'.$teenPost->id.'/like')->assertNotFound();
        $this->as($this->teenB)->postJson('/api/v1/posts/'.$teenPost->id.'/comments', ['body' => 'Merhaba', 'request_id' => (string) Str::uuid()])->assertCreated();
        $this->as($this->teenA)->getJson('/api/v1/posts/'.$teenPost->id.'/comments')->assertOk()->assertJsonCount(1, 'data.items');
    }

    public function test_a_comment_written_before_the_barrier_is_hidden_from_the_other_band(): void
    {
        $post = $this->makePost($this->adultA, 'Herkese açık');
        DB::table('post_comments')->insert(['post_id' => $post->id, 'user_id' => $this->teenA->id, 'body' => 'Eski yorum', 'created_at' => now(), 'updated_at' => now()]);
        $this->as($this->adultB)->getJson('/api/v1/posts/'.$post->id.'/comments')->assertOk()->assertJsonCount(0, 'data.items');
    }

    public function test_direct_messages_and_requests_are_never_created_across_bands(): void
    {
        $send = fn (User $from, User $to) => $this->as($from)->postJson('/api/v1/users/'.$to->id.'/messages', ['body' => 'Merhaba', 'request_id' => (string) Str::uuid()]);
        $send($this->teenA, $this->adultA)->assertStatus(404);
        $send($this->adultA, $this->teenA)->assertStatus(404);
        $this->assertDatabaseCount('conversations', 0);
        $this->assertDatabaseCount('messages', 0);
        $send($this->teenA, $this->teenB)->assertCreated();
        $send($this->adultA, $this->adultB)->assertCreated();
        $this->assertDatabaseCount('conversations', 2);
    }

    public function test_an_existing_conversation_locks_when_the_bands_stop_matching(): void
    {
        // Two accounts talk as peers; one then turns 18 (the other stays 17): the chat is sealed for both sides.
        $near = $this->user('almost', '2008-11-20');  // 17, turns 18 on 2026-11-20
        $this->as($near)->postJson('/api/v1/users/'.$this->teenB->id.'/messages', ['body' => 'Selam', 'request_id' => (string) Str::uuid()])->assertCreated();
        $id = DB::table('conversations')->value('id');
        $this->as($this->teenB)->getJson('/api/v1/conversations/'.$id)->assertOk();

        Carbon::setTestNow(Carbon::parse('2026-11-21 12:00:00', 'UTC'));
        $this->assertSame('adult', AgeSafety::bandOf($near->id), 'The band follows the birth date automatically.');
        $this->as($this->teenB)->getJson('/api/v1/conversations/'.$id)->assertNotFound();
        $this->as($near)->getJson('/api/v1/conversations/'.$id)->assertNotFound();
        $this->as($near)->postJson('/api/v1/users/'.$this->teenB->id.'/messages', ['body' => 'Hâlâ orada mısın?', 'request_id' => (string) Str::uuid()])->assertNotFound();
        $this->assertDatabaseCount('messages', 1);
        // ...and it behaves as an adult from now on.
        $this->as($near)->getJson('/api/v1/users/adulta')->assertOk();
        $this->as($near)->getJson('/api/v1/users/teenb')->assertNotFound();
    }

    public function test_nearby_people_exclude_the_other_band(): void
    {
        $this->locate($this->teenA, 36.544, 32.000);
        $this->locate($this->teenB, 36.5441, 32.0002);
        $this->locate($this->adultA, 36.5442, 32.0003);
        $this->as($this->teenA)->getJson('/api/v1/nearby/users')->assertOk()
            ->assertJsonCount(1, 'data.items')->assertJsonPath('data.items.0.username', 'teenb');
        $this->as($this->adultA)->getJson('/api/v1/nearby/users')->assertOk()->assertJsonCount(0, 'data.items');
        $this->locate($this->adultB, 36.5443, 32.0001);
        $this->as($this->adultA)->getJson('/api/v1/nearby/users')->assertOk()
            ->assertJsonCount(1, 'data.items')->assertJsonPath('data.items.0.username', 'adultb');
    }

    public function test_encounter_tag_search_and_requests_do_not_cross_bands(): void
    {
        $this->as($this->teenA)->getJson('/api/v1/search?type=users&encounter=1&q=adulta')->assertOk()->assertJsonCount(0, 'data.items');
        $this->as($this->teenA)->postJson('/api/v1/posts', [
            'body' => 'Sahilde karşılaştık', 'type' => 'encounter', 'city_id' => $this->city, 'visibility' => 'city',
            'encounter_target_id' => $this->adultA->id, 'request_id' => (string) Str::uuid(),
        ])->assertUnprocessable();
        $this->assertDatabaseCount('encounter_requests', 0);
        $this->as($this->teenA)->postJson('/api/v1/posts', [
            'body' => 'Sahilde karşılaştık', 'type' => 'encounter', 'city_id' => $this->city, 'visibility' => 'city', 'is_anonymous' => false,
            'encounter_target_id' => $this->teenB->id, 'request_id' => (string) Str::uuid(),
        ])->assertCreated();
        $this->assertDatabaseCount('encounter_requests', 1);
    }

    public function test_map_notes_and_replies_stay_inside_the_band(): void
    {
        $payload = fn () => ['body' => 'Seni burada gördüm, yarın yine buradayım.', 'is_anonymous' => false, 'city_id' => $this->city,
            'latitude' => 36.5446, 'longitude' => 32.0021, 'request_id' => (string) Str::uuid()];
        $note = $this->as($this->teenA)->postJson('/api/v1/map-notes', $payload())->assertCreated()->json('data');
        foreach ([$this->teenB, $this->adultA] as $viewer) {
            $this->locate($viewer, 36.5446, 32.0021);
        }
        $this->as($this->adultA)->getJson('/api/v1/map-notes/'.$note['id'])->assertNotFound();
        $this->as($this->adultA)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Merhaba', 'request_id' => (string) Str::uuid()])->assertNotFound();
        $this->as($this->adultA)->getJson('/api/v1/map/notes?city_id='.$this->city)->assertOk()->assertJsonCount(0, 'data.items');
        $this->as($this->teenB)->getJson('/api/v1/map-notes/'.$note['id'])->assertOk();
        $this->as($this->teenB)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Merhaba', 'request_id' => (string) Str::uuid()])->assertCreated();
    }

    public function test_notifications_never_cross_bands(): void
    {
        $post = $this->makePost($this->adultA, 'Gönderi');
        \App\Notifications\Inbox::add($this->adultB->id, $this->teenA->id, 'follow');
        \App\Notifications\Inbox::add($this->teenA->id, $this->adultA->id, 'like', $post->id);
        $this->assertDatabaseCount('app_notifications', 0);
        \App\Notifications\Inbox::add($this->adultB->id, $this->adultA->id, 'like', $post->id);
        $this->assertDatabaseCount('app_notifications', 1);
    }

    public function test_location_matching_and_nearby_activity_skip_the_other_band(): void
    {
        $this->assertTrue(\App\Safety\Blocks::between($this->teenA->id, $this->adultA->id));
        $this->assertTrue(\App\Safety\Blocks::between($this->adultA->id, $this->teenA->id));
        $this->assertFalse(\App\Safety\Blocks::between($this->teenA->id, $this->teenB->id));
        $this->assertFalse(\App\Safety\Blocks::between($this->adultA->id, $this->adultB->id));
    }
}
