<?php

namespace App\Location;

use App\Notifications\Inbox;
use App\Safety\Blocks;

use App\Models\Post;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

final class LocationData
{
    public function __construct(private readonly CityResolver $cities) {}

    public function update(User $viewer, array $data): ?object
    {
        return DB::transaction(function () use ($viewer, $data) {
            $user = User::lockForUpdate()->findOrFail($viewer->id);
            $latitude = Geo::grid($data['latitude'], 0.001);
            $longitude = Geo::grid($data['longitude'], 0.001);
            $resolved = $this->cities->resolve($latitude, $longitude);
            $city = $resolved && DB::table('cities')->where('id', $resolved)->where('is_active', true)->exists()
                ? $resolved : null;
            // An area the person picked by hand stays until they pick another one: the device never takes it over.
            if (!$data['history_only'] && $user->active_city_source !== 'manual') {
                $values = ['active_city_id' => $city, 'active_city_source' => $city ? 'device' : null];
                $user->forceFill($values)->save();
                $viewer->forceFill($values)->unsetRelation('activeCity');
            }
            $now = now();
            $previous = DB::table('user_locations')->where('user_id', $user->id)->first();
            $sharing = ! $data['history_only'] && $user->nearby_visible;
            $changed = ! $previous || (int) $previous->city_id !== (int) $city
                || Geo::distance($latitude, $longitude, $previous->latitude, $previous->longitude)
                    >= config('location.minimum_movement_meters')
                || $now->diffInSeconds(Carbon::parse($previous->recorded_at), true) >= config('location.refresh_seconds');

            // Background samples update history only, without advertising live presence.
            if (! $data['history_only'] && ($changed || (bool) $previous->visibility !== $sharing)) {
                DB::table('user_locations')->upsert([[
                    'user_id' => $user->id, 'city_id' => $city,
                    'latitude' => $latitude, 'longitude' => $longitude, 'accuracy' => (int) ceil($data['accuracy']),
                    'recorded_at' => $now, 'visibility' => $sharing, 'created_at' => $now, 'updated_at' => $now,
                ]], ['user_id'], ['city_id', 'latitude', 'longitude', 'accuracy', 'recorded_at', 'visibility', 'updated_at']);
            }

            if ($city && $user->location_history_enabled && $data['record_history'] && $data['accuracy'] <= 5000) {
                $this->remember($user->id, $city, $latitude, $longitude, $now);
            }

            return DB::table('cities')->select('id', 'name', 'slug')->where('id', $city)->first();
        });
    }

    private function remember(int $user, int $city, float $latitude, float $longitude, $now): void
    {
        $grid = config('location.history_grid');
        $latitude = Geo::grid($latitude, $grid);
        $longitude = Geo::grid($longitude, $grid);
        $last = DB::table('user_location_history')->where('user_id', $user)->latest('recorded_at')->first();
        if ($last && (int) $last->city_id === $city && (float) $last->latitude === $latitude
            && (float) $last->longitude === $longitude && $last->recorded_at >= $now->copy()->subMinutes(30)->toDateTimeString()) {
            return;
        }
        DB::table('user_location_history')->insert([
            'user_id' => $user, 'city_id' => $city, 'latitude' => $latitude,
            'longitude' => $longitude, 'recorded_at' => $now,
        ]);
    }

    public static function active(User $user): ?object
    {
        return DB::table('user_locations')->where('user_id', $user->id)
            ->where('recorded_at', '>=', now()->subMinutes(config('location.active_minutes')))->first();
    }

    public static function city(User $user, ?object $origin, ?int $chosen): int
    {
        return $chosen ?? $user->active_city_id ?? $origin?->city_id ?? $user->city_id;
    }

    public static function clearHistory(int $userId): void
    {
        DB::table('user_location_history')->where('user_id', $userId)->delete();
        DB::table('location_matches')->where('user_id', $userId)->delete();
    }

    public static function cutoff(): Carbon
    {
        return now()->subDays(app(\App\Administration\Settings::class)->get('location_history_days'));
    }

    public static function matchPost(Post $post): void
    {
        app(PostMatcher::class)->match($post);
    }
}
