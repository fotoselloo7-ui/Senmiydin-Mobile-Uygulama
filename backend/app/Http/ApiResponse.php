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
        static $english = null;
        if (app()->getLocale() !== 'en') {
            return $message;
        }
        $english ??= require lang_path('en/messages.php');

        return $english[$message] ?? $message;
    }

    private static function localizeAll(array $errors): array
    {
        return array_map(fn ($value) => is_array($value) ? self::localizeAll($value) : (is_string($value) ? self::localize($value) : $value), $errors);
    }
}
