<?php

namespace App\Accounts;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

final class MediaCleanup
{
    public function run(): int
    {
        $failed = 0;
        DB::table('media_deletions')->orderBy('id')->chunkById(100, function ($items) use (&$failed): void {
            foreach ($items as $item) {
                try {
                    $disk = Storage::disk($item->disk);
                    if ($disk->exists($item->path) && ! $disk->delete($item->path)) {
                        $failed++;
                        continue;
                    }
                    DB::table('media_deletions')->where('id', $item->id)->delete();
                } catch (\Throwable) {
                    // Retain the cleanup entry for the next scheduler run, without logging private paths.
                    $failed++;
                }
            }
        });
        return $failed;
    }
}
