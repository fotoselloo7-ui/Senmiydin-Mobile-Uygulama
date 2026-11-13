<?php

namespace App\MapNotes;

use App\Location\Geo;
use App\Models\MapNote;
use App\Notifications\Inbox;
use App\Safety\Blocks;
use Illuminate\Support\Facades\DB;

/**
 * Create-time fan-out: one "someone left a note near you" notification per eligible user, exactly once.
 * Uses the user's recent location (not Geçtiğim Yerler history) and never carries the author's identity.
 */
final class NearbyNotifier
{
    public function notify(MapNote $note): int
    {
        $origin = (object) ['latitude' => $note->approx_latitude, 'longitude' => $note->approx_longitude];
        $radius = (int) config('map_notes.nearby_notification_meters');
        [$distance, $bindings] = Geo::expression($origin, 'l.latitude', 'l.longitude');
        $recipients = DB::table('user_locations as l')->join('users as u', 'u.id', '=', 'l.user_id')
            ->where('l.city_id', $note->city_id)
            ->where('u.account_status', 'active')->where('u.id', '<>', $note->user_id)
            ->where('l.recorded_at', '>=', now()->subMinutes(config('location.active_minutes')))
            ->select('u.id')->selectRaw("($distance) AS meters", $bindings);
        Blocks::exclude($recipients, $note->user_id, 'u.id');
        Geo::bound($recipients, $origin, $radius, 'l.latitude', 'l.longitude');
        $ids = $recipients->whereRaw("($distance) <= ?", [...$bindings, $radius])
            ->orderBy('meters')->orderBy('u.id')->limit((int) config('map_notes.nearby_notification_limit'))->pluck('u.id');

        $sent = 0;
        foreach ($ids as $id) {
            // Inbox::add enforces the recipient's own preference (in-app and push) and block relations.
            $before = DB::table('app_notifications')->where('user_id', $id)->where('type', 'map_note_nearby')
                ->where('entity_id', $note->id)->exists();
            if ($before) {
                continue;
            }
            Inbox::add((int) $id, null, 'map_note_nearby', $note->id);
            $sent += DB::table('app_notifications')->where('user_id', $id)->where('type', 'map_note_nearby')
                ->where('entity_id', $note->id)->exists() ? 1 : 0;
        }

        return $sent;
    }
}
