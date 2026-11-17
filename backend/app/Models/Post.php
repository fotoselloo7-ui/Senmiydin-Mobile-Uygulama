<?php

namespace App\Models;

use App\Safety\Blocks;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOneThrough;
use Illuminate\Database\Eloquent\SoftDeletes;

class Post extends Model
{
    use SoftDeletes;

    public const TYPES = ['moment', 'confession', 'thought', 'travel', 'encounter'];

    protected $fillable = ['user_id', 'city_id', 'body', 'type', 'is_anonymous', 'visibility', 'comments_enabled', 'request_id', 'occurred_at', 'place_label', 'place_id'];

    protected function casts(): array
    {
        return ['is_anonymous' => 'boolean', 'comments_enabled' => 'boolean', 'occurred_at' => 'datetime'];
    }

    protected static function booted(): void
    {
        static::creating(function (self $post): void {
            $post->public_id ??= \Illuminate\Support\Str::lower(\Illuminate\Support\Str::random(12));
        });
    }

    public const STORY_PENDING = 'pending';
    public const STORY_REJECTED = 'rejected';
    public const STORY_PUBLISHED = 'published';

    public function jointEncounter(): BelongsTo
    {
        return $this->belongsTo(Encounter::class, 'encounter_id');
    }

    public function confirmedEncounter(): HasOneThrough
    {
        return $this->hasOneThrough(Encounter::class, EncounterRequest::class, 'source_post_id', 'request_id');
    }

    public function scopePublishedOrOrdinary(Builder $query): Builder
    {
        return $query->where(fn (Builder $posts) =>
            $posts->whereNull('posts.encounter_id')->orWhere('posts.story_status', self::STORY_PUBLISHED));
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function travel(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(PostTravelDetail::class);
    }

    /** The place the author chose for the post (optional; older posts only have a city). */
    public function place(): BelongsTo
    {
        return $this->belongsTo(Place::class);
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(City::class);
    }

    public function media(): HasMany
    {
        return $this->hasMany(PostMedia::class)->orderBy('sort_order');
    }

    public function comments(): HasMany
    {
        // A reply is public only while its top-level comment is (not deleted / moderated, active author): no orphan replies.
        return $this->hasMany(PostComment::class)
            ->whereHas('author', fn (Builder $user) => $user->where('account_status', 'active'))
            ->where(fn (Builder $thread) => $thread->whereNull('post_comments.parent_id')
                ->orWhereHas('parent', fn (Builder $parent) => $parent
                    ->whereHas('author', fn (Builder $user) => $user->where('account_status', 'active'))));
    }

    public function likes(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'post_likes');
    }

    public function saves(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'post_saves');
    }

    public function scopeVisibleTo(Builder $query, User $viewer): Builder
    {
        return Blocks::exclude($query, $viewer->id, 'posts.user_id')
            ->where(fn (Builder $available) => $available->whereNull('posts.encounter_id')
                ->orWhereHas('jointEncounter.invitation', function (Builder $pair) use ($viewer): void {
                    Blocks::exclude($pair, $viewer->id, 'encounter_requests.requester_id');
                    Blocks::exclude($pair, $viewer->id, 'encounter_requests.target_user_id');
                }))
            ->whereHas('author', fn (Builder $user) => $user->where('account_status', 'active'))
            ->where(function (Builder $visible) use ($viewer): void {
                $visible->where(fn (Builder $ordinary) => $ordinary->whereNull('posts.encounter_id')
                    ->where(fn (Builder $access) => $access->where('posts.visibility', 'city')->orWhere('posts.user_id', $viewer->id)))
                    ->orWhere(fn (Builder $published) => $published->where('posts.story_status', self::STORY_PUBLISHED)
                        ->where('posts.visibility', 'city')->whereHas('jointEncounter.invitation', fn (Builder $pair) => $pair->activePair()))
                    ->orWhereHas('jointEncounter.invitation', fn (Builder $pair) => $pair->participant($viewer->id));
            });
    }

    public function scopeForViewer(Builder $query, User $viewer): Builder
    {
        $ownRequest = EncounterRequest::whereColumn('source_post_id', 'posts.id')->where('requester_id', $viewer->id);
        return $query->with([
            'jointEncounter.invitation.requester',
            'jointEncounter.invitation.target',
            'city:id,name,slug,labels', 'place',
            'travel.origin:id,name,slug,labels', 'travel.destination:id,name,slug,labels',
            'travel.originPlace', 'travel.destinationPlace',
            'media',
            'author' => fn (BelongsTo $authors) => $authors->withExists([
                'followers as followed_by_viewer' => fn (Builder $users) => $users->where($users->qualifyColumn('id'), $viewer->id),
            ]),
        ])->addSelect('posts.*')->selectSub(\Illuminate\Support\Facades\DB::table('location_matches')
            ->whereColumn('post_id', 'posts.id')->where('user_id', $viewer->id)
            ->where('matched_at', '>=', \App\Location\LocationData::cutoff())->select('score'), 'viewer_match_score')
        ->withCount(['likes', 'comments'])->withExists([
            'confirmedEncounter',
            'likes as liked_by_viewer' => fn (Builder $users) => $users->where($users->qualifyColumn('id'), $viewer->id),
            'saves as saved_by_viewer' => fn (Builder $users) => $users->where($users->qualifyColumn('id'), $viewer->id),
        ])->selectSub((clone $ownRequest)->select('id'), 'own_encounter_request_id')
            ->selectSub($ownRequest->select('status'), 'own_encounter_request_status');
    }
}
