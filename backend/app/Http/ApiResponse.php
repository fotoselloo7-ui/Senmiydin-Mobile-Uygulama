<?php

namespace App\Http;

use Illuminate\Contracts\Pagination\Paginator;
use Illuminate\Http\JsonResponse;

final class ApiResponse
{
    public static function ok(mixed $data = null, string $message = 'İşlem tamamlandı.', int $status = 200): JsonResponse
    {
        return response()->json(['success' => true, 'message' => self::localize($message), 'data' => $data], $status);
    }

    public static function page(Paginator $page, string $resource): JsonResponse
    {
        return self::ok([
            'items' => $resource::collection($page->items()),
            'next_page' => $page->hasMorePages() ? $page->currentPage() + 1 : null,
        ]);
    }

    public static function error(string $message, int $status, array $errors = []): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => self::localize($message),
            'data' => null,
            'errors' => (object) self::localizeAll($errors),
        ], $status);
    }

    /** English text for a Turkish API message when the request language is English; otherwise (or unknown) unchanged. */
    public static function localize(string $message): string
    {
        static $english = null, $patterns = null;
        if (app()->getLocale() !== 'en') {
            return $message;
        }
        $english ??= require lang_path('en/messages.php');
        if (isset($english[$message])) {
            return $english[$message];
        }
        // Sentences that carry a number or a place name ("En fazla 4 fotoğraf ...", "Alanya · Yaklaşık bölge").
        $patterns ??= require lang_path('en/message_patterns.php');
        foreach ($patterns as $pattern => $replacement) {
            if (preg_match($pattern, $message)) {
                return preg_replace($pattern, $replacement, $message);
            }
        }

        return $message;
    }

    /**
     * Field errors in the request language. Laravel's own English sentences ("The q field is required.") are only
     * produced for rules without a written message; a Turkish reader gets one clear Turkish sentence instead of them.
     */
    public static function fieldErrors(array $errors): array
    {
        if (app()->getLocale() === 'en') {
            return $errors;
        }

        return array_map(fn ($messages) => array_map(
            fn ($message) => is_string($message) && preg_match('/^The [\x20-\x7E]+$/', $message) ? 'Bu bilgi geçerli değil. Kontrol edip tekrar dene.' : $message,
            (array) $messages,
        ), $errors);
    }

    private static function localizeAll(array $errors): array
    {
        return array_map(fn ($value) => is_array($value) ? self::localizeAll($value) : (is_string($value) ? self::localize($value) : $value), $errors);
    }
}
