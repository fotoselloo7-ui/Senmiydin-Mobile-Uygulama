<?php

namespace App\Http\Resources;

use App\Notifications\Inbox;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProfileResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'username' => $this->username,
            'email' => $this->email,
            'birth_date' => $this->birth_date->toDateString(),
            // Server-derived and read-only: drives ad treatment and age-appropriate messaging in the app.
            'age_band' => \App\Safety\AgeSafety::band($this->birth_date),
            'city_id' => $this->city_id,
            'active_city' => $this->activeCity?->only('id', 'name', 'slug'),
            'active_city_source' => $this->active_city_source,
            'city' => $this->city->only('id', 'name', 'slug'),
            'avatar' => $this->avatar ? route('avatars.show', ['filename' => basename($this->avatar)], false) : null,
            'cover_image' => $this->coverUrl(),
            'bio' => $this->bio,
            'occupation_school' => $this->occupation_school,
            'account_status' => $this->account_status,
            'created_at' => $this->created_at?->toISOString(),
            'last_seen_at' => $this->last_seen_at?->toISOString(),
            'message_privacy' => $this->message_privacy,
            'show_activity' => $this->show_activity,
            'preferred_locale' => $this->preferred_locale,
            'push_preferences' => ($this->push_preferences ?? []) + Inbox::DEFAULTS,
            'connections' => $this->connections ?? [],
            'nearby_visible' => $this->nearby_visible,
            'encounter_suggestions' => $this->encounter_suggestions,
            'city_discovery' => $this->city_discovery,
            'location_history_enabled' => $this->location_history_enabled,
            'onboarding_step' => $this->onboarding_step,
            'interests' => $this->interests->map->only('id', 'name', 'slug', 'icon')->all(),
        ];
    }
}
