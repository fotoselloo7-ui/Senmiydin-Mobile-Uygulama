<?php

namespace App\Models;

use App\Notifications\PasswordResetCode;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, Notifiable;

    protected $fillable = [
        'name', 'username', 'email', 'password', 'birth_date', 'city_id', 'place_id',
        'bio', 'occupation_school', 'connections', 'nearby_visible',
        'encounter_suggestions', 'city_discovery', 'location_history_enabled',
        'message_privacy', 'memory_default_visibility', 'show_activity', 'push_preferences', 'preferred_locale', 'last_locale',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'birth_date' => 'date',
            'last_seen_at' => 'datetime',
            'erased_at' => 'datetime',
            'show_activity' => 'boolean',
            'push_preferences' => 'array',
            'connections' => 'array',
            'nearby_visible' => 'boolean',
            'encounter_suggestions' => 'boolean',
            'city_discovery' => 'boolean',
            'location_history_enabled' => 'boolean',
            'onboarding_step' => 'integer',
            'has_password' => 'boolean',
        ];
    }

    /** Cover files uploaded through the API are served privately; any legacy value is returned as stored. */
    public function coverUrl(): ?string
    {
        if ($this->cover_image === null || $this->cover_image === '') {
            return null;
        }

        return str_starts_with($this->cover_image, 'covers/')
            ? route('covers.show', ['filename' => basename($this->cover_image)], false)
            : $this->cover_image;
    }

    public function activeCity(): BelongsTo
    {
        return $this->belongsTo(City::class, 'active_city_id');
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(City::class);
    }

    /** The home place the person chose (may be as fine as a neighbourhood); private to the owner. */
    public function place(): BelongsTo
    {
        return $this->belongsTo(Place::class);
    }

    public function interests(): BelongsToMany
    {
        return $this->belongsToMany(Interest::class, 'user_interests')->orderBy('sort_order');
    }

    public function posts(): HasMany
    {
        return $this->hasMany(Post::class);
    }

    public function followers(): BelongsToMany
    {
        return $this->belongsToMany(self::class, 'user_follows', 'followed_id', 'follower_id');
    }

    public function following(): BelongsToMany
    {
        return $this->belongsToMany(self::class, 'user_follows', 'follower_id', 'followed_id');
    }

    public function sendPasswordResetNotification($token): void
    {
        if (app()->environment('production') && in_array(config('mail.default'), ['log', 'array'], true)) {
            abort(503);
        }
        $this->notify(new PasswordResetCode($token));
    }
}
