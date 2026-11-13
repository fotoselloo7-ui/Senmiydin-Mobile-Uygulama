<?php

namespace App\Models;

use App\Safety\Blocks;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class MapNote extends Model
{
    use SoftDeletes;

    protected $fillable = ['user_id', 'city_id', 'body', 'is_anonymous', 'approx_latitude', 'approx_longitude',
        'place_label', 'content_hash', 'request_id', 'expires_at'];

    protected function casts(): array
    {
        return ['is_anonymous' => 'boolean', 'expires_at' => 'datetime', 'moderated_at' => 'datetime',
            'approx_latitude' => 'float', 'approx_longitude' => 'float'];
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(City::class);
    }

    public function replies(): HasMany
    {
        return $this->hasMany(MapNoteReply::class);
    }

    /** Opaque, non-sensitive identifier of the approximate point. */
    public static function groupKey(float $latitude, float $longitude): string
    {
        return number_format($latitude, 5, '.', '').'_'.number_format($longitude, 5, '.', '');
    }

    public function group(): string
    {
        return self::groupKey($this->approx_latitude, $this->approx_longitude);
    }

    public function isLive(): bool
    {
        return $this->deleted_at === null && $this->moderated_at === null && $this->expires_at->isFuture()
            && User::whereKey($this->user_id)->where('account_status', 'active')->exists();
    }

    /** Publicly visible: not removed, not moderated, not expired, active author. */
    public function scopeLive(Builder $query): Builder
    {
        return $query->whereNull('map_notes.deleted_at')->whereNull('map_notes.moderated_at')
            ->where('map_notes.expires_at', '>', now())
            ->whereExists(fn ($users) => $users->selectRaw('1')->from('users')
                ->whereColumn('users.id', 'map_notes.user_id')->where('users.account_status', 'active'));
    }

    public function scopeVisibleTo(Builder $query, User $viewer): Builder
    {
        return Blocks::exclude($query->live(), $viewer->id, 'map_notes.user_id');
    }

    /** Lifecycle: expired or removed notes stay for admin review, then are purged for good (replies cascade). */
    public static function purgeExpired(): int
    {
        $cutoff = now()->subDays(config('map_notes.retention_days'));
        $removed = 0;
        static::withTrashed()->where(fn ($q) => $q->where('expires_at', '<', $cutoff)
            ->orWhere('deleted_at', '<', $cutoff))->chunkById(100, function ($notes) use (&$removed): void {
                foreach ($notes as $note) {
                    $note->forceDelete();
                    $removed++;
                }
            });

        return $removed;
    }
}
