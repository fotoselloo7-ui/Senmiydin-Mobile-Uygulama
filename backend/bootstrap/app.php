<?php

use App\Http\ApiResponse;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->replace(\Illuminate\Http\Middleware\TrustProxies::class, App\Http\Middleware\TrustedProxies::class);
        $middleware->replace(\Illuminate\Http\Middleware\HandleCors::class, App\Http\Middleware\ProductionSecurity::class);
        $middleware->appendToGroup('api', App\Http\Middleware\SetLocale::class);
        $middleware->appendToGroup('api', App\Http\Middleware\MobileAvailability::class);
        $middleware->validateCsrfTokens(except: ['auth/apple/callback']);
        $middleware->redirectGuestsTo(fn () => null);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->dontFlash(['current_password', 'password', 'password_confirmation', 'token', 'id_token', 'authorization_code']);
        $exceptions->report(function (Throwable $error) {
            if (app()->environment('production')) {
                // Do not record exception messages, SQL bindings, tokens or request bodies.
                \Illuminate\Support\Facades\Log::error('Application operation failed', ['exception_type' => $error::class]);
                return false;
            }
        });
        $exceptions->shouldRenderJsonWhen(fn (Request $request, Throwable $error) => $request->is('api/*') || $request->expectsJson()
        );

        $exceptions->render(function (Throwable $error, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }
            if ($error instanceof ValidationException) {
                return ApiResponse::error('Bilgilerini kontrol et.', 422, $error->errors());
            }
            if ($error instanceof AuthenticationException) {
                return ApiResponse::error('Oturumun sona erdi. Tekrar giriş yap.', 401);
            }

            $status = $error instanceof HttpExceptionInterface ? $error->getStatusCode() : 500;
            $headers = $error instanceof HttpExceptionInterface ? $error->getHeaders() : [];
            $message = match ($status) {
                401 => 'Oturumun sona erdi. Tekrar giriş yap.',
                403 => 'Bu işlemi yapamazsın.',
                404 => 'Aradığın kayıt bulunamadı.',
                409 => 'İçerik güncellendi. Ekranı yenileyip tekrar dene.',
                405 => 'Bu işlem desteklenmiyor.',
                413 => 'Dosya çok büyük.',
                429 => 'Çok fazla deneme yaptın. Biraz sonra tekrar dene.',
                default => $status >= 500 ? 'Bir sorun oluştu. Daha sonra tekrar dene.' : 'İşlem tamamlanamadı.',
            };

            return ApiResponse::error($message, $status)->withHeaders($headers);
        });
    })->create();
