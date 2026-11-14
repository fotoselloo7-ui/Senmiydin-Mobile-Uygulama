<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Picks the response language: the signed-in user's saved choice, otherwise Accept-Language (tr / en), otherwise
 * Turkish. Everything the API says to the person (validation, notification text) follows this one decision.
 */
class SetLocale
{
    public const SUPPORTED = ['tr', 'en'];

    public function handle(Request $request, Closure $next): Response
    {
        $user = Auth::guard('sanctum')->user();
        $saved = $user instanceof User ? $user->preferred_locale : null;
        app()->setLocale(in_array($saved, self::SUPPORTED, true) ? $saved : $this->fromHeader($request));

        return $next($request);
    }

    private function fromHeader(Request $request): string
    {
        foreach (explode(',', (string) $request->header('Accept-Language')) as $part) {
            $language = strtolower(substr(trim(explode(';', $part)[0]), 0, 2));
            if (in_array($language, self::SUPPORTED, true)) {
                return $language;
            }
        }

        return 'tr';
    }
}
