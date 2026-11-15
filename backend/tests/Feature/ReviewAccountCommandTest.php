<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReviewAccountCommandTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    public function test_it_refuses_without_a_password(): void
    {
        putenv('REVIEW_ACCOUNT_PASSWORD');
        $this->artisan('app:review-account')->assertExitCode(1);
        $this->assertDatabaseMissing('users', ['username' => 'review']);
    }

    public function test_it_creates_a_loginable_adult_review_account_and_is_repeatable(): void
    {
        putenv('REVIEW_ACCOUNT_PASSWORD=Review-Pass-Long-123');
        $this->artisan('app:review-account')->assertExitCode(0);
        $this->artisan('app:review-account')->assertExitCode(0);
        putenv('REVIEW_ACCOUNT_PASSWORD');

        $this->assertSame(1, User::where('username', 'review')->count());
        $this->postJson('/api/v1/auth/login', ['identifier' => 'review', 'password' => 'Review-Pass-Long-123'])
            ->assertOk()->assertJsonPath('data.user.username', 'review');
    }
}
