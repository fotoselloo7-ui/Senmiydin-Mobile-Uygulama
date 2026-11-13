<?php

namespace App\Policies;

use App\Models\EncounterRequest;
use App\Models\User;

class EncounterRequestPolicy
{
    public function view(User $user, EncounterRequest $request): bool
    {
        return $request->includes($user);
    }

    public function respond(User $user, EncounterRequest $request): bool
    {
        return $request->target_user_id === $user->id;
    }

    public function cancel(User $user, EncounterRequest $request): bool
    {
        return $request->requester_id === $user->id;
    }
}
