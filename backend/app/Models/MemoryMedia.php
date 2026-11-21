<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MemoryMedia extends Model
{
    protected $table = 'memory_media';

    public $timestamps = false;

    protected $fillable = ['disk', 'path', 'thumb_path', 'sort_order', 'width', 'height', 'aspect_ratio', 'mime_type'];

    protected function casts(): array
    {
        return ['aspect_ratio' => 'float', 'width' => 'integer', 'height' => 'integer', 'sort_order' => 'integer'];
    }

    public function memory(): BelongsTo
    {
        return $this->belongsTo(Memory::class);
    }

    /** @return list<string> every file this row owns. */
    public function files(): array
    {
        return array_values(array_filter([$this->path, $this->thumb_path]));
    }
}
