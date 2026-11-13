<?php

namespace App\Http\Middleware;

use App\Administration\Settings;
use App\Http\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class MobileAvailability
{
    public function __construct(private readonly Settings $settings) {}

    public function handle(Request $request, Closure $next): Response
    {
        if ($request->is('api/v1/app-config', 'api/v1/auth/logout', 'api/v1/auth/login', 'api/v1/auth/forgot-password', 'api/v1/auth/reset-password', 'api/v1/auth/account', 'api/v1/avatars/*', 'api/v1/legal/*')) {
            return $next($request);
        }

        if ($this->settings->get('maintenance_mode')) {
            return $this->unavailable($this->settings->get('maintenance_message'), 'maintenance');
        }
        if ($request->is('api/v1/auth/register') && ! $this->settings->get('registrations_enabled')) {
            return $this->unavailable('Yeni kayıtlar şu anda kapalı.', 'registrations');
        }
        if (! $this->settings->get('encounters_enabled') && ($request->is('api/v1/encounter-requests', 'api/v1/encounter-requests/*', 'api/v1/encounters/*')
            || ($request->isMethod('POST') && $request->is('api/v1/posts') && $request->input('type') === 'encounter'))
            && ! $request->is('api/v1/encounters/featured')) {
            return $this->unavailable('Karşılaşma işlemleri şu anda kullanılamıyor.', 'encounters');
        }
        if (! $this->settings->get('messaging_enabled') && $request->is('api/v1/conversations*', 'api/v1/users/*/conversation', 'api/v1/users/*/messages', 'api/v1/message-images/*')) {
            return $this->unavailable('Mesajlaşma şu anda kullanılamıyor.', 'messaging');
        }
        return $next($request);
    }

    private function unavailable(string $message, string $feature): Response
    {
        return response()->json(['success' => false, 'message' => $message, 'data' => null, 'errors' => (object) [], 'unavailable' => $feature], 503)
            ->header('Cache-Control', 'no-store');
    }
}
