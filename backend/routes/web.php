<?php

use App\Http\Controllers\Admin\ModerationController;
use App\Http\Controllers\Admin\RecordsController;
use App\Http\Controllers\Admin\SessionController;
use App\Http\Controllers\Admin\SystemController;
use App\Http\Controllers\WebsiteController;
use App\Http\Middleware\AdminAccess;
use Illuminate\Support\Facades\Route;

Route::post('/auth/apple/callback', [App\Http\Controllers\SocialAuthController::class, 'appleCallback'])->middleware('throttle:20,1');

Route::get('/health', App\Http\Controllers\HealthController::class)->middleware('throttle:60,1');

Route::get('/', [WebsiteController::class, 'page'])->name('website.home');
Route::get('/{slug}', [WebsiteController::class, 'page'])->whereIn('slug', [
    'nasil-calisir', 'ozellikler', 'guvenlik', 'gizlilik', 'kvkk', 'kullanim-kosullari',
    'topluluk-kurallari', 'iletisim', 'hesap-silme',
])->name('website.page');
Route::post('/{slug}', [WebsiteController::class, 'submit'])->whereIn('slug', ['iletisim', 'hesap-silme'])->middleware('throttle:website-form');
Route::get('/sitemap.xml', [WebsiteController::class, 'sitemap']);
Route::get('/robots.txt', [WebsiteController::class, 'robots']);

Route::prefix('admin')->name('admin.')->group(function (): void {
    Route::get('login', [SessionController::class, 'create'])->name('login');
    Route::post('login', [SessionController::class, 'store'])->middleware('throttle:admin-login')->name('login.store');
    Route::middleware(AdminAccess::class)->group(function (): void {
        Route::get('/', [RecordsController::class, 'dashboard'])->name('dashboard');
        Route::post('logout', [SessionController::class, 'destroy'])->name('logout');
        Route::get('media/{media}', [RecordsController::class, 'media'])->whereNumber('media')->name('media');
        Route::get('reports/{report}/image', [RecordsController::class, 'reportImage'])->whereNumber('report')->name('report.image');
        Route::get('{section}', [RecordsController::class, 'index'])->name('index');
        Route::get('{section}/{id}', [RecordsController::class, 'detail'])->whereNumber('id')->name('detail');
        Route::post('users/{id}', [ModerationController::class, 'user'])->whereNumber('id')->name('user.action');
        Route::post('{section}/{id}/moderate', [ModerationController::class, 'content'])
            ->whereNumber('id')->whereIn('section', ['posts', 'comments', 'encounters'])->name('content.action');
        Route::post('reports/{id}', [ModerationController::class, 'report'])->whereNumber('id')->name('report.action');
    });
    Route::middleware(AdminAccess::class.':system')->group(function (): void {
        Route::post('featured/{id}', [ModerationController::class, 'featured'])->whereNumber('id')->name('featured.update');
        Route::post('settings', [SystemController::class, 'settings'])->name('settings.update');
        Route::post('interests/{id?}', [SystemController::class, 'interest'])->whereNumber('id')->name('interests.save');
        Route::post('cities/{id}', [SystemController::class, 'city'])->whereNumber('id')->name('cities.update');
        Route::post('legal/{slug}', [SystemController::class, 'legal'])->name('legal.update');
        Route::post('announcements', [SystemController::class, 'announcement'])->name('announcements.create');
        Route::post('announcements/{id}', [SystemController::class, 'updateAnnouncement'])->whereNumber('id')->name('announcements.update');
        Route::post('requests/{id}', [SystemController::class, 'support'])->whereNumber('id')->name('requests.handle');
    });
});
