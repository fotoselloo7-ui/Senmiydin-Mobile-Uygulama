<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PostMedia extends Model
{
    protected $table = 'post_media';

    public $timestamps = false;

    protected $fillable = ['disk', 'file_path', 'sort_order', 'width', 'height', 'mime_type'];

    public function post(): BelongsTo
    {
        return $this->belongsTo(Post::class);
    }
}
