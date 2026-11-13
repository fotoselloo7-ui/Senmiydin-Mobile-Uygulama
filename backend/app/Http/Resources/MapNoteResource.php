<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Public representation of a map note. Only the grid-approximated coordinate is ever exposed.
 * Anonymous notes carry no author, user id, username, avatar or profile route.
 */
class MapNoteResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $viewer = $request->user();

        return [
            'id' => $this->id,
            'body' => $this->body,
            'is_anonymous' => $this->is_anonymous,
            'mine' => $viewer !== null && $this->user_id === $viewer->id,
            'author' => $this->is_anonymous ? null : new PublicUserResource($this->author),
            'city' => $this->city->only('id', 'name', 'slug'),
            'place_label' => $this->place_label,
            'group' => $this->group(),
            'latitude' => $this->approx_latitude,
            'longitude' => $this->approx_longitude,
            'reply_count' => (int) ($this->replies_count ?? 0),
            'can_reply' => $this->expires_at->isFuture() && $this->deleted_at === null && $this->moderated_at === null && $this->archived_at === null,
            // The letter's real date. A re-publication gets a new created_at / expires_at but keeps this one.
            'occurred_at' => ($this->occurred_at ?? $this->created_at)->toISOString(),
            'republished' => $this->reposted_from_id !== null,
            'created_at' => $this->created_at->toISOString(),
            'expires_at' => $this->expires_at->toISOString(),
        ];
    }
}
