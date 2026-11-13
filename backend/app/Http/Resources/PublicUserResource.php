<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PublicUserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'username' => $this->username,
            'name' => $this->name,
            'avatar' => $this->avatar ? route('avatars.show', ['filename' => basename($this->avatar)], false) : null,
            'cover_image' => $this->cover_image,
            'city' => $this->whenLoaded('city', fn () => $this->city->only('id', 'name', 'slug')),
            'bio' => $this->bio,
            'occupation_school' => $this->occupation_school,
            'interests' => $this->whenLoaded('interests', fn () => $this->interests->map->only('id', 'name', 'slug')->all()),
            'post_count' => $this->whenCounted('posts'),
            'encounter_count' => $this->whenHas('encounter_count', fn () => (int) $this->encounter_count),
            'followers_count' => $this->whenCounted('followers'),
            'following_count' => $this->whenCounted('following'),
            'following' => $this->whenHas('followed_by_viewer', fn () => (bool) $this->followed_by_viewer),
        ];
    }
}
