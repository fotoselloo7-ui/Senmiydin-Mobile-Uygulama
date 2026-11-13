<?php

namespace App\Http\Middleware;

use App\Http\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ProductionSecurity
{
    public function handle(Request $request, Closure $next): Response
    {
        if (app()->environment('production')) {
            config(['app.debug' => false]);
            abort_unless(parse_url(config('app.url'), PHP_URL_SCHEME) === 'https', 503);
            $host = parse_url(config('app.url'), PHP_URL_HOST);
            abort_unless(is_string($host) && $request->getHost() === $host, 400);
            if (! $request->isSecure()) {
                if ($request->is('api/*') || ! $request->isMethodSafe()) {
                    return ApiResponse::error('Güvenli HTTPS bağlantısı gerekli.', 426);
                }
                return redirect(rtrim(config('app.url'), '/').$request->getRequestUri(), 308);
            }
        }
        // Enforce transport before CORS can short-circuit a preflight request.
        $response = app(\Illuminate\Http\Middleware\HandleCors::class)->handle($request, $next);
        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->headers->set('X-Frame-Options', 'DENY');
        if (app()->environment('production')) {
            $response->headers->set('Strict-Transport-Security', 'max-age=31536000');
        }
        if ($request->is('api/*')) {
            $response->headers->set('Cache-Control', 'private, no-store');
        }
        return $response;
    }
}
