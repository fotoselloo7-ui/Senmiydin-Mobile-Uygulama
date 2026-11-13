<?php

namespace App\Models;

use App\Safety\Blocks;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class MapNoteReply extends Model
{
    use SoftDeletes;

    protected $fillable = ['map_note_id', 'user_id', 'body', 'is_anonymous', 'content_hash', 'request_id'];

    protected function casts(): array
    {
        return ['is_anonymous' => 'boolean', 'moderated_at' => 'datetime'];
    }

    public function note(): BelongsTo
    {
        return $this->belongsTo(MapNote::class, 'map_note_id')->withTrashed();
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function scopeLive(Builder $query): Builder
    {
        return $query->whereNull('map_note_replies.deleted_at')->whereNull('map_note_replies.moderated_at')
            ->whereExists(fn ($users) => $users->selectRaw('1')->from('users')
                ->whereColumn('users.id', 'map_note_replies.user_id')->where('users.account_status', 'active'));
    }

    public function scopeVisibleTo(Builder $query, User $viewer): Builder
    {
        return Blocks::exclude($query->live(), $viewer->id, 'map_note_replies.user_id');
    }
}
