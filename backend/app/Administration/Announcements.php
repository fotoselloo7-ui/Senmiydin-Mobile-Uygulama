<?php

namespace App\Administration;

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
            $users = User::where('account_status', 'active')->where('id', '>', $entry->last_user_id)
                ->when($entry->city_id, fn ($query) => $query->where('city_id', $entry->city_id))
                ->orderBy('id')->limit(100)->pluck('id');
            foreach ($users as $user) {
                Inbox::add($user, null, 'system', $id, (bool) $entry->show_in_app, (bool) $entry->send_push, $id);
            }
            $complete = $users->count() < 100;
            DB::table('announcements')->where('id', $id)->update([
                'last_user_id' => $users->last() ?? $entry->last_user_id,
                'published_at' => $complete ? now() : null, 'updated_at' => now(),
            ]);
            return ! $complete;
        });
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
            ->orderByDesc('publish_at')->orderByDesc('id')->first(['id', 'title', 'body']);
    }
}
