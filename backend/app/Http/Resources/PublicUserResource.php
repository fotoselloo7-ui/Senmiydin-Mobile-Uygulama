<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Public identity only. City, interests and occupation stay server-side for onboarding, filters and matching;
 * the final public profile never shows them, so no other account receives them.
 */
class PublicUserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'username' => $this->username,
            'name' => $this->name,
            'avatar' => $this->avatar ? route('avatars.show', ['filename' => basename($this->avatar)], false) : null,
            'cover_image' => $this->coverUrl(),
            'bio' => $this->bio,
            'post_count' => $this->whenCounted('posts'),
            'encounter_count' => $this->whenHas('encounter_count', fn () => (int) $this->encounter_count),
            'followers_count' => $this->whenCounted('followers'),
            'following_count' => $this->whenCounted('following'),
            'following' => $this->whenHas('followed_by_viewer', fn () => (bool) $this->followed_by_viewer),
        ];
    }
}
