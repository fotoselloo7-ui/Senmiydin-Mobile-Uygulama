<?php

use App\Location\LocationData;
use App\Models\Post;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schedule;
use Illuminate\Support\Facades\Storage;

Schedule::command('sanctum:prune-expired --hours=24')->daily()->withoutOverlapping();

Artisan::command('posts:purge-deleted', function (): int {
    $failed = 0;
    $posts = Post::onlyTrashed()->whereNull('moderated_at')->where('deleted_at', '<=', now()->subDays(30))->with('media');
    $posts->chunkById(100, function ($entries) use (&$failed): void {
        foreach ($entries as $post) {
            foreach ($post->media as $media) {
                $disk = Storage::disk($media->disk);
                if ($disk->exists($media->file_path) && ! $disk->delete($media->file_path)) {
                    $failed++;

                    continue 2;
                }
            }
            $post->forceDelete();
        }
    });

    return $failed === 0 ? 0 : 1;
})->purpose('Remove expired deleted posts and their private media');

Schedule::command('posts:purge-deleted')->daily()->withoutOverlapping();

Artisan::command('location:purge', function (): void {
    $cutoff = LocationData::cutoff();
    DB::table('user_location_history')->where('recorded_at', '<', $cutoff)->delete();
    DB::table('location_matches')->where('matched_at', '<', $cutoff)->delete();
    DB::table('user_locations')->where('recorded_at', '<', now()->subDay())->delete();
})->purpose('Remove expired location records');

Schedule::command('location:purge')->hourly()->withoutOverlapping();

Schedule::call(fn () => app(App\Administration\Announcements::class)->run())
    ->name('announcements.publish')->everyMinute()->withoutOverlapping();

Artisan::command('admin:create {email} {--moderator}', function (): int {
    $email = \Illuminate\Support\Str::lower(trim($this->argument('email')));
    $name = $this->ask('Yönetici adı');
    $password = $this->secret('Parola (en az 12 karakter)');
    $confirmation = $this->secret('Parolayı doğrula');
    $validator = \Illuminate\Support\Facades\Validator::make(
        ['name' => $name, 'email' => $email, 'password' => $password, 'password_confirmation' => $confirmation],
        ['name' => 'required|string|max:100', 'email' => 'required|email|max:254|unique:admins,email',
            'password' => ['required', 'string', 'min:12', 'confirmed', fn ($attribute, $value, $fail) =>
                strlen($value) > 72 ? $fail('Parola en fazla 72 bayt olabilir.') : null]],
    );
    if ($validator->fails()) {
        foreach ($validator->errors()->all() as $error) {
            $this->error($error);
        }
        return 1;
    }
    App\Models\Admin::create(['name' => $name, 'email' => $email, 'password' => $password,
        'role' => $this->option('moderator') ? 'moderator' : 'super_admin']);
    $this->info('Yönetici hesabı oluşturuldu.');
    return 0;
})->purpose('Create an administrator without passing a password in the command line');

Artisan::command('media:cleanup', fn () => app(\App\Accounts\MediaCleanup::class)->run() === 0 ? 0 : 1)
    ->purpose('Retry removal of erased account media');
Schedule::command('media:cleanup')->everyTenMinutes()->withoutOverlapping();

Artisan::command('oauth:revoke-deleted', function (): int {
    $failed = 0;
    DB::table('oauth_revocations')->orderBy('id')->chunkById(100, function ($items) use (&$failed): void {
        foreach ($items as $item) {
            try {
                app(\App\Auth\AppleTokens::class)->revoke(\Illuminate\Support\Facades\Crypt::decryptString($item->refresh_token), $item->client_id);
                DB::table('oauth_revocations')->where('id', $item->id)->delete();
            } catch (\Throwable) { $failed++; }
        }
    });
    return $failed ? 1 : 0;
})->purpose('Revoke Apple credentials for erased accounts');
Schedule::command('oauth:revoke-deleted')->everyTenMinutes()->withoutOverlapping();

Artisan::command('devices:prune', function (): void {
    DB::table('user_devices')->where('updated_at', '<', now()->subDays(30))
        ->where(fn ($q) => $q->where('is_active', false)->orWhereNotExists(fn ($tokens) => $tokens
            ->selectRaw('1')->from('personal_access_tokens')->whereColumn('personal_access_tokens.id', 'user_devices.personal_access_token_id')))
        ->delete();
})->purpose('Remove inactive or orphaned stale push devices');
Schedule::command('devices:prune')->daily()->withoutOverlapping();

Artisan::command('demo:refresh-locations', function (): int {
    if (! app()->environment('local', 'development')) {
        $this->error('REFUSE: development-only command.');
        return 1;
    }
    // Deterministic fixture rows (explicit city + coordinates) for the seeded demo accounts...
    $restored = Database\Seeders\DemoDataSeeder::restoreLocations();
    // ...and a fresh timestamp for any other local fixture account that already has a location row.
    $seeded = collect(Database\Seeders\DemoDataSeeder::PEOPLE)->map(fn ($p) => Database\Seeders\DemoDataSeeder::email($p[0]));
    $ids = DB::table('users')->where('email', 'like', '%@senmiydin.local')->whereNotIn('email', $seeded)
        ->where('account_status', 'active')->pluck('id');
    DB::table('user_locations')->whereIn('user_id', $ids)->update(['recorded_at' => now(), 'updated_at' => now()]);
    $this->info("Development location fixtures refreshed ({$restored} seeded accounts restored with explicit city); no account was created or removed.");
    return 0;
})->purpose('Restore deterministic development location fixtures (explicit city) without seeding or replacing user data');
