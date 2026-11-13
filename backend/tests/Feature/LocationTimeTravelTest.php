<?php

namespace Tests\Feature;

use App\Administration\Settings;
use App\Jobs\MatchLocationPost;
use App\Location\BoundaryCityResolver;
use App\Location\CityResolver;
use App\Location\LocationData;
use App\Location\PostMatcher;
use App\Models\City;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class LocationTimeTravelTest extends TestCase
{
    use RefreshDatabase;
    protected $seed = true;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-11-08 17:00:00', 'UTC'));
        Queue::fake();
    }
    protected function tearDown(): void { Carbon::setTestNow(); parent::tearDown(); }
    private function city(string $slug): int { return City::where('slug', $slug)->value('id'); }
    private function user(string $name, string $city = 'istanbul', bool $history = true, bool $notify = true): User
    {
        return User::create(['name' => $name, 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => '1995-01-01', 'password' => 'TestPassword1234', 'city_id' => $this->city($city),
            'location_history_enabled' => $history, 'nearby_visible' => true, 'push_preferences' => ['location_match' => $notify]]);
    }
    private function asUser(User $user): static
    {
        $this->app['auth']->forgetGuards();
        return $this->withToken($user->createToken('test')->plainTextToken);
    }
    private function sample(User $user, string $time = '2026-11-08 11:15:00', float $lat = 41.015, float $lng = 28.980, string $city = 'istanbul'): int
    {
        return DB::table('user_location_history')->insertGetId(['user_id' => $user->id, 'city_id' => $this->city($city),
            'latitude' => $lat, 'longitude' => $lng, 'recorded_at' => $time]);
    }
    private function draft(array $extra = []): array
    {
        return array_replace(['body' => 'Bugün burada gördüğüm kişi sen miydin?', 'type' => 'encounter',
            'city_id' => $this->city('istanbul'), 'visibility' => 'city', 'is_anonymous' => false,
            'request_id' => (string) Str::uuid()], $extra);
    }
    private function publish(User $user, array $extra = []): array
    {
        return $this->asUser($user)->postJson('/api/v1/posts', $this->draft($extra))->assertCreated()->json('data');
    }
    private function match(int $post): void { app(PostMatcher::class)->match(Post::findOrFail($post)); }

    public function test_device_city_uses_real_boundaries_and_profile_city_is_preserved(): void
    {
        $demo = $this->user('demo', 'alanya');
        $this->asUser($demo)->putJson('/api/v1/location', ['latitude' => 39.9208, 'longitude' => 32.8541, 'accuracy' => 20])
            ->assertOk()->assertJsonPath('data.city.name', 'Ankara')->assertJsonPath('data.manual_city_required', false);
        $this->getJson('/api/v1/profile')->assertJsonPath('data.city.name', 'Alanya')->assertJsonPath('data.active_city.name', 'Ankara');
        $writer = $this->user('ankara', 'ankara');
        $post = $this->publish($writer, ['city_id' => $this->city('ankara')]);
        $this->asUser($demo)->getJson('/api/v1/feed')->assertJsonPath('data.items.0.id', $post['id']);
        $this->putJson('/api/v1/location', ['latitude' => 36.544, 'longitude' => 32.000, 'accuracy' => 20])
            ->assertJsonPath('data.city.name', 'Alanya');
        $this->assertSame('Alanya', $demo->fresh()->city->name);
    }

    public function test_unknown_city_preserves_coordinates_and_manual_fallback_persists(): void
    {
        $user = $this->user('manual', 'alanya');
        $this->asUser($user)->putJson('/api/v1/location', ['latitude' => 0, 'longitude' => 0, 'accuracy' => 20])
            ->assertOk()->assertJsonPath('data.city', null)->assertJsonPath('data.manual_city_required', true);
        $this->assertDatabaseHas('user_locations', ['user_id' => $user->id, 'latitude' => 0, 'city_id' => null]);
        $this->putJson('/api/v1/active-city', ['city_id' => $this->city('ankara')])->assertOk();
        $this->getJson('/api/v1/auth/me')->assertJsonPath('data.active_city.name', 'Ankara')->assertJsonPath('data.city.name', 'Alanya');
        $this->putJson('/api/v1/location', ['latitude' => 0, 'longitude' => 0, 'accuracy' => 20])
            ->assertOk()->assertJsonPath('data.manual_city_required', false);
        $this->getJson('/api/v1/auth/me')->assertJsonPath('data.active_city.name', 'Ankara');
        $this->putJson('/api/v1/active-city', ['city_id' => 999999])->assertUnprocessable();
        config(['location.city_provider' => 'none']);
        $this->assertNull(app(BoundaryCityResolver::class)->resolve(39.9208, 32.8541));
    }

    public function test_gulhane_historical_time_match_boost_notification_and_privacy(): void
    {
        $demo = $this->user('demo');
        $elif = $this->user('elif');
        $selected = $this->sample($demo, '2026-11-08 11:20:00');
        $this->sample($elif, '2026-11-08 11:15:00');
        $this->sample($elif, '2026-11-08 11:30:00');
        $post = $this->publish($demo, ['location_source' => 'history', 'history_id' => $selected, 'occurred_at' => '2026-11-08T11:20:00Z']);
        Queue::assertPushed(MatchLocationPost::class);
        $this->match($post['id']);
        $this->match($post['id']);
        $this->assertDatabaseHas('location_matches', ['user_id' => $elif->id, 'post_id' => $post['id'], 'strength' => 'strong', 'score' => 90, 'notification_state' => 'sent']);
        $this->assertSame(1, DB::table('location_matches')->where('user_id', $elif->id)->count());
        $this->assertSame(1, DB::table('app_notifications')->where('user_id', $elif->id)->where('type', 'location_match')->count());
        $stored = Post::findOrFail($post['id']);
        $this->assertSame('2026-11-08 11:20:00', $stored->occurred_at->format('Y-m-d H:i:s'));
        $this->assertEquals(41.015, $stored->approx_latitude);
        $stored->update(['created_at' => now()->subHour()]);
        $this->publish($demo, ['body' => 'Daha yeni sıradan bir şehir paylaşımı.']);
        $feed = $this->asUser($elif)->getJson('/api/v1/feed')->assertOk()
            ->assertJsonPath('data.items.0.id', $post['id'])->assertJsonPath('data.items.0.match_hint', 'Geçtiğin bir bölgeden')
            ->assertJsonPath('data.items.0.encounter_confirmed', false)
            ->assertJsonMissingPath('data.items.0.approx_latitude')->assertJsonMissingPath('data.items.0.history_id')
            ->assertJsonMissingPath('data.items.0.time_difference_seconds')->json('data.items.0');
        $this->assertArrayNotHasKey('latitude', $feed);
        $this->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.type', 'location_match')
            ->assertJsonPath('data.items.0.route', '/post')->assertJsonPath('data.items.0.actor', null)->assertJsonPath('data.items.0.entity_id', $post['id']);
        $this->assertDatabaseCount('encounters', 0);
    }

    public function test_weak_and_medium_matches_use_time_distance_and_skip_other_days(): void
    {
        $author = $this->user('author');
        $weak = $this->user('weak');
        $medium = $this->user('medium');
        $old = $this->user('old');
        $this->sample($weak, '2026-11-08 05:00:00', 41.050);
        $this->sample($medium, '2026-11-08 10:00:00', 41.025);
        $this->sample($old, '2026-11-07 11:20:00');
        $post = $this->publish($author, ['location_source' => 'map', 'place_latitude' => 41.015, 'place_longitude' => 28.980, 'occurred_at' => '2026-11-08T11:20:00Z']);
        $this->match($post['id']);
        $this->assertDatabaseHas('location_matches', ['user_id' => $weak->id, 'strength' => 'weak']);
        $this->assertDatabaseHas('location_matches', ['user_id' => $medium->id, 'strength' => 'medium']);
        $this->assertDatabaseMissing('location_matches', ['user_id' => $old->id]);
        $this->assertDatabaseCount('app_notifications', 0);
    }

    public function test_history_consent_and_notification_preferences_are_independent(): void
    {
        $author = $this->user('author');
        $silent = $this->user('silent', notify: false);
        $disabled = $this->user('disabled', history: false);
        $this->sample($silent); $this->sample($disabled);
        $post = $this->publish($author, ['location_source' => 'map', 'place_latitude' => 41.015, 'place_longitude' => 28.980, 'occurred_at' => '2026-11-08T11:20:00Z']);
        $this->match($post['id']);
        $this->assertDatabaseHas('location_matches', ['user_id' => $silent->id, 'notification_state' => 'disabled']);
        $this->assertDatabaseMissing('location_matches', ['user_id' => $disabled->id]);
        $this->assertDatabaseCount('app_notifications', 0);
        $this->asUser($silent)->putJson('/api/v1/profile', ['location_history_enabled' => false])->assertOk();
        $this->assertDatabaseMissing('user_location_history', ['user_id' => $silent->id]);
        $this->assertDatabaseMissing('location_matches', ['user_id' => $silent->id]);
        $this->assertFalse($silent->fresh()->push_preferences['location_match']);
    }

    public function test_history_selector_is_owner_scoped_paged_coarse_and_revocable(): void
    {
        $owner = $this->user('owner'); $other = $this->user('other');
        $id = $this->sample($owner, '2026-11-08 11:29:00');
        for ($i = 0; $i < 21; $i++) $this->sample($owner);
        $this->asUser($owner)->getJson('/api/v1/location-history')->assertJsonCount(20, 'data.items')
            ->assertJsonPath('data.next_page', 2)->assertJsonMissingPath('data.items.0.latitude')->assertJsonMissingPath('data.items.0.longitude')
            ->assertJsonPath('data.items.0.recorded_at', '2026-11-08T11:00:00.000000Z');
        $this->asUser($other)->getJson('/api/v1/location-history')->assertJsonCount(0, 'data.items');
        $this->postJson('/api/v1/posts', $this->draft(['location_source' => 'history', 'history_id' => $id]))->assertUnprocessable();
        $owner->update(['location_history_enabled' => false]);
        $this->asUser($owner)->getJson('/api/v1/location-history')->assertJsonCount(0, 'data.items');
        $this->postJson('/api/v1/posts', $this->draft(['location_source' => 'history', 'history_id' => $id]))->assertUnprocessable();
    }

    public function test_occurrence_time_and_map_validation_do_not_accept_future_or_expired_places(): void
    {
        $user = $this->user('writer');
        foreach (['2026-11-09T11:20:00Z', '2026-10-01T11:20:00Z', 'invalid'] as $at) {
            $this->asUser($user)->postJson('/api/v1/posts', $this->draft(['occurred_at' => $at]))->assertUnprocessable();
        }
        $this->postJson('/api/v1/posts', $this->draft(['location_source' => 'map', 'place_latitude' => 91]))->assertUnprocessable();
        $expired = $this->sample($user, '2026-10-01 11:20:00');
        $this->postJson('/api/v1/posts', $this->draft(['location_source' => 'history', 'history_id' => $expired]))->assertUnprocessable();
        $this->postJson('/api/v1/posts', $this->draft(['location_source' => 'map', 'place_latitude' => 39.9208, 'place_longitude' => 32.8541]))->assertUnprocessable();
        $this->assertDatabaseCount('posts', 0);
    }

    public function test_occurrence_and_departure_offsets_are_normalized_to_utc(): void
    {
        $writer = $this->user('clock', 'ankara');
        $post = $this->publish($writer, ['type' => 'travel', 'city_id' => $this->city('ankara'),
            'occurred_at' => '2026-11-08T14:20:00+03:00',
            'travel' => array_replace($this->travelData(), ['departure_at' => '2026-11-08T19:30:00+03:00'])]);
        $stored = Post::findOrFail($post['id']);
        $this->assertSame('2026-11-08 11:20:00', $stored->occurred_at->format('Y-m-d H:i:s'));
        $this->assertSame('2026-11-08 16:30:00', $stored->travel->departure_at->format('Y-m-d H:i:s'));
    }

    private function travelData(bool $public = true): array
    {
        return ['transport_type' => 'bus', 'origin_city_id' => $this->city('ankara'),
            'destination_city_id' => $this->city('erzincan'), 'departure_at' => '2026-11-08T16:30:00Z',
            'operator_name' => 'Pamukkale', 'vehicle_identifier' => '07 NM 365', 'is_public' => $public];
    }

    public function test_pamukkale_travel_metadata_feed_recommendation_without_any_group(): void
    {
        $author = $this->user('traveller', 'ankara'); $reader = $this->user('passenger', 'ankara');
        $this->sample($reader, '2026-11-08 16:20:00', 39.920, 32.855, 'ankara');
        $post = $this->publish($author, ['type' => 'travel', 'city_id' => $this->city('ankara'),
            'body' => 'Aynı otobüsteysen bir sonraki molada kahve içelim mi? ☕', 'travel' => $this->travelData()]);
        $this->match($post['id']);
        $this->assertDatabaseHas('location_matches', ['user_id' => $reader->id, 'post_id' => $post['id'], 'strength' => 'medium', 'score' => 60, 'distance_meters' => null]);
        $this->asUser($reader)->getJson('/api/v1/feed')->assertJsonPath('data.items.0.travel.operator_name', 'Pamukkale')
            ->assertJsonPath('data.items.0.travel.origin.name', 'Ankara')->assertJsonPath('data.items.0.travel.destination.name', 'Erzincan')
            ->assertJsonPath('data.items.0.travel.vehicle_identifier', '07 NM 365')->assertJsonPath('data.items.0.match_hint', 'Geçtiğin bir bölgeden');
        $this->assertDatabaseCount('encounters', 0);
        $this->assertDatabaseCount('encounter_requests', 0);
        $this->assertDatabaseCount('app_notifications', 0);
    }

    public function test_private_travel_metadata_is_only_visible_to_owner_and_types_are_validated(): void
    {
        $author = $this->user('author', 'ankara'); $reader = $this->user('reader', 'ankara');
        $post = $this->publish($author, ['type' => 'travel', 'city_id' => $this->city('ankara'), 'travel' => $this->travelData(false)]);
        $this->assertSame('07 NM 365', $post['travel']['vehicle_identifier']);
        $this->asUser($reader)->getJson('/api/v1/posts/'.$post['id'])->assertJsonPath('data.travel', null);
        foreach (['train', 'plane', 'ferry', 'other'] as $type) {
            $this->publish($author, ['type' => 'travel', 'travel' => array_replace($this->travelData(), ['transport_type' => $type, 'vehicle_identifier' => null]), 'body' => 'Yolculuk '.$type]);
        }
        $this->asUser($author)->postJson('/api/v1/posts', $this->draft(['travel' => $this->travelData()]))->assertUnprocessable();
        $this->postJson('/api/v1/posts', $this->draft(['type' => 'travel', 'travel' => ['transport_type' => 'ship']]))->assertUnprocessable();
    }

    public function test_blocked_private_deleted_posts_and_history_retention_are_not_matched(): void
    {
        $author = $this->user('author'); $reader = $this->user('reader');
        $this->sample($reader);
        $post = $this->publish($author, ['location_source' => 'map', 'place_latitude' => 41.015, 'place_longitude' => 28.980, 'occurred_at' => '2026-11-08T11:20:00Z']);
        $this->asUser($reader)->putJson('/api/v1/blocks/'.$author->id)->assertOk();
        $this->match($post['id']);
        $this->assertDatabaseCount('location_matches', 0);
        $this->asUser($reader)->getJson('/api/v1/posts/'.$post['id'])->assertNotFound();
        $this->deleteJson('/api/v1/blocks/'.$author->id)->assertOk();
        $entry = Post::findOrFail($post['id']); $entry->update(['visibility' => 'private']);
        $this->match($entry->id); $this->assertDatabaseCount('location_matches', 0);
        $entry->update(['visibility' => 'city']); $entry->delete();
        app(PostMatcher::class)->match($entry);
    }

    public function test_duplicate_posts_comments_and_excessive_mentions_are_rejected_without_breaking_idempotency(): void
    {
        $author = $this->user('writer');
        app(Settings::class)->save(['moderation_post_repeats' => 2, 'moderation_comment_repeats' => 2]);
        $draft = $this->draft();
        $first = $this->asUser($author)->postJson('/api/v1/posts', $draft)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/posts', $draft)->assertOk()->assertJsonPath('data.id', $first);
        $this->publish($author);
        $this->postJson('/api/v1/posts', $this->draft())->assertUnprocessable();
        $this->postJson("/api/v1/posts/$first/comments", ['body' => 'Çok hızlı aynı yorum'])->assertCreated();
        $this->postJson("/api/v1/posts/$first/comments", ['body' => 'Çok hızlı aynı yorum'])->assertCreated();
        $this->postJson("/api/v1/posts/$first/comments", ['body' => 'Çok hızlı aynı yorum'])->assertUnprocessable();
        $this->postJson('/api/v1/posts', $this->draft(['body' => implode(' ', array_map(fn($i) => '@user'.$i, range(1, 9)))]))->assertUnprocessable();
        $this->assertDatabaseCount('posts', 2); $this->assertDatabaseCount('post_comments', 2);
    }

    public function test_url_and_word_moderation_is_configurable_and_avoids_substring_false_positives(): void
    {
        $user = $this->user('writer');
        app(Settings::class)->save(['moderation_banned_words' => 'tehditifadesi', 'moderation_blocked_domains' => 'spam.invalid']);
        foreach (['Bir tehditifadesi yazısı', 'https://sub.spam.invalid/abc', 'www.spam.invalid/path'] as $body) {
            $this->asUser($user)->postJson('/api/v1/posts', $this->draft(['body' => $body]))->assertUnprocessable();
        }
        $this->publish($user, ['body' => 'tehditifadesinin uzun sözcüğü ve https://spam.invalid.safe.test/ güvenli alanı']);
        $this->assertDatabaseCount('posts', 1);
    }

    private function gps(): UploadedFile
    {
        return new UploadedFile(base_path('tests/Fixtures/gps-image.jpg'), 'original-private-place.jpg', 'image/jpeg', null, true);
    }
    private function cleanImage(string $bytes): void
    {
        $this->assertStringNotContainsString('TEST-PRIVATE-GPS', $bytes);
        $this->assertStringNotContainsString('Exif', $bytes);
        $this->assertNotFalse(imagecreatefromstring($bytes));
    }

    public function test_exif_gps_is_removed_for_post_avatar_message_and_joint_story(): void
    {
        Storage::fake(config('mobile.post_media_disk')); Storage::fake(config('mobile.avatar_disk'));
        $author = $this->user('author'); $target = $this->user('target');
        $this->assertStringContainsString('Exif', $this->gps()->get());
        $post = $this->publish($author, ['encounter_target_id' => $target->id, 'media' => [$this->gps()]]);
        $this->assertStringNotContainsString('original-private-place', $post['media'][0]['url']);
        $this->cleanImage($this->asUser($author)->get($post['media'][0]['url'])->assertOk()->streamedContent());
        $avatar = $this->postJson('/api/v1/profile/avatar', ['avatar' => $this->gps()])->assertOk()->json('data.avatar');
        $this->cleanImage($this->get($avatar)->assertOk()->streamedContent());
        $message = $this->postJson('/api/v1/users/'.$target->id.'/messages', ['image' => $this->gps(), 'request_id' => (string)Str::uuid()])->assertCreated()->json('data.message.image');
        $this->cleanImage($this->get($message)->assertOk()->streamedContent());
        $invitation = $post['encounter_request_id'];
        $encounter = $this->asUser($target)->postJson("/api/v1/encounter-requests/$invitation/accept")->assertOk()->json('data.encounter_id');
        $story = $this->publish($author, ['encounter_id' => $encounter, 'story_title' => 'Güzel bir karşılaşma', 'media' => [$this->gps()]]);
        $this->cleanImage($this->asUser($author)->get($story['media'][0]['url'])->assertOk()->streamedContent());
    }

    public function test_invalid_executable_svg_and_corrupt_uploads_are_rejected(): void
    {
        $author = $this->user('writer');
        foreach ([UploadedFile::fake()->createWithContent('photo.jpg', '<?php echo 1; ?>'),
            UploadedFile::fake()->createWithContent('image.svg', '<svg xmlns="http://www.w3.org/2000/svg"/>'),
            UploadedFile::fake()->createWithContent('photo.jpg.php', file_get_contents(base_path('tests/Fixtures/gps-image.jpg')))] as $file) {
            $this->asUser($author)->postJson('/api/v1/posts', $this->draft(['media' => [$file]]))->assertUnprocessable();
        }
        $this->assertDatabaseCount('post_media', 0);
    }
}
