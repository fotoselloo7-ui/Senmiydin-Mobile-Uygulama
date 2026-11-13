<?php

namespace App\Policies;

use App\Models\Encounter;
use App\Models\Post;
use App\Models\User;

class EncounterPolicy
{
    public function view(User $user, Encounter $encounter): bool
    {
        return $encounter->invitation->includes($user);
    }

    public function propose(User $user, Encounter $encounter): bool
    {
        return $this->view($user, $encounter);
    }

    public function editStory(User $user, Encounter $encounter, Post $story): bool
    {
        return $this->view($user, $encounter) && $story->user_id === $user->id;
    }

    public function reviewStory(User $user, Encounter $encounter, Post $story): bool
    {
        return $this->view($user, $encounter) && $story->user_id !== $user->id;
    }
}
