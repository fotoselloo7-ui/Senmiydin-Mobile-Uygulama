<?php

namespace App\Models;

use App\Safety\Blocks;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class Conversation extends Model
{
    protected $fillable = ['first_user_id', 'second_user_id', 'requester_id', 'status', 'responded_at'];

    protected function casts(): array
    {
        return ['responded_at' => 'datetime'];
    }

    public function canRequestAgain(): bool
    {
        return in_array($this->status, ['cancelled', 'rejected'], true)
            && $this->responded_at?->lte(now()->subDay());
    }

    public function scopeForMember(Builder $query, int $id): Builder
    {
        return $query->where(fn (Builder $pair) => $pair->where('first_user_id', $id)->orWhere('second_user_id', $id));
    }

    public function scopeAvailable(Builder $query, int $id): Builder
    {
        return $query->forMember($id)->whereIn('first_user_id', User::where('account_status', 'active')->select('id'))
            ->whereIn('second_user_id', User::where('account_status', 'active')->select('id'))
            ->tap(fn (Builder $items) => Blocks::exclude($items, $id, 'conversations.first_user_id'))
            ->tap(fn (Builder $items) => Blocks::exclude($items, $id, 'conversations.second_user_id'));
    }

    public function otherId(int $id): int
    {
        return $id === $this->first_user_id ? $this->second_user_id : $this->first_user_id;
    }
}
