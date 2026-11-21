<?php

namespace App\Memories;

use App\Models\MapNote;
use App\Models\Memory;
use App\Models\Post;
use App\Models\User;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

/**
 * Reads the content a memory can be created from (the owner's own map note or post) as a plain snapshot. Nothing here
 * writes to the source, and the memory keeps no live link to it: only `source_type` / `source_id` are remembered so the
 * same source is not copied twice.
 */
final class MemorySources
{
    /**
     * @return array{type:string,id:int,body:string,occurred_at:\Illuminate\Support\Carbon,city_id:?int,place_id:?int,place_label:?string,latitude:?float,longitude:?float,anonymous:bool,media:list<array{ref:string,disk:string,path:string,url:string,width:?int,height:?int}>}
     */
    public static function snapshot(User $owner, string $type, int $id): array
    {
        return $type === 'map_note' ? self::note($owner, $id) : self::post($owner, $id);
    }

    /** The owner's own memory already made from this source, when there is one. */
    public static function existing(User $owner, string $type, int $id): ?Memory
    {
        return Memory::where('user_id', $owner->id)->where('source_type', $type)->where('source_id', $id)->latest('id')->first();
    }

    private static function note(User $owner, int $id): array
    {
        // Active, archived and expired letters all qualify; only moderated / deleted ones are gone.
        $note = MapNote::where('user_id', $owner->id)->whereNull('moderated_at')->findOrFail($id);

        return [
            'type' => 'map_note', 'id' => $note->id, 'body' => (string) $note->body,
            'occurred_at' => $note->occurred_at ?? $note->created_at,
            'city_id' => $note->city_id, 'place_id' => null, 'place_label' => $note->place_label,
            'latitude' => $note->approx_latitude, 'longitude' => $note->approx_longitude,
            'anonymous' => (bool) $note->is_anonymous,
            'media' => $note->image_path ? [[
                'ref' => 's'.$note->id, 'disk' => config('mobile.post_media_disk'), 'path' => $note->image_path,
                'url' => route('map-notes.image', ['note' => $note->id], false), 'width' => null, 'height' => null,
            ]] : [],
        ];
    }

    private static function post(User $owner, int $id): array
    {
        $post = Post::visibleTo($owner)->where('posts.user_id', $owner->id)->with('media')->findOrFail($id);
        if ($post->encounter_id !== null) {
            // A joint encounter story belongs to two people.
            throw ValidationException::withMessages(['source_id' => 'Ortak karşılaşma hikâyeleri Anılara eklenemez.']);
        }

        return [
            'type' => 'post', 'id' => $post->id, 'body' => (string) $post->body,
            'occurred_at' => $post->occurred_at ?? $post->created_at,
            'city_id' => $post->city_id, 'place_id' => $post->place_id, 'place_label' => $post->place_label,
            'latitude' => $post->approx_latitude === null ? null : (float) $post->approx_latitude,
            'longitude' => $post->approx_longitude === null ? null : (float) $post->approx_longitude,
            'anonymous' => (bool) $post->is_anonymous,
            'media' => $post->media->take((int) config('memories.max_media'))->map(fn ($image) => [
                'ref' => 's'.$image->id, 'disk' => $image->disk, 'path' => $image->file_path,
                'url' => route('posts.media', ['media' => $image->id], false), 'width' => $image->width, 'height' => $image->height,
            ])->all(),
        ];
    }

    /** The bytes of a source photo (it never leaves the server: the memory gets its own re-encoded copy). */
    public static function read(array $media): ?string
    {
        $disk = Storage::disk($media['disk']);

        return $disk->exists($media['path']) ? $disk->get($media['path']) : null;
    }
}
