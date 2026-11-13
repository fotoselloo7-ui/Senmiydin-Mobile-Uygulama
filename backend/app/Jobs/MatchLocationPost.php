<?php

namespace App\Jobs;

use App\Location\PostMatcher;
use App\Models\Post;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class MatchLocationPost implements ShouldQueue
{
    use Queueable;
    public int $tries = 3;
    public int $timeout = 60;
    public function __construct(public readonly int $postId) {}
    public function handle(PostMatcher $matcher): void
    {
        $post = Post::find($this->postId);
        if ($post) $matcher->match($post);
    }
}
