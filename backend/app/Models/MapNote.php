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
        'place_label', 'content_hash', 'request_id', 'expires_at', 'occurred_at', 'reposted_from_id'];

    protected function casts(): array
    {
        return ['is_anonymous' => 'boolean', 'expires_at' => 'datetime', 'moderated_at' => 'datetime',
            'occurred_at' => 'datetime', 'archived_at' => 'datetime',
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

    /** Later public publications of this same letter ("Tekrar Paylaş"). Their reply threads are separate. */
    public function reposts(): HasMany
    {
        return $this->hasMany(self::class, 'reposted_from_id');
    }

    /** active = public now; archived = owner took it off the map; expired = its 7 public days are over. */
    public function state(): string
    {
        return $this->archived_at !== null ? 'archived' : ($this->expires_at->isPast() ? 'expired' : 'active');
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
        return $this->deleted_at === null && $this->moderated_at === null && $this->archived_at === null && $this->expires_at->isFuture()
            && User::whereKey($this->user_id)->where('account_status', 'active')->exists();
    }

    /** Publicly visible: not removed, not moderated, not expired, active author. */
    public function scopeLive(Builder $query): Builder
    {
        return $query->whereNull('map_notes.deleted_at')->whereNull('map_notes.moderated_at')->whereNull('map_notes.archived_at')
            ->where('map_notes.expires_at', '>', now())
            ->whereExists(fn ($users) => $users->selectRaw('1')->from('users')
                ->whereColumn('users.id', 'map_notes.user_id')->where('users.account_status', 'active'));
    }

    public function scopeVisibleTo(Builder $query, User $viewer): Builder
    {
        return Blocks::exclude($query->live(), $viewer->id, 'map_notes.user_id');
    }

    /**
     * Retention. The public 7-day visibility never changes, but expiry no longer destroys anything: an expired or owner-archived
     * letter stays in the owner's private archive until the owner permanently deletes it or deletes the account.
     * Only rows that already left the owner's reach are purged for good after the moderation / audit window:
     * permanently deleted letters that had reports, notes removed by moderation, and erased accounts' rows.
     */
    public static function purgeExpired(): int
    {
        $cutoff = now()->subDays(config('map_notes.retention_days'));
        $removed = 0;
        static::withTrashed()->where(fn ($q) => $q->where('deleted_at', '<', $cutoff)->orWhere('moderated_at', '<', $cutoff))
            ->chunkById(100, function ($notes) use (&$removed): void {
                foreach ($notes as $note) {
                    $note->forceDelete();
                    $removed++;
                }
            });

        return $removed;
    }
}
