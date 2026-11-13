<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class EncounterRequestResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'status' => $this->status,
            'outgoing' => $this->requester_id === $request->user()->id,
            'requester' => new PublicUserResource($this->requester),
            'target' => new PublicUserResource($this->target),
            'source' => $this->source ? new PostResource($this->source) : null,
            'encounter_id' => $this->encounter?->id,
            'confirmed_at' => $this->encounter?->confirmed_at->toISOString(),
            'story' => $this->encounter?->story ? new PostResource($this->encounter->story) : null,
            'created_at' => $this->created_at->toISOString(),
            'responded_at' => $this->responded_at?->toISOString(),
        ];
    }
}
