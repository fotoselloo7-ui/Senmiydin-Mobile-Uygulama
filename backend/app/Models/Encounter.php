<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Encounter extends Model
{
    protected $fillable = ['request_id', 'confirmed_at'];

    protected function casts(): array
    {
        return ['confirmed_at' => 'datetime'];
    }

    public function invitation(): BelongsTo
    {
        return $this->belongsTo(EncounterRequest::class, 'request_id');
    }

    public function story(): HasOne
    {
        return $this->hasOne(Post::class);
    }
}
