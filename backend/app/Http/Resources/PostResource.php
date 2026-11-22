<?php

namespace App\Http\Resources;

use App\Location\Geo;
use App\Models\Post;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PostResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $story = $this->relationLoaded('jointEncounter') ? $this->jointEncounter : null;
        $published = $this->story_status === Post::STORY_PUBLISHED;

        $travel = $this->relationLoaded('travel') ? $this->travel : null;
        $travelVisible = $travel && ($travel->is_public || $this->user_id === $request->user()->id);
        return [
            'id' => $this->id,
            'author' => $this->is_anonymous ? null : new PublicUserResource($this->author),
            'mine' => $this->user_id === $request->user()->id,
            'body' => $this->body,
            'type' => $this->type,
            'city' => $this->city->only('id', 'name', 'slug'),
            // The place the author picked for this post, when there is one (name + its hierarchy, never a coordinate).
            'place' => $this->relationLoaded('place') ? $this->place?->summary() : null,
            'is_anonymous' => $this->is_anonymous,
            'visibility' => $this->visibility,
            'comments_enabled' => $this->comments_enabled,
            'encounter_confirmed' => (bool) $this->confirmed_encounter_exists || $published,
            'encounter_request_id' => $this->own_encounter_request_id,
            'encounter_request_status' => $this->own_encounter_request_status,
            'story_title' => $this->story_title,
            'story_status' => $this->story_status,
            'story_revision' => $this->story_revision,
            'story_participants' => $story && $published ? [
                new PublicUserResource($story->invitation->requester),
                new PublicUserResource($story->invitation->target),
            ] : [],
            'interactions_enabled' => $this->encounter_id === null || $published,
            'distance_meters' => Geo::publicDistance($this->distance_meters),
            'location_label' => $this->approx_latitude === null ? null : \App\Http\ApiResponse::localize($this->place_label ?? $this->city->name),
            // The approximate (grid) point the map already shows for this post, so the app can open the map on it.
            // Never the author's exact position; null for a post without a place.
            'map_point' => $this->approx_latitude === null ? null : [
                'latitude' => (float) $this->approx_latitude, 'longitude' => (float) $this->approx_longitude,
            ],
            'occurred_at' => $this->occurred_at?->toISOString(),
            'match_hint' => $this->viewer_match_score > 0 ? \App\Http\ApiResponse::localize('Geçtiğin bir bölgeden') : null,
            'travel' => $travelVisible ? [
                'transport_type' => $travel->transport_type,
                'origin' => $travel->origin->only('id', 'name', 'slug') + ['label' => $travel->originPlace?->display()['label']],
                'destination' => $travel->destination->only('id', 'name', 'slug') + ['label' => $travel->destinationPlace?->display()['label']],
                'departure_at' => $travel->departure_at?->toISOString(),
                'operator_name' => $travel->operator_name, 'service_code' => $travel->service_code,
                'vehicle_identifier' => $travel->vehicle_identifier, 'is_public' => $travel->is_public,
            ] : null,
            // A public https link, only for content that may leave the app (see App\Sharing\PublicShare); null otherwise.
            'share_url' => \App\Sharing\PublicShare::postUrl($this->resource),
            'created_at' => $this->created_at->toISOString(),
            'updated_at' => $this->updated_at->toISOString(),
            'media' => $this->media->map(fn ($image) => [
                'id' => $image->id,
                'url' => route('posts.media', ['media' => $image->id], false),
                'width' => $image->width,
                'height' => $image->height,
            ])->all(),
            'likes_count' => $this->likes_count,
            'comments_count' => $this->comments_count,
            'liked' => (bool) $this->liked_by_viewer,
            'saved' => (bool) $this->saved_by_viewer,
        ];
    }
}
