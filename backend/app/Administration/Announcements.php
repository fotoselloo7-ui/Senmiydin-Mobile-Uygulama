<?php

namespace App\Administration;

use App\Location\Geo;
use App\Models\User;
use App\Notifications\Inbox;
use Illuminate\Support\Facades\DB;

final class Announcements
{
    public function publishBatch(int $id): bool
    {
        return DB::transaction(function () use ($id): bool {
            $entry = DB::table('announcements')->where('is_active', true)->whereNull('published_at')
                ->where('publish_at', '<=', now())
                ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))
                ->lockForUpdate()->find($id);
            if (! $entry) {
                return false;
            }
            $users = $this->recipients($entry);
            $delivered = 0;
            foreach ($users as $user) {
                Inbox::add($user, null, 'system', $id, (bool) $entry->show_in_app, (bool) $entry->send_push, $id);
                $delivered += DB::table('app_notifications')->where('user_id', $user)->where('announcement_id', $id)->exists() ? 1 : 0;
            }
            $complete = $users->count() < 100;
            DB::table('announcements')->where('id', $id)->update([
                'last_user_id' => $users->last() ?? $entry->last_user_id,
                'targeted_count' => DB::raw('targeted_count + '.$users->count()),
                'delivered_count' => DB::raw('delivered_count + '.$delivered),
                'published_at' => $complete ? now() : null, 'updated_at' => now(),
            ]);
            return ! $complete;
        });
    }

    /**
     * The next batch (max. 100 ids) of recipients. Location announcements use the CURRENT location sample of each
     * person (fresh, never the history) around the admin's approximate point; nothing identifies where anyone is.
     */
    private function recipients(object $entry): \Illuminate\Support\Collection
    {
        if (($entry->target_type ?? 'all') !== 'location') {
            return User::where('account_status', 'active')->where('id', '>', $entry->last_user_id)
                ->when($entry->city_id, fn ($query) => $query->where('city_id', $entry->city_id))
                ->orderBy('id')->limit(100)->pluck('id');
        }
        $origin = (object) ['latitude' => (float) $entry->target_latitude, 'longitude' => (float) $entry->target_longitude];
        $radius = (int) $entry->target_radius_m;
        [$distance, $bindings] = Geo::expression($origin, 'l.latitude', 'l.longitude');
        $query = DB::table('user_locations as l')->join('users as u', 'u.id', '=', 'l.user_id')
            ->where('u.account_status', 'active')->where('u.id', '>', $entry->last_user_id)
            ->where('l.recorded_at', '>=', now()->subMinutes((int) config('location.active_minutes')))
            ->when($entry->city_id, fn ($q) => $q->where('l.city_id', $entry->city_id))
            ->select('u.id');
        Geo::bound($query, $origin, $radius, 'l.latitude', 'l.longitude');

        return $query->whereRaw("($distance) <= ?", [...$bindings, $radius])->orderBy('u.id')->limit(100)->pluck('u.id');
    }

    public function run(): void
    {
        $ids = DB::table('announcements')->where('is_active', true)->whereNull('published_at')
            ->where('publish_at', '<=', now())
            ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))
            ->oldest('publish_at')->limit(20)->pluck('id');
        foreach ($ids as $id) {
            $this->publishBatch($id);
        }
    }

    public function banner(User $user): ?object
    {
        return DB::table('announcements')->where('is_active', true)->where('show_in_app', true)->whereNotNull('published_at')
            ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))
            ->where(fn ($query) => $query->whereNull('city_id')->orWhere('city_id', $user->city_id))
            // Location announcements reach people through the inbox only, never as the global banner.
            ->where(fn ($query) => $query->where('target_type', '<>', 'location')->orWhereNull('target_type'))
            ->orderByDesc('publish_at')->orderByDesc('id')->first(['id', 'title', 'body', 'title_en', 'body_en']);
    }
}
