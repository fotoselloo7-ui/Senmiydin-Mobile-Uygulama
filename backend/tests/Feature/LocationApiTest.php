<?php

namespace Tests\Feature;

use App\Location\CityResolver;
use App\Location\LocationData;
use App\Models\City;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class LocationApiTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $city;

    protected function setUp(): void
    {
        parent::setUp();
        $this->city = City::where('slug', 'alanya')->value('id');
    }

    public function test_location_update_requires_valid_input_and_limits_repeated_writes(): void
    {
        $user = $this->user('viewer');
        $this->putJson('/api/v1/location', [])->assertUnauthorized();
        $this->asUser($user)->putJson('/api/v1/location', [
            'latitude' => 91, 'longitude' => 32, 'accuracy' => -1,
        ])->assertUnprocessable();
        $this->sample($user, 36.54423, 32.00017)->assertOk()
            ->assertJsonPath('data.city.name', 'Alanya')->assertJsonMissingPath('data.latitude');
        $first = DB::table('user_locations')->sole();
        $this->assertEquals(36.544, $first->latitude);
        $this->assertEquals(32.000, $first->longitude);
        $this->travel(2)->minutes();
        $this->sample($user, 36.544, 32.000)->assertOk();
        $this->assertSame($first->recorded_at, DB::table('user_locations')->sole()->recorded_at);
        $this->sample($user, 36.550, 32.000)->assertOk();
        $this->assertNotSame($first->recorded_at, DB::table('user_locations')->sole()->recorded_at);
        $this->asUser($user)->deleteJson('/api/v1/location')->assertOk();
        $this->assertDatabaseCount('user_locations', 0);
    }

    public function test_nearby_filters_by_distance_city_age_status_and_privacy(): void
    {
        $viewer = $this->user('viewer');
        $near = $this->user('near');
        $far = $this->user('far');
        $hidden = $this->user('hidden', false);
        $expired = $this->user('expired');
        $inactive = $this->user('inactive');
        $outside = $this->user('outside', city: City::where('slug', 'antalya')->value('id'));
        $this->asUser($viewer)->getJson('/api/v1/nearby/users')
            ->assertJsonPath('data.location_required', true);
        $this->sample($viewer, 36.544, 32.000)->assertOk();
        $this->sample($far, 36.560, 32.000)->assertOk();
        $this->sample($near, 36.544, 32.004)->assertOk();
        $this->sample($hidden, 36.545, 32.000)->assertOk();
        $this->sample($expired, 36.546, 32.000)->assertOk();
        $this->sample($inactive, 36.547, 32.000)->assertOk();
        $this->sample($outside, 36.890, 30.700)->assertOk();
        DB::table('user_locations')->where('user_id', $expired->id)->update(['recorded_at' => now()->subHour()]);
        $inactive->forceFill(['account_status' => 'disabled'])->save();

        $this->asUser($viewer)->getJson('/api/v1/nearby/users?radius=5000')
            ->assertOk()->assertJsonCount(2, 'data.items')
            ->assertJsonPath('data.items.0.username', 'near')
            ->assertJsonPath('data.items.0.distance_meters', 400)
            ->assertJsonPath('data.items.1.username', 'far')
            ->assertJsonMissingPath('data.items.0.latitude')
            ->assertJsonMissingPath('data.items.0.longitude')
            ->assertJsonMissingPath('data.items.0.accuracy')
            ->assertJsonMissingPath('data.items.0.recorded_at');
        $this->asUser($viewer)->getJson('/api/v1/nearby/users?radius=500&limit=1')
            ->assertJsonCount(1, 'data.items');
        $this->asUser($near)->putJson('/api/v1/profile', ['nearby_visible' => false])->assertOk();
        $this->asUser($viewer)->getJson('/api/v1/nearby/users')->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.username', 'far');
        $this->asUser($viewer)->getJson('/api/v1/nearby/users?limit=31')->assertUnprocessable();
    }

    public function test_resolved_city_is_distinct_from_the_profile_city(): void
    {
        $viewer = $this->user('viewer');
        $otherCity = City::where('slug', 'izmir')->value('id');
        $this->app->instance(CityResolver::class, new class($otherCity) implements CityResolver
        {
            public function __construct(private readonly int $id) {}

            public function resolve(float $latitude, float $longitude): ?int
            {
                return $this->id;
            }
        });
        $this->sample($viewer, 38.42, 27.14)->assertJsonPath('data.city.id', $otherCity);
        $this->asUser($viewer)->getJson('/api/v1/auth/me')->assertJsonPath('data.city_id', $this->city);
    }

    public function test_nearby_feed_and_map_filter_approximate_points_without_restricting_general_feed(): void
    {
        $viewer = $this->user('viewer');
        $author = $this->user('writer');
        $this->sample($viewer, 36.544, 32.000)->assertOk();
        $this->sample($author, 36.54411, 32.00642)->assertOk();
        $near = $this->publish($author, true);
        $this->sample($author, 36.547, 32.080)->assertOk();
        $far = $this->publish($author, true);
        $plain = $this->publish($author, false);
        $private = $this->publish($author, true, 'private');
        $this->asUser($viewer)->getJson('/api/v1/feed?sort=nearby')->assertOk()
            ->assertJsonPath('data.items.0.id', $near)
            ->assertJsonPath('data.items.1.id', $far)
            ->assertJsonPath('data.items.2.id', $plain)
            ->assertJsonPath('data.items.0.location_label', 'Alanya')
            ->assertJsonMissingPath('data.items.0.approx_latitude')
            ->assertJsonMissingPath('data.items.0.latitude');
        // The same approximate grid point the map shows (never an exact position), only for a post that has a place.
        $this->asUser($viewer)->getJson('/api/v1/feed?sort=nearby')
            ->assertJsonPath('data.items.0.map_point.latitude', 36.545)->assertJsonPath('data.items.0.map_point.longitude', 32.005)
            ->assertJsonPath('data.items.2.map_point', null);
        $this->asUser($viewer)->getJson("/api/v1/posts/$near")->assertOk()
            ->assertJsonPath('data.map_point.latitude', 36.545)->assertJsonPath('data.map_point.longitude', 32.005);
        $this->asUser($viewer)->getJson('/api/v1/feed?sort=nearby&radius=5000')->assertJsonCount(1, 'data.items');
        $this->asUser($viewer)->getJson('/api/v1/feed?sort=nearby&radius=10000')->assertJsonCount(2, 'data.items');
        $this->asUser($viewer)->getJson('/api/v1/feed')->assertJsonCount(3, 'data.items');
        $this->asUser($viewer)->getJson('/api/v1/map/posts?radius=5000')->assertOk()
            ->assertJsonCount(1, 'data.items')->assertJsonPath('data.items.0.post_id', $near)
            ->assertJsonPath('data.items.0.latitude', 36.545)->assertJsonPath('data.items.0.longitude', 32.005);
        $this->asUser($viewer)->getJson('/api/v1/map/posts?radius=10000')->assertJsonCount(2, 'data.items');
        $this->assertNull(Post::findOrFail($private)->approx_latitude);
        $this->asUser($viewer)->getJson("/api/v1/posts/$private")->assertNotFound();
        $this->asUser($author)->deleteJson("/api/v1/posts/$near")->assertOk();
        $this->asUser($viewer)->getJson('/api/v1/map/posts')->assertJsonCount(1, 'data.items');
    }

    public function test_history_is_opt_in_coarse_revocable_and_background_does_not_advertise_presence(): void
    {
        $user = $this->user('viewer');
        $this->sample($user, 36.5432, 32.0068)->assertOk();
        $this->assertDatabaseCount('user_location_history', 0);
        $this->asUser($user)->putJson('/api/v1/profile', ['location_history_enabled' => true])
            ->assertOk()->assertJsonPath('data.location_history_enabled', true);
        $this->sample($user, 36.5432, 32.0068, true)->assertOk();
        $history = DB::table('user_location_history')->sole();
        $this->assertEquals(36.545, $history->latitude);
        $this->assertEquals(32.005, $history->longitude);
        $this->sample($user, 36.5601, 32.0201, true)->assertOk();
        $this->assertDatabaseCount('user_location_history', 2);
        $this->assertEquals(36.543, DB::table('user_locations')->sole()->latitude);
        $this->asUser($user)->putJson('/api/v1/profile', ['location_history_enabled' => false])->assertOk();
        $this->sample($user, 36.564, 32.000, true)->assertOk();
        $this->assertDatabaseCount('user_location_history', 0);
    }

    public function test_retention_and_duplicate_matches(): void
    {
        $viewer = $this->user('viewer');
        $author = $this->user('writer');
        $viewer->forceFill(['location_history_enabled' => true])->save();
        $this->sample($viewer, 36.545, 32.005)->assertOk();
        $this->sample($author, 36.545, 32.005)->assertOk();
        $id = $this->publish($author, true);
        LocationData::matchPost(Post::findOrFail($id));
        $this->assertDatabaseCount('location_matches', 1);
        $this->assertDatabaseHas('location_matches', ['user_id' => $viewer->id, 'post_id' => $id, 'status' => 'pending']);
        $this->travel(config('location.history_days') + 1)->days();
        $this->artisan('location:purge')->assertExitCode(0);
        $this->assertDatabaseCount('user_location_history', 0);
        $this->assertDatabaseCount('location_matches', 0);
        $this->assertDatabaseCount('user_locations', 0);
    }

    private function user(string $name, bool $visible = true, ?int $city = null): User
    {
        return User::create([
            'username' => $name, 'name' => $name, 'email' => "$name@example.test",
            'birth_date' => '1998-04-12', 'password' => 'KonumDeneme123',
            'city_id' => $city ?? $this->city, 'nearby_visible' => $visible, 'city_discovery' => true, 'encounter_suggestions' => true,
        ]);
    }

    private function asUser(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    private function sample(User $user, float $latitude, float $longitude, bool $historyOnly = false)
    {
        return $this->asUser($user)->putJson('/api/v1/location', [
            'latitude' => $latitude, 'longitude' => $longitude, 'accuracy' => 30, 'history_only' => $historyOnly,
        ]);
    }

    private function publish(User $user, bool $attach, string $visibility = 'city'): int
    {
        return $this->asUser($user)->postJson('/api/v1/posts', [
            'body' => 'Bir şehir paylaşımı', 'type' => 'moment', 'city_id' => $this->city,
            'visibility' => $visibility, 'is_anonymous' => true,
            'attach_location' => $attach, 'request_id' => (string) Str::uuid(),
        ])->assertCreated()->json('data.id');
    }
}
