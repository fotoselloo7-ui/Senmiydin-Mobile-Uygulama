<?php

namespace App\Providers;

use App\Location\CityResolver;
use App\Location\ProfileCityFallback;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->scoped(\App\Administration\Settings::class);
        $this->app->bind(CityResolver::class, \App\Places\PlaceCityResolver::class);
        // Which place provider answers is configuration only (PLACES_PROVIDER); the app never knows.
        $this->app->bind(\App\Places\PlaceSearchProvider::class, fn () => match (config('places.provider')) {
            'nominatim' => new \App\Places\NominatimProvider,
            default => new \App\Places\NoPlaceProvider,
        });
        $this->app->singleton(\App\Places\PlaceDirectory::class);
    }

    public function boot(): void
    {
        if ($this->app->environment('production')) {
            config(['app.debug' => false, 'session.secure' => true, 'session.http_only' => true, 'session.encrypt' => true]);
            \Illuminate\Support\Facades\URL::forceRootUrl(config('app.url'));
            \Illuminate\Support\Facades\URL::forceScheme('https');
        }
        RateLimiter::for('admin-login', function (Request $request): array {
            $value = $request->input('email');
            $email = is_string($value) ? strtolower(trim($value)) : '';
            return [Limit::perMinute(15)->by('ip:'.$request->ip()),
                Limit::perMinute(5)->by('identity:'.hash('sha256', $email).'|'.$request->ip())];
        });
        RateLimiter::for('website-form', fn (Request $request) => Limit::perMinutes(10, 5)->by($request->ip()));
        RateLimiter::for('registration', fn (Request $request) => Limit::perMinute(5)->by($request->ip()));
        RateLimiter::for('login', function (Request $request): array {
            $identifier = $request->input('identifier');
            $identity = is_string($identifier) ? strtolower(trim($identifier)) : '';

            return [
                Limit::perMinute(30)->by('ip:'.$request->ip()),
                Limit::perMinute(5)->by('identity:'.hash('sha256', $identity).'|'.$request->ip()),
            ];
        });
        // Place search is explicit (a search button, never per keystroke): 20 calls a minute are plenty for a person.
        RateLimiter::for('places', fn (Request $request) => Limit::perMinute(20)->by('places:'.($request->user()?->id ?? $request->ip())));
        RateLimiter::for('password-recovery', fn (Request $request) => Limit::perMinute(5)->by($request->ip()));
        foreach (['post-write' => 15, 'comment-write' => 30, 'reaction' => 120, 'social-search' => 90, 'location-write' => 12, 'location-read' => 60, 'encounter-action' => 30, 'communication-read' => 120, 'message-write' => 40] as $name => $limit) {
            RateLimiter::for($name, fn (Request $request) => Limit::perMinute($limit)->by($request->user()->id));
        }

        // Notes: 8 per hour. Replies: 10 per minute and 60 per hour per account.
        RateLimiter::for('map-note-create', fn (Request $request) => Limit::perHour((int) config('map_notes.create_per_hour'))->by($request->user()->id));
        RateLimiter::for('map-note-reply', fn (Request $request) => [
            Limit::perMinute(10)->by('reply-m:'.$request->user()->id), Limit::perHour(60)->by('reply-h:'.$request->user()->id),
        ]);
        RateLimiter::for('account-deletion', fn (Request $request) => Limit::perMinute(3)->by($request->user()->id));
        RateLimiter::for('password-change', fn (Request $request) => Limit::perMinute(5)->by($request->user()->id));
    }
}
