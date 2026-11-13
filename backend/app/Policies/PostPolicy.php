<?php

namespace App\Policies;

use App\Models\Post;
use App\Models\User;

class PostPolicy
{
    public function update(User $user, Post $post): bool
    {
        return $post->encounter_id === null && $post->user_id === $user->id;
    }

    public function delete(User $user, Post $post): bool
    {
        if ($post->user_id === $user->id) {
            return true;
        }
        return $post->story_status === Post::STORY_PUBLISHED
            && $post->jointEncounter?->invitation->includes($user) === true;
    }
}
