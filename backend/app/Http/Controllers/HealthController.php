<?php
namespace App\Http\Controllers;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class HealthController
{
    public function __invoke()
    {
        $key = 'health:'.Str::uuid();
        try {
            DB::select('SELECT 1');
            Cache::put($key, true, 5);
            abort_unless(Cache::get($key) === true, 503);
            return response()->json(['status' => 'ok'])->header('Cache-Control', 'no-store');
        } catch (\Throwable) {
            return response()->json(['status' => 'unavailable'], 503)->header('Cache-Control', 'no-store');
        } finally {
            try { Cache::forget($key); } catch (\Throwable) {}
        }
    }
}
