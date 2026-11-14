<?php

namespace App\Safety;

use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Builder as Eloquent;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Server-side age bands. TEEN = 16–17, ADULT = 18+. The band is derived from the stored birth date only: no user,
 * request field or admin toggle can change it, and it moves to ADULT automatically on the 18th birthday.
 *
 * User-to-user social surfaces (search, profiles, follows, nearby, encounters, messages, map notes, comments,
 * feeds, notifications) already pass every "may A see B" decision through {@see Blocks}; the band barrier is folded
 * into those same checks, so a cross-band pair behaves exactly like a blocked pair and no surface can forget it.
 */
final class AgeSafety
{
    public const TEEN = 'teen';

    public const ADULT = 'adult';

    /** Age at which the ADULT band starts. */
    public const ADULT_AGE = 18;

    private static function today(): Carbon
    {
        return Carbon::now('Europe/Istanbul')->startOfDay();
    }

    /** Birth dates after this date belong to the TEEN band. */
    public static function cutoff(): Carbon
    {
        return self::today()->subYearsNoOverflow(self::ADULT_AGE);
    }

    public static function band(CarbonInterface|string|null $birthDate): string
    {
        if ($birthDate === null) {
            return self::ADULT;
        }
        // A birth date is a calendar day, not an instant: the Eloquent `date` cast hands back midnight UTC, which would
        // otherwise sit three hours after Istanbul midnight and make the account a teen for one extra day.
        $day = $birthDate instanceof CarbonInterface ? $birthDate->format('Y-m-d') : substr((string) $birthDate, 0, 10);
        $birth = Carbon::createFromFormat('Y-m-d', $day, 'Europe/Istanbul')->startOfDay();

        return $birth->greaterThan(self::cutoff()) ? self::TEEN : self::ADULT;
    }

    public static function bandOf(int $user): string
    {
        // The authenticated account is the viewer in almost every call; reuse the already loaded model.
        $current = auth()->user();
        if ($current instanceof User && $current->getKey() === $user && $current->birth_date !== null) {
            return self::band($current->birth_date);
        }

        return self::band(User::whereKey($user)->value('birth_date'));
    }

    public static function isTeen(int $user): bool
    {
        return self::bandOf($user) === self::TEEN;
    }

    public static function sameBand(int $a, int $b): bool
    {
        if ($a === $b) {
            return true;
        }
        $dates = DB::table('users')->whereIn('id', [$a, $b])->pluck('birth_date', 'id');
        if ($dates->count() < 2) {
            // One side is missing/erased: not a cross-band pair; other rules (active account, blocks) decide.
            return true;
        }

        return self::band($dates[$a]) === self::band($dates[$b]);
    }

    /** Restrict [$column] (a users.id style column) to accounts in the viewer's own band. */
    public static function exclude(Builder|Eloquent $query, int $viewer, string $column): Builder|Eloquent
    {
        $teen = self::isTeen($viewer);
        $cutoff = self::cutoff()->toDateString();

        // Rows without an acting account (system notifications, anonymous system content) are never band-restricted.
        return $query->where(fn ($either) => $either->whereNull($column)
            ->orWhereExists(fn (Builder $users) => $users->selectRaw('1')->from('users as age_users')
                ->whereColumn('age_users.id', $column)
                ->whereRaw('(DATE(age_users.birth_date) > ?) = ?', [$cutoff, $teen ? 1 : 0])));
    }

    /** SQL-level restriction of a users query to the band of [$viewer]. */
    public static function scope(Builder|Eloquent $users, int $viewer, string $birthColumn = 'users.birth_date'): Builder|Eloquent
    {
        return $users->whereRaw("(DATE($birthColumn) > ?) = ?", [self::cutoff()->toDateString(), self::isTeen($viewer) ? 1 : 0]);
    }
}
