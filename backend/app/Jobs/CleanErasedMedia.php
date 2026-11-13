<?php
namespace App\Jobs;

use App\Accounts\MediaCleanup;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class CleanErasedMedia implements ShouldQueue
{
    use Queueable;
    public int $tries = 3;
    public array $backoff = [10, 60, 300];

    public function handle(MediaCleanup $cleanup): void
    {
        if ($cleanup->run() !== 0) throw new \RuntimeException('Media cleanup requires retry.');
    }
}
