<?php

namespace App\Notifications;

use App\Models\Conversation;
use App\Models\EncounterRequest;
use App\Models\MapNote;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\User;
use App\Safety\Blocks;
use Illuminate\Support\Facades\DB;

final class Targets
{
    /**
     * comment_reply notifications store the reply id; resolve them to the post id the app opens.
     * A reply is reachable only while the reply, its top-level comment and the post are all still public.
     *
     * @return array<int,int> reply id => post id
     */
    public static function replyPosts(User $viewer, iterable $items): array
    {
        $ids = collect($items)->whereIn('type', ['comment_reply', 'comment_like'])->pluck('entity_id')->filter()->unique();
        if ($ids->isEmpty()) {
            return [];
        }
        $visible = Post::visibleTo($viewer)->select('posts.id');
        $comments = Blocks::exclude(PostComment::query(), $viewer->id, 'post_comments.user_id')
            ->whereIn('post_comments.id', $ids)->whereIn('post_comments.post_id', $visible)
            // A reply (or a like on one) is reachable only while its top-level comment is too.
            ->where(fn ($thread) => $thread->whereNull('post_comments.parent_id')->orWhereHas('parent', fn ($parent) => $parent->whereHas('author', fn ($user) => $user->where('account_status', 'active'))))
            ->whereHas('author', fn ($user) => $user->where('account_status', 'active'))->get(['id', 'post_id']);

        return $comments->pluck('post_id', 'id')->all();
    }

    /** Resolve one page in batches; do not leak whether an inaccessible target exists. */
    public static function available(User $viewer, iterable $items): array
    {
        $items = collect($items);
        $ids = $items->pluck('entity_id')->filter()->unique();
        $posts = Post::visibleTo($viewer)->whereKey($ids)->pluck('id')->flip();
        $chats = Conversation::available($viewer->id)->whereKey($ids)->pluck('id')->flip();
        $notes = MapNote::visibleTo($viewer)->whereKey($ids)->pluck('id')->flip();
        $replies = self::replyPosts($viewer, $items);
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
            in_array($item->type, ['like', 'comment', 'location_match', 'nearby_activity', 'nearby_post'], true) => $posts->has($item->entity_id),
            in_array($item->type, ['message', 'message_request'], true) => $chats->has($item->entity_id),
            in_array($item->type, ['comment_reply', 'comment_like'], true) => isset($replies[$item->entity_id]),
            in_array($item->type, ['map_note_nearby', 'map_note_reply'], true) => $notes->has($item->entity_id),
            str_starts_with($item->type, 'encounter_') => $pairs->has($item->entity_id),
            $item->type === 'follow' => $actors->has($item->actor_id),
            $item->type === 'system' => !$item->announcement_id || $announcements->has($item->announcement_id),
            default => false,
        }])->all();
    }
}
