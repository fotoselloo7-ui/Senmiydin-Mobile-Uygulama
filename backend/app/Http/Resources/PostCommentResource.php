<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PostCommentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'author' => $this->post->is_anonymous && $this->post->user_id === $this->user_id
                ? null : new PublicUserResource($this->author),
            'mine' => $this->user_id === $request->user()->id,
            'body' => $this->body,
            'created_at' => $this->created_at->toISOString(),
        ];
    }
}
