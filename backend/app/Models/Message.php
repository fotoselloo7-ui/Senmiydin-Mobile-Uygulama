<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    protected $fillable = ['conversation_id', 'sender_id', 'request_id', 'body', 'type', 'image_path', 'read_at', 'deleted_at', 'recalled_at', 'recipient_hidden_at', 'approx_latitude', 'approx_longitude', 'place_label', 'audio_path', 'audio_duration_ms', 'gift_id'];

    protected function casts(): array
    {
        return ['read_at' => 'datetime', 'deleted_at' => 'datetime', 'recalled_at' => 'datetime', 'recipient_hidden_at' => 'datetime'];
    }

    public function gift()
    {
        return $this->belongsTo(Gift::class);
    }

    public function conversation()
    {
        return $this->belongsTo(Conversation::class);
    }
}
