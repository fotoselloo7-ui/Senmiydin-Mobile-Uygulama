<?php

namespace App\Models;

use App\Location\LocationData;
use App\Safety\Blocks;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * A memory (Anı): an independent, owner-curated snapshot shown on the profile. See the migration for the data rules and
 * docs/PRODUCT_GAP_AUDIT.md ("Anılar") for the privacy matrix.
 */
class Memory extends Model
{
    use SoftDeletes;

    public const PRIVATE = 'private';

    public const FOLLOWERS = 'followers';

    public const PUBLIC = 'public';

    public const AREA = 'area';

    public const VISIBILITIES = [self::PRIVATE, self::FOLLOWERS, self::PUBLIC, self::AREA];

    public const SOURCES = ['map_note', 'post'];

    protected $fillable = ['user_id', 'source_type', 'source_id', 'body', 'occurred_at', 'city_id', 'place_id', 'place_label',
        'approx_latitude', 'approx_longitude', 'visibility', 'is_hidden', 'content_hash', 'request_id'];

    protected function casts(): array
    {
        return ['occurred_at' => 'datetime', 'moderated_at' => 'datetime', 'is_hidden' => 'boolean',
            'approx_latitude' => 'float', 'approx_longitude' => 'float'];
    }

    protected static function booted(): void
    {
        // Permanent deletion (owner delete without a report, retention purge, account erasure) takes the files with it.
        // It runs BEFORE the row goes, because the database cascade would otherwise remove the media rows first.
        static::forceDeleting(function (self $memory): void {
            self::removeFiles($memory->media()->get());
        });
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(City::class);
    }

    public function place(): BelongsTo
    {
        return $this->belongsTo(Place::class);
    }

    public function media(): HasMany
    {
        return $this->hasMany(MemoryMedia::class)->orderBy('sort_order')->orderBy('id');
    }

    /** Deletes the files of media rows now; whatever the disk refuses is queued for the cleanup job instead. */
    public static function removeFiles(iterable $media): void
    {
        foreach ($media as $item) {
            $disk = Storage::disk($item->disk);
            foreach ($item->files() as $path) {
                try {
                    if ($disk->exists($path) && ! $disk->delete($path)) {
                        throw new \RuntimeException('not deleted');
                    }
                } catch (\Throwable) {
                    DB::table('media_deletions')->insertOrIgnore(['disk' => $item->disk, 'path' => $path, 'created_at' => now()]);
                }
            }
        }
    }

    /**
     * The areas (cities rows) a person counts as "being in": the home area they registered with and the area their
     * device last placed them in. An area picked by hand in the app never counts, so "Bu Bölgedekiler" cannot be opened
     * by simply browsing another city. No coordinate takes part: it is an area id comparison.
     *
     * @return list<int>
     */
    public static function viewerAreas(User $viewer): array
    {
        $areas = [$viewer->city_id];
        if ($viewer->active_city_id && $viewer->active_city_source === 'device') {
            $areas[] = $viewer->active_city_id;
        }
        $areas[] = LocationData::active($viewer)?->city_id;

        return array_values(array_unique(array_map('intval', array_filter($areas))));
    }

    /**
     * Every rule that decides who sees a memory, in one place and in SQL (the client never filters):
     *  - blocked in either direction, or across the teen / adult age bands (App\Safety\Blocks) beats everything;
     *  - removed by moderation, deleted, or by an inactive account: gone for everyone, owner included;
     *  - the owner always sees their own (also hidden and private ones);
     *  - everybody else needs the memory not to be hidden AND: public, or followers (viewer follows the owner), or
     *    area (viewer is in the memory's area).
     */
    public function scopeVisibleTo(Builder $query, User $viewer): Builder
    {
        Blocks::exclude($query, $viewer->id, 'memories.user_id');

        return $query->whereNull('memories.deleted_at')->whereNull('memories.moderated_at')
            ->whereExists(fn ($users) => $users->selectRaw('1')->from('users')
                ->whereColumn('users.id', 'memories.user_id')->where('users.account_status', 'active'))
            ->where(fn (Builder $access) => $access->where('memories.user_id', $viewer->id)
                ->orWhere(fn (Builder $others) => $others->where('memories.is_hidden', false)->where(fn (Builder $kind) => $kind
                    ->where('memories.visibility', self::PUBLIC)
                    ->orWhere(fn (Builder $followers) => $followers->where('memories.visibility', self::FOLLOWERS)
                        ->whereExists(fn ($follows) => $follows->selectRaw('1')->from('user_follows')
                            ->whereColumn('user_follows.followed_id', 'memories.user_id')->where('user_follows.follower_id', $viewer->id)))
                    ->orWhere(fn (Builder $area) => $area->where('memories.visibility', self::AREA)
                        ->whereNotNull('memories.city_id')->whereIn('memories.city_id', self::viewerAreas($viewer) ?: [0])))));
    }

    /** Retention: removed-by-moderation and reported-then-deleted memories leave for good once the review window ends. */
    public static function purgeExpired(): int
    {
        $cutoff = now()->subDays((int) config('memories.retention_days'));
        $removed = 0;
        static::withTrashed()->where(fn ($q) => $q->where('deleted_at', '<', $cutoff)->orWhere('moderated_at', '<', $cutoff))
            ->chunkById(100, function ($memories) use (&$removed): void {
                foreach ($memories as $memory) {
                    $memory->forceDelete();
                    $removed++;
                }
            });

        return $removed;
    }
}
