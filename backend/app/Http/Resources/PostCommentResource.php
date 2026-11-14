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
            'parent_id' => $this->parent_id,
            'likes_count' => (int) ($this->likes_total ?? 0),
            'liked_by_me' => (bool) ($this->liked_by_me ?? false),
            'created_at' => $this->created_at->toISOString(),
            ...($this->parent_id === null ? [
                'reply_count' => (int) ($this->reply_total ?? 0),
                'replies' => $this->relationLoaded('replies')
                    ? self::collection($this->replies->each(fn ($reply) => $reply->setRelation('post', $this->post)))->resolve($request) : [],
            ] : []),
        ];
    }
}
