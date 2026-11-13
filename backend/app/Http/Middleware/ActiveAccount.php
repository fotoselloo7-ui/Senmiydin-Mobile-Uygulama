<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ActiveAccount
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->isMethodSafe()) {
            abort_unless($request->user()->account_status === 'active', 401);
            return $next($request);
        }
        // Serialize account writes with erasure so an in-flight request cannot recreate personal data.
        return \Illuminate\Support\Facades\DB::transaction(function () use ($request, $next) {
            $user = \App\Models\User::lockForUpdate()->findOrFail($request->user()->id);
            abort_unless($user->account_status === 'active', 401);
            $token = $request->user()->currentAccessToken();
            if ($token instanceof \Laravel\Sanctum\PersonalAccessToken) {
                abort_unless($token->newQuery()->whereKey($token->id)->exists(), 401);
            }
            // Controllers must reauthenticate against the locked current password, not a cached guard snapshot.
            \Illuminate\Support\Facades\Auth::guard('sanctum')->setUser($user->withAccessToken($token));
            return $next($request);
        }, 3);
    }
}
