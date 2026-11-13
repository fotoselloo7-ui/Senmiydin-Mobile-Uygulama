<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PostTravelDetail extends Model
{
    public $timestamps = false;
    protected $primaryKey = 'post_id';
    protected $guarded = [];
    protected function casts(): array { return ['departure_at' => 'datetime', 'is_public' => 'boolean']; }
    public function origin(): BelongsTo { return $this->belongsTo(City::class, 'origin_city_id'); }
    public function destination(): BelongsTo { return $this->belongsTo(City::class, 'destination_city_id'); }
}
