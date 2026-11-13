<?php

namespace App\Safety;

use App\Models\User;
use Illuminate\Database\Eloquent\Builder as Eloquent;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

final class Blocks
{
    public static function lockPair(int $a, int $b): void
    {
        User::whereKey(array_unique([$a, $b]))->orderBy('id')->lockForUpdate()->get(['id']);
    }

    public static function between(int $a, int $b): bool
    {
        return DB::table('user_blocks')->where(fn (Builder $query) => $query
            ->where('blocker_id', $a)->where('blocked_id', $b))
            ->orWhere(fn (Builder $query) => $query->where('blocker_id', $b)->where('blocked_id', $a))->exists();
    }

    public static function exclude(Builder|Eloquent $query, int $viewer, string $column): Builder|Eloquent
    {
        return $query->whereNotExists(fn (Builder $blocks) => $blocks->selectRaw('1')->from('user_blocks')
            ->where('blocker_id', $viewer)->whereColumn('blocked_id', $column))
            ->whereNotExists(fn (Builder $blocks) => $blocks->selectRaw('1')->from('user_blocks')
                ->where('blocked_id', $viewer)->whereColumn('blocker_id', $column));
    }
}
