<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AdminAccess
{
    public function handle(Request $request, Closure $next, string $permission = 'moderate'): Response
    {
        $admin = $request->user('admin');
        if (! $admin || ! $admin->is_active) {
            return redirect()->guest(route('admin.login'));
        }

        abort_unless($permission === 'system' ? $admin->canManageSystem() : $admin->canModerate(), 403);
        $response = $next($request);
        $response->headers->set('Cache-Control', 'private, no-store');
        $response->headers->set('X-Robots-Tag', 'noindex, nofollow');
        $response->headers->set('X-Frame-Options', 'DENY');
        return $response;
    }
}
