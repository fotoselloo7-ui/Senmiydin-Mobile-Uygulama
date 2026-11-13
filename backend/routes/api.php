<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\ConversationController;
use App\Http\Controllers\InboxController;
use App\Http\Controllers\SafetyController;
use App\Http\Controllers\CatalogController;
use App\Http\Controllers\EncounterController;
use App\Http\Controllers\LocationController;
use App\Http\Controllers\PostController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\SocialUserController;
use App\Http\Middleware\ActiveAccount;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('legal/{slug}', function (string $slug, App\Website\Pages $pages) {
        abort_unless(isset(App\Website\Pages::LEGAL[$slug]), 404);
        return App\Http\ApiResponse::ok($pages->legal()[$slug]);
    })->whereIn('slug', array_keys(App\Website\Pages::LEGAL));
    Route::get('app-config', App\Http\Controllers\AppConfigController::class);
    Route::get('cities', [CatalogController::class, 'cities']);
    Route::get('interests', [CatalogController::class, 'interests']);
    Route::get('avatars/{filename}', [ProfileController::class, 'image'])
        ->where('filename', '[0-9a-f-]{36}\.jpg')->name('avatars.show');

    Route::prefix('auth')->group(function (): void {
        Route::post('social/apple/challenge', [App\Http\Controllers\SocialAuthController::class, 'challenge'])->middleware('throttle:login');
        Route::post('social/{provider}', [App\Http\Controllers\SocialAuthController::class, 'login'])->whereIn('provider', ['google', 'apple'])->middleware('throttle:login');
        Route::post('register', [AuthController::class, 'register'])->middleware('throttle:registration');
        Route::post('login', [AuthController::class, 'login'])->middleware('throttle:login');
        Route::post('forgot-password', [AuthController::class, 'forgot'])->middleware('throttle:password-recovery');
        Route::post('reset-password', [AuthController::class, 'reset'])->middleware('throttle:password-recovery');
        Route::post('logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
    });

    Route::middleware(['auth:sanctum', ActiveAccount::class])->group(function (): void {
        Route::delete('auth/account', App\Http\Controllers\AccountDeletionController::class)->middleware('throttle:account-deletion');
        Route::get('auth/me', [ProfileController::class, 'show']);
        Route::put('auth/password', [AuthController::class, 'changePassword'])->middleware('throttle:password-change');
        Route::get('profile', [ProfileController::class, 'show']);
        Route::put('profile', [ProfileController::class, 'update']);
        Route::post('profile/avatar', [ProfileController::class, 'uploadAvatar'])->middleware('throttle:12,1');
        Route::put('active-city', [LocationController::class, 'selectCity'])->middleware('throttle:location-write');
        Route::get('location-history', [LocationController::class, 'history'])->middleware('throttle:location-read');
        Route::put('location', [LocationController::class, 'update'])->middleware('throttle:location-write');
        Route::delete('location', [LocationController::class, 'clear'])->middleware('throttle:location-write');
        Route::get('nearby/users', [LocationController::class, 'nearby'])->middleware('throttle:location-read');
        Route::get('map/posts', [LocationController::class, 'map'])->middleware('throttle:location-read');

        Route::get('encounter-requests', [EncounterController::class, 'index']);
        Route::get('encounter-requests/pending-count', [EncounterController::class, 'pendingCount']);
        Route::get('encounter-requests/{invitation}', [EncounterController::class, 'showRequest'])->whereNumber('invitation');
        Route::post('encounter-requests/{invitation}/accept', [EncounterController::class, 'accept'])->whereNumber('invitation')->middleware('throttle:encounter-action');
        Route::post('encounter-requests/{invitation}/reject', [EncounterController::class, 'reject'])->whereNumber('invitation')->middleware('throttle:encounter-action');
        Route::delete('encounter-requests/{invitation}', [EncounterController::class, 'cancel'])->whereNumber('invitation')->middleware('throttle:encounter-action');
        Route::get('encounters/featured', [EncounterController::class, 'featured']);
        Route::get('encounters/{encounter}', [EncounterController::class, 'show'])->whereNumber('encounter');
        Route::put('encounters/{encounter}/story', [EncounterController::class, 'editStory'])->whereNumber('encounter')->middleware('throttle:encounter-action');
        Route::post('encounters/{encounter}/story/approve', [EncounterController::class, 'approveStory'])->whereNumber('encounter')->middleware('throttle:encounter-action');
        Route::post('encounters/{encounter}/story/reject', [EncounterController::class, 'rejectStory'])->whereNumber('encounter')->middleware('throttle:encounter-action');
        Route::get('users/{username}/encounters', [EncounterController::class, 'publicProfile']);

        Route::get('feed', [PostController::class, 'feed']);
        Route::get('posts/saved', [PostController::class, 'saved']);
        Route::post('posts', [PostController::class, 'store'])->middleware('throttle:post-write');
        Route::get('posts/{post}', [PostController::class, 'show'])->whereNumber('post');
        Route::put('posts/{post}', [PostController::class, 'update'])->whereNumber('post')->middleware('throttle:post-write');
        Route::delete('posts/{post}', [PostController::class, 'destroy'])->whereNumber('post')->middleware('throttle:post-write');
        Route::get('post-media/{media}', [PostController::class, 'media'])->whereNumber('media')->name('posts.media');
        Route::match(['POST', 'DELETE'], 'posts/{post}/like', [PostController::class, 'like'])->whereNumber('post')->middleware('throttle:reaction');
        Route::match(['POST', 'DELETE'], 'posts/{post}/save', [PostController::class, 'save'])->whereNumber('post')->middleware('throttle:reaction');
        Route::get('posts/{post}/comments', [PostController::class, 'comments'])->whereNumber('post');
        Route::post('posts/{post}/comments', [PostController::class, 'comment'])->whereNumber('post')->middleware('throttle:comment-write');
        Route::delete('posts/{post}/comments/{comment}', [PostController::class, 'deleteComment'])->whereNumber(['post', 'comment'])->middleware('throttle:comment-write');
        Route::get('users/{username}', [SocialUserController::class, 'show']);
        Route::get('users/{username}/posts', [SocialUserController::class, 'posts']);
        Route::get('users/{username}/followers', [SocialUserController::class, 'followers']);
        Route::get('users/{username}/following', [SocialUserController::class, 'following']);
        Route::match(['POST', 'DELETE'], 'users/{username}/follow', [SocialUserController::class, 'follow'])->middleware('throttle:reaction');
        Route::get('search', [SocialUserController::class, 'search'])->middleware('throttle:social-search');

        Route::middleware('throttle:communication-read')->group(function (): void {
            Route::get('conversations', [ConversationController::class, 'index']);
            Route::get('conversations/{conversation}', [ConversationController::class, 'show'])->whereNumber('conversation');
            Route::get('conversations/{conversation}/messages', [ConversationController::class, 'messages'])->whereNumber('conversation');
            Route::get('users/{user}/conversation', [ConversationController::class, 'peer'])->whereNumber('user');
            Route::get('unread-counts', [ConversationController::class, 'unread']);
            Route::get('notifications', [InboxController::class, 'index']);
            Route::get('notifications/{notification}', [InboxController::class, 'show'])->whereNumber('notification');
            Route::get('blocks', [SafetyController::class, 'blocks']);
        });
        Route::post('users/{user}/messages', [ConversationController::class, 'send'])->whereNumber('user')->middleware('throttle:message-write');
        Route::post('conversations/{conversation}/request/{action}', [ConversationController::class, 'respond'])
            ->whereNumber('conversation')->whereIn('action', ['accept', 'reject'])->middleware('throttle:message-write');
        Route::put('conversations/{conversation}/read', [ConversationController::class, 'read'])->whereNumber('conversation')->middleware('throttle:communication-read');
        Route::delete('conversations/{conversation}', [ConversationController::class, 'hide'])->whereNumber('conversation')->middleware('throttle:message-write');
        Route::delete('conversations/{conversation}/messages/{message}', [ConversationController::class, 'deleteMessage'])
            ->whereNumber(['conversation', 'message'])->middleware('throttle:message-write');
        Route::get('message-images/{message}', [ConversationController::class, 'image'])->whereNumber('message')->name('messages.image');
        Route::put('notifications/read', [InboxController::class, 'read'])->middleware('throttle:communication-read');
        Route::put('notifications/{notification}/read', [InboxController::class, 'read'])->whereNumber('notification')->middleware('throttle:communication-read');
        Route::put('push-device', [InboxController::class, 'device'])->middleware('throttle:12,1');
        Route::delete('push-device/{device}', [InboxController::class, 'disableDevice'])->whereUuid('device')->middleware('throttle:12,1');
        Route::match(['PUT', 'DELETE'], 'blocks/{user}', [SafetyController::class, 'block'])->whereNumber('user')->middleware('throttle:20,1');
        Route::post('reports', [SafetyController::class, 'report'])->middleware('throttle:8,1');

        Route::get('profile/interests', [ProfileController::class, 'interests']);
        Route::put('profile/interests', [ProfileController::class, 'saveInterests']);
    });
});
