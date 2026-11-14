<?php

namespace App\Location;

use App\Models\Post;
use App\Models\User;
use App\Notifications\Inbox;
use App\Safety\Blocks;
use Illuminate\Support\Facades\DB;

/**
 * "Yakınında yeni bir paylaşım var": when a city-visible post with an approximate place is created, people who are
 * actually near that place right now (fresh location sample) get one `nearby_post` notification.
 *
 * Deliberately separate from the Geçtiğim Yerler history matcher (PostMatcher → location_match / nearby_activity):
 * it reads only the current location sample, never the history, and never carries the author's identity.
 * Radius, freshness and the per-run cap live in config('location.current_nearby').
 */
final class CurrentNearby
{
    public function notify(Post $post): int
    {
        if ($post->visibility !== 'city' || $post->trashed() || $post->encounter_id || $post->approx_latitude === null ||
            ! User::whereKey($post->user_id)->where('account_status', 'active')->exists()) {
            return 0;
        }
        $rules = config('location.current_nearby');
        $origin = (object) ['latitude' => $post->approx_latitude, 'longitude' => $post->approx_longitude];
        [$distance, $bindings] = Geo::expression($origin, 'l.latitude', 'l.longitude');
        $recipients = DB::table('user_locations as l')->join('users as u', 'u.id', '=', 'l.user_id')
            // Same active city as the post and a location sample that is still fresh.
            ->where('l.city_id', $post->city_id)
            ->where('u.account_status', 'active')->where('u.id', '<>', $post->user_id)
            ->where('l.recorded_at', '>=', now()->subMinutes($rules['freshness_minutes']))
            ->select('u.id')->selectRaw("($distance) AS meters", $bindings);
        // Blocks::exclude covers blocks in both directions and the teen / adult separation relative to the author.
        Blocks::exclude($recipients, $post->user_id, 'u.id');
        Geo::bound($recipients, $origin, $rules['radius_meters'], 'l.latitude', 'l.longitude');
        $ids = $recipients->whereRaw("($distance) <= ?", [...$bindings, $rules['radius_meters']])
            ->orderBy('meters')->orderBy('u.id')->limit($rules['max_recipients'])->pluck('u.id');

        $sent = 0;
        foreach ($ids as $id) {
            // One notification per post and person: a stronger (history based) match for the same post wins.
            $already = DB::table('app_notifications')->where('user_id', $id)->where('entity_id', $post->id)
                ->whereIn('type', ['location_match', 'nearby_activity', 'nearby_post'])->exists()
                || DB::table('location_matches')->where('user_id', $id)->where('post_id', $post->id)->exists();
            $recipient = User::find($id);
            if ($already || ! $recipient || ! Post::visibleTo($recipient)->whereKey($post->id)->exists()) {
                continue;
            }
            // Inbox::add applies the recipient's own "nearby_activity" preference (in-app and push) and block rules.
            Inbox::add((int) $id, null, 'nearby_post', $post->id);
            $sent += DB::table('app_notifications')->where('user_id', $id)->where('type', 'nearby_post')->where('entity_id', $post->id)->exists() ? 1 : 0;
        }

        return $sent;
    }
}
