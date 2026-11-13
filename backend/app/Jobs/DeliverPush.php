<?php

namespace App\Jobs;

use App\Notifications\PushDelivery;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class DeliverPush implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;
    public int $timeout = 30;
    public array $backoff = [10, 60, 300];

    public function __construct(public readonly int $notification) {}

    public function handle(PushDelivery $delivery): void
    {
        $delivery->send($this->notification);
    }
}
