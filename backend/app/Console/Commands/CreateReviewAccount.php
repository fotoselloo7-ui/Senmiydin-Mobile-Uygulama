<?php

namespace App\Console\Commands;

use App\Models\City;
use App\Models\Interest;
use App\Models\User;
use Illuminate\Console\Command;

/**
 * Creates (or resets) the normal-role account that Google Play / App Store reviewers sign in with.
 * The password is read from REVIEW_ACCOUNT_PASSWORD (never stored in the repository); run once after deployment:
 *   REVIEW_ACCOUNT_PASSWORD=... php artisan app:review-account
 */
class CreateReviewAccount extends Command
{
    protected $signature = 'app:review-account {--username=review} {--email=review@senmiydin.tr} {--city=alanya}';

    protected $description = 'Create or reset the store-review account (password from REVIEW_ACCOUNT_PASSWORD)';

    public function handle(): int
    {
        $password = (string) env('REVIEW_ACCOUNT_PASSWORD', '');
        if (strlen($password) < 12) {
            $this->error('Set REVIEW_ACCOUNT_PASSWORD (at least 12 characters) in the environment first.');

            return 1;
        }
        $city = City::where('slug', $this->option('city'))->first();
        if (! $city) {
            $this->error('City not found; run the seeders first.');

            return 1;
        }
        $username = (string) $this->option('username');
        $email = (string) $this->option('email');
        $existing = User::where('username', $username)->first();
        if ($existing && $existing->email !== $email) {
            $this->error("Username already belongs to another account: $username");

            return 1;
        }
        $user = $existing ?? new User(['username' => $username, 'email' => $email]);
        $user->password = $password;
        $user->forceFill([
            'name' => 'Store Reviewer', 'city_id' => $city->id, 'birth_date' => '1990-01-01',
            'bio' => 'Account for App Review.', 'nearby_visible' => false, 'city_discovery' => true,
            'encounter_suggestions' => true, 'onboarding_step' => 3, 'location_history_enabled' => false,
        ])->save();
        $user->interests()->sync(Interest::orderBy('sort_order')->limit(4)->pluck('id'));
        $this->info("Review account ready: $username ($email)");

        return 0;
    }
}
