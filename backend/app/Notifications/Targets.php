<?php

namespace App\Notifications;

use App\Models\Conversation;
use App\Models\EncounterRequest;
use App\Models\Post;
use App\Models\User;
use App\Safety\Blocks;
use Illuminate\Support\Facades\DB;

final class Targets
{
    /** Resolve one page in batches; do not leak whether an inaccessible target exists. */
    public static function available(User $viewer, iterable $items): array
    {
        $items = collect($items);
        $ids = $items->pluck('entity_id')->filter()->unique();
        $posts = Post::visibleTo($viewer)->whereKey($ids)->pluck('id')->flip();
        $chats = Conversation::available($viewer->id)->whereKey($ids)->pluck('id')->flip();
        $pairs = EncounterRequest::participant($viewer->id)->activePair()->whereKey($ids);
        Blocks::exclude($pairs, $viewer->id, 'encounter_requests.requester_id');
        Blocks::exclude($pairs, $viewer->id, 'encounter_requests.target_user_id');
        $pairs = $pairs->pluck('id')->flip();
        $actors = Blocks::exclude(User::where('account_status', 'active'), $viewer->id, 'users.id')
            ->whereKey($items->pluck('actor_id')->filter())->pluck('id')->flip();
        $announcements = DB::table('announcements')->where('is_active', true)
            ->where(fn ($q) => $q->whereNull('expires_at')->orWhere('expires_at', '>', now()))
            ->whereIn('id', $items->pluck('announcement_id')->filter())->pluck('id')->flip();

        return $items->mapWithKeys(fn ($item) => [$item->id => match (true) {
            in_array($item->type, ['like', 'comment', 'location_match', 'nearby_activity'], true) => $posts->has($item->entity_id),
            in_array($item->type, ['message', 'message_request'], true) => $chats->has($item->entity_id),
            str_starts_with($item->type, 'encounter_') => $pairs->has($item->entity_id),
            $item->type === 'follow' => $actors->has($item->actor_id),
            $item->type === 'system' => !$item->announcement_id || $announcements->has($item->announcement_id),
            default => false,
        }])->all();
    }
}
