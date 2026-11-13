<?php

namespace App\Console\Commands;

use App\Deployment\Readiness;
use Illuminate\Console\Command;

class CheckProduction extends Command
{
    protected $signature = 'app:check {--json : Emit only safe status identifiers}';
    protected $aliases = ['senmiydin:production-check'];
    protected $description = 'Report production blockers without displaying secrets';

    public function handle(Readiness $readiness): int
    {
        $checks = $readiness->checks();
        if ($this->option('json')) {
            $this->line(json_encode(['checks' => $checks, 'ready' => !collect($checks)->contains(fn ($row) =>
                in_array($row['status'], ['MISSING', 'ERROR'], true))], JSON_THROW_ON_ERROR));
        } else {
            $this->table(['Check', 'Status', 'Category'], array_map('array_values', $checks));
        }
        // Missing deployment information is a release blocker, not a test/code failure.
        return collect($checks)->contains(fn ($row) => in_array($row['status'], ['MISSING', 'ERROR'], true)) ? 2 : 0;
    }
}
