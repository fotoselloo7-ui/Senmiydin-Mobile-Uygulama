<?php

namespace App\Http\Resources;

use App\Http\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * What the app (and any other viewer) receives for a memory.
 *
 * Never part of it: a coordinate of any kind (only the approximate area label and area), location history ids, the
 * source's id, moderation fields, the content hash or the idempotency key. The visibility, hidden state and the kind of
 * source are told to the owner only.
 */
class MemoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $mine = $this->user_id === $request->user()->id;
        $label = $this->place_label ? ApiResponse::localize((string) $this->place_label) : null;

        return [
            'id' => $this->id,
            'mine' => $mine,
            'author' => $this->relationLoaded('author') && $this->author ? new PublicUserResource($this->author) : null,
            'body' => $this->body,
            'occurred_at' => $this->occurred_at->toISOString(),
            'city' => $this->relationLoaded('city') ? $this->city?->only('id', 'name', 'slug') : null,
            'place' => $this->relationLoaded('place') ? $this->place?->summary() : null,
            'place_label' => $label,
            // For "Haritada Gör": a coarse area (centre rounded to ~1 km + radius), never the memory's own point.
            'map_area' => $this->relationLoaded('city') ? \App\Memories\MapArea::of($this->resource) : null,
            'visibility' => $mine ? $this->visibility : null,
            'is_hidden' => $mine ? (bool) $this->is_hidden : null,
            'source_type' => $mine ? $this->source_type : null,
            'media' => $this->media->map(fn ($image) => [
                'id' => $image->id,
                'url' => route('memories.media', ['media' => $image->id], false),
                'thumb_url' => route('memories.thumb', ['media' => $image->id], false),
                'width' => $image->width,
                'height' => $image->height,
                'aspect_ratio' => $image->aspect_ratio,
            ])->all(),
            'created_at' => $this->created_at->toISOString(),
            'updated_at' => $this->updated_at->toISOString(),
        ];
    }
}
