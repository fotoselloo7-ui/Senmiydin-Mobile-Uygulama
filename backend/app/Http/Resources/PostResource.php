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
            'location_label' => $this->approx_latitude === null ? null : ($this->place_label ?? $this->city->name),
            'occurred_at' => $this->occurred_at?->toISOString(),
            'match_hint' => $this->viewer_match_score > 0 ? 'Geçtiğin bir bölgeden' : null,
            'travel' => $travelVisible ? [
                'transport_type' => $travel->transport_type,
                'origin' => $travel->origin->only('id', 'name', 'slug'),
                'destination' => $travel->destination->only('id', 'name', 'slug'),
                'departure_at' => $travel->departure_at?->toISOString(),
                'operator_name' => $travel->operator_name, 'service_code' => $travel->service_code,
                'vehicle_identifier' => $travel->vehicle_identifier, 'is_public' => $travel->is_public,
            ] : null,
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
