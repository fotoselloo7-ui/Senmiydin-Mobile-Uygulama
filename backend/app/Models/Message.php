<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    protected $fillable = ['conversation_id', 'sender_id', 'request_id', 'body', 'type', 'image_path', 'read_at', 'deleted_at', 'approx_latitude', 'approx_longitude', 'place_label'];

    protected function casts(): array
    {
        return ['read_at' => 'datetime', 'deleted_at' => 'datetime'];
    }

    public function conversation()
    {
        return $this->belongsTo(Conversation::class);
    }
}
