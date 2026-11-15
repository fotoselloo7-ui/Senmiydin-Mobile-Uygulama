<?php

namespace App\Sharing;

use App\Models\MapNote;
use App\Models\Post;
use App\Models\User;
use App\Safety\AgeSafety;
use Illuminate\Database\Eloquent\Builder;

/**
 * What may leave the app as a link or a card. Only content that is public right now: a city-visible post (or a published,
 * mutually confirmed joint story), an active Map Note. Never private posts, drafts, messages, removed / moderated / expired
 * content, or anything written by a 16-17 year old account: teen content stays inside the age-separated app.
 */
final class PublicShare
{
    public static function postUrl(Post $post): ?string
    {
        return self::postShareable($post) && $post->public_id ? self::url('p', $post->public_id) : null;
    }

    public static function noteUrl(MapNote $note): ?string
    {
        return self::noteShareable($note) && $note->public_id ? self::url('n', $note->public_id) : null;
    }

    public static function postShareable(Post $post): bool
    {
        if ($post->visibility !== 'city' || $post->moderated_at !== null || $post->deleted_at !== null) {
            return false;
        }
        // A joint (encounter) story is shared only once the other person has confirmed and it is published.
        if ($post->encounter_id !== null && $post->story_status !== Post::STORY_PUBLISHED) {
            return false;
        }

        return self::adultActiveAuthor($post->author);
    }

    public static function noteShareable(MapNote $note): bool
    {
        return $note->isLive() && self::adultActiveAuthor($note->author);
    }

    private static function adultActiveAuthor(?User $author): bool
    {
        return $author !== null && $author->account_status === 'active'
            && AgeSafety::band($author->birth_date) === AgeSafety::ADULT;
    }

    /** A post for the public web page / link resolution (or null: unavailable, whatever the reason). */
    public static function findPost(string $publicId): ?Post
    {
        $post = Post::query()->where('public_id', $publicId)->with(['author', 'city:id,name,slug', 'media', 'jointEncounter.invitation.requester', 'jointEncounter.invitation.target'])->first();

        return $post && self::postShareable($post) ? $post : null;
    }

    public static function findNote(string $publicId): ?MapNote
    {
        $note = MapNote::query()->where('public_id', $publicId)->with(['author', 'city'])->first();

        return $note && self::noteShareable($note) ? $note : null;
    }

    public static function url(string $kind, string $publicId): string
    {
        return config('website.url').'/'.$kind.'/'.$publicId;
    }

    /** Query helper for tests / admin tooling: rows that currently qualify. */
    public static function scopeShareablePosts(Builder $query): Builder
    {
        return $query->where('visibility', 'city')->whereNull('moderated_at');
    }
}
