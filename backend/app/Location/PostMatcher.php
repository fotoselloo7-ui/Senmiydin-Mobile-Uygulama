<?php

namespace App\Location;

use App\Models\Post;
use App\Models\User;
use App\Notifications\Inbox;
use App\Safety\Blocks;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

final class PostMatcher
{
    public function match(Post $post): void
    {
        if ($post->visibility !== 'city' || $post->trashed() || $post->encounter_id ||
            !User::whereKey($post->user_id)->where('account_status', 'active')->exists()) return;
        $travel = $post->type === 'travel' ? $post->travel : null;
        if ($post->approx_latitude === null && !$travel) return;
        $at = ($post->occurred_at ?? $travel?->departure_at ?? $post->created_at)->copy()->utc();
        if ($at->lt(LocationData::cutoff()) || $at->gt(now())) return;
        $origin = (object) ['latitude' => $post->approx_latitude, 'longitude' => $post->approx_longitude];
        $rules = config('location.matching');
        [$distance, $bindings] = Geo::expression($origin, 'h.latitude', 'h.longitude');
        $seconds = DB::getDriverName() === 'sqlite'
            ? "ABS(CAST(strftime('%s', h.recorded_at) AS INTEGER) - ?)"
            : 'ABS(TIMESTAMPDIFF(SECOND, h.recorded_at, ?))';
        $timeBinding = DB::getDriverName() === 'sqlite' ? $at->timestamp : $at->toDateTimeString();
        $day = $at->copy()->setTimezone('Europe/Istanbul')->startOfDay()->utc();
        $q = DB::table('user_location_history as h')->join('users as u', 'u.id', '=', 'h.user_id')
            ->where('u.location_history_enabled', true)->where('u.account_status', 'active')
            ->where('h.user_id', '<>', $post->user_id)->where('h.city_id', $post->city_id)
            ->where('h.recorded_at', '>=', LocationData::cutoff())->where('h.recorded_at', '<=', now())
            ->whereBetween('h.recorded_at', [$day, $day->copy()->addDay()->subSecond()])
            ->select('h.user_id')->selectRaw("($distance) AS meters, ($seconds) AS seconds", [...$bindings, $timeBinding]);
        Blocks::exclude($q, $post->user_id, 'h.user_id');
        Geo::bound($q, $origin, $rules['weak_meters'], 'h.latitude', 'h.longitude');
        if ($post->approx_latitude === null) $q->whereRaw('1 = 0');
        $eligible = DB::query()->fromSub($q, 'samples')->where('meters', '<=', $rules['weak_meters'])
            ->select('samples.*')->selectRaw(
                'CASE WHEN meters <= ? AND seconds <= ? THEN ? WHEN meters <= ? AND seconds <= ? THEN ? ELSE ? END AS score',
                [$rules['strong_meters'], $rules['strong_seconds'], $rules['strong_score'],
                 $rules['medium_meters'], $rules['medium_seconds'], $rules['medium_score'], $rules['weak_score']]
            );
        if ($travel) {
            $travelAt = ($travel->departure_at ?? $at)->copy()->utc();
            $travelSeconds = DB::getDriverName() === 'sqlite'
                ? "ABS(CAST(strftime('%s', h.recorded_at) AS INTEGER) - ?)"
                : 'ABS(TIMESTAMPDIFF(SECOND, h.recorded_at, ?))';
            $travelBinding = DB::getDriverName() === 'sqlite' ? $travelAt->timestamp : $travelAt->toDateTimeString();
            $route = DB::table('user_location_history as h')->join('users as u', 'u.id', '=', 'h.user_id')
                ->where('u.location_history_enabled', true)->where('u.account_status', 'active')
                ->where('h.user_id', '<>', $post->user_id)
                ->whereIn('h.city_id', [$travel->origin_city_id, $travel->destination_city_id])
                ->where('h.recorded_at', '>=', LocationData::cutoff())->where('h.recorded_at', '<=', now())
                ->whereBetween('h.recorded_at', [$travelAt->copy()->subSeconds($rules['travel_seconds']), $travelAt->copy()->addSeconds($rules['travel_seconds'])])
                ->select('h.user_id')->selectRaw("NULL AS meters, ($travelSeconds) AS seconds, ? AS score", [$travelBinding, $rules['medium_score']]);
            Blocks::exclude($route, $post->user_id, 'h.user_id');
            $eligible->unionAll($route);
        }
        $ranked = DB::query()->fromSub($eligible, 'scored')->select('scored.*')
            ->selectRaw('ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY score DESC, seconds, meters) AS sample_rank');
        DB::query()->fromSub($ranked, 'ranked')->where('sample_rank', 1)->orderBy('user_id')->chunk(100,
            function ($items) use ($post, $rules): void {
                foreach ($items as $item) {
                    DB::transaction(function () use ($post, $item, $rules): void {
                        $user = User::lockForUpdate()->find($item->user_id);
                        $author = User::find($post->user_id);
                        if (!$user?->location_history_enabled || $user->account_status !== 'active' ||
                            !$author || $author->account_status !== 'active' || Blocks::between($user->id, $author->id) ||
                            !Post::visibleTo($user)->whereKey($post->id)->exists()) return;
                        $strength = $item->score >= $rules['strong_score'] ? 'strong' : ($item->score >= $rules['medium_score'] ? 'medium' : 'weak');
                        $type = $strength === 'strong' ? 'location_match' : ($strength === 'medium' ? 'nearby_activity' : null);
                        $notify = $type !== null && Inbox::permitted($user, $type);
                        $inserted = DB::table('location_matches')->insertOrIgnore([
                            'user_id' => $user->id, 'post_id' => $post->id, 'matched_at' => now(),
                            'distance_meters' => $item->meters === null ? null : (int) round($item->meters), 'time_difference_seconds' => (int) $item->seconds,
                            'score' => (int) $item->score, 'strength' => $strength, 'status' => 'pending',
                            'notification_state' => $notify ? 'sent' : 'disabled',
                        ]);
                        if ($inserted && $notify) Inbox::add($user->id, null, $type, $post->id);
                    });
                }
            });
    }
}
