<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class EncounterRequest extends Model
{
    use \Illuminate\Database\Eloquent\SoftDeletes;

    public const PENDING = 'pending';
    public const ACCEPTED = 'accepted';
    public const REJECTED = 'rejected';
    public const CANCELLED = 'cancelled';

    protected $fillable = ['requester_id', 'target_user_id', 'source_post_id', 'status', 'responded_at'];

    protected function casts(): array
    {
        return ['responded_at' => 'datetime'];
    }

    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    public function target(): BelongsTo
    {
        return $this->belongsTo(User::class, 'target_user_id');
    }

    public function source(): BelongsTo
    {
        return $this->belongsTo(Post::class, 'source_post_id');
    }

    public function encounter(): HasOne
    {
        return $this->hasOne(Encounter::class, 'request_id');
    }

    public function scopeParticipant(Builder $query, int $userId): Builder
    {
        return $query->where(fn (Builder $pair) =>
            $pair->where('requester_id', $userId)->orWhere('target_user_id', $userId));
    }

    public function scopeActivePair(Builder $query): Builder
    {
        return $query->whereHas('requester', fn (Builder $user) => $user->where('account_status', 'active'))
            ->whereHas('target', fn (Builder $user) => $user->where('account_status', 'active'));
    }

    public function includes(User $user): bool
    {
        return $this->requester_id === $user->id || $this->target_user_id === $user->id;
    }
}
