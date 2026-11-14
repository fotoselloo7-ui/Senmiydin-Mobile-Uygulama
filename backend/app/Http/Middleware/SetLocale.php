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
        $header = $this->fromHeader($request);
        if ($user instanceof User && $header !== null && $user->last_locale !== $header) {
            // Pushes are sent from queue workers with no request to read a header from: remember the language the
            // person's app last spoke so an unset account still gets pushes in the language it sees in the app.
            User::whereKey($user->getKey())->update(['last_locale' => $header]);
            $user->last_locale = $header;
        }
        app()->setLocale(self::resolve($saved, $header));

        return $next($request);
    }

    /** Language for a request without touching the account (used when an error is rendered before the middleware ran). */
    public static function forRequest(Request $request): string
    {
        $user = Auth::guard('sanctum')->user();
        $header = null;
        foreach (explode(',', (string) $request->header('Accept-Language')) as $part) {
            $language = strtolower(substr(trim(explode(';', $part)[0]), 0, 2));
            if (in_array($language, self::SUPPORTED, true)) {
                $header = $language;
                break;
            }
        }

        return self::resolve($user instanceof User ? $user->preferred_locale : null, $header);
    }

    /** The one language decision: a saved choice, else the request header (or the app's last header), else Turkish. */
    public static function resolve(?string $saved, ?string $header = null): string
    {
        return in_array($saved, self::SUPPORTED, true) ? $saved : (in_array($header, self::SUPPORTED, true) ? $header : 'tr');
    }

    /** Language for work done without a request (push, mail): the saved choice, else what the app last sent. */
    public static function forUser(User $user): string
    {
        return self::resolve($user->preferred_locale, $user->last_locale);
    }

    private function fromHeader(Request $request): ?string
    {
        foreach (explode(',', (string) $request->header('Accept-Language')) as $part) {
            $language = strtolower(substr(trim(explode(';', $part)[0]), 0, 2));
            if (in_array($language, self::SUPPORTED, true)) {
                return $language;
            }
        }

        return null;
    }
}
