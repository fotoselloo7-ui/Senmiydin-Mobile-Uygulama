<?php

namespace App\Encounters;

use App\Models\User;
use App\Safety\Blocks;
use Illuminate\Validation\ValidationException;

class EncounterEligibility
{
    public function validateTarget(User $requester, int $targetId): void
    {
        if ($targetId === $requester->id) {
            throw ValidationException::withMessages(['encounter_target_id' => 'Kendini etiketleyemezsin.']);
        }
        $target = User::where('account_status', 'active')->find($targetId);
        if (! $target || ! $this->allowsPair($requester, $target)) {
            throw ValidationException::withMessages(['encounter_target_id' => 'Bu kişiyi etiketleyemezsin.']);
        }
    }

    protected function allowsPair(User $requester, User $target): bool
    {
        return ! Blocks::between($requester->id, $target->id);
    }
}
