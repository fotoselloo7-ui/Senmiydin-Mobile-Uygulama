<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * "Mektuplarım": the owner's own view of a letter (active or private archive). Never public.
 * Only the grid-approximated coordinate exists; there is no read / viewer information of any kind.
 */
class MyMapNoteResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $state = $this->state();
        $live = (bool) ($this->has_live_repost ?? false);

        return [
            'id' => $this->id,
            'body' => $this->body,
            'is_anonymous' => $this->is_anonymous,
            'mine' => true,
            // As others see it: the owner's own name on an open letter, nothing on an anonymous one.
            'author' => $this->is_anonymous ? null : new PublicUserResource($this->author),
            'city' => $this->city->only('id', 'name', 'slug'),
            'place_label' => \App\Http\ApiResponse::localize((string) $this->place_label),
            // The letter's optional photo is served by id through its own visibility-checked route; no file name leaves the server.
            'image' => $this->imageUrl(),
            'share_url' => \App\Sharing\PublicShare::noteUrl($this->resource),
            'group' => $this->group(),
            'latitude' => $this->approx_latitude,
            'longitude' => $this->approx_longitude,
            'reply_count' => (int) ($this->replies_count ?? 0),
            'state' => $state,
            'can_reply' => false,
            'occurred_at' => ($this->occurred_at ?? $this->created_at)->toISOString(),
            'created_at' => $this->created_at->toISOString(),
            'expires_at' => $this->expires_at->toISOString(),
            'archived_at' => $this->archived_at?->toISOString(),
            'republished' => $this->reposted_from_id !== null,
            'has_live_repost' => $live,
            // The owner's memory made from this letter ("Anılarında"), when there is one.
            'memory_id' => ($this->memory_id ?? null) === null ? null : (int) $this->memory_id,
            'can_repost' => $state !== 'active' && ! $live,
            'seconds_left' => $state === 'active' ? max(0, (int) now()->diffInSeconds($this->expires_at, false)) : null,
        ];
    }
}
