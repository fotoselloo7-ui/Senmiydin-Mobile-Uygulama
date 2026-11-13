<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\Interest;
use App\Models\User;
use App\Notifications\PasswordResetCode;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class AccountApiTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private const PASSWORD = 'GeciciSifre123';

    private const NEW_PASSWORD = 'YeniSifre456';

    public function test_register_normalizes_identity_and_hashes_password(): void
    {
        $response = $this->postJson('/api/v1/auth/register', $this->registration([
            'username' => '  DeNiZ.01  ',
            'email' => '  DENIZ@example.test  ',
        ]));
        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.user.username', 'deniz.01')
            ->assertJsonPath('data.user.email', 'deniz@example.test')
            ->assertJsonMissingPath('data.user.password');

        $user = User::sole();
        $this->assertTrue(Hash::check(self::PASSWORD, $user->password));
        $this->assertNotSame($response->json('data.token'), $user->tokens()->sole()->token);
    }

    public function test_hash_like_passwords_are_hashed_as_plaintext(): void
    {
        $password = Hash::make(self::PASSWORD);
        $this->postJson('/api/v1/auth/register', $this->registration(['password' => $password]))
            ->assertCreated();

        $this->assertTrue(Hash::check($password, User::sole()->password));
        $this->login('deniz', self::PASSWORD)->assertUnauthorized();
        $this->login('deniz', $password)->assertOk();
    }

    public function test_register_validates_age_unique_identity_and_input_types(): void
    {
        $this->postJson('/api/v1/auth/register', $this->registration())->assertCreated();
        $this->postJson('/api/v1/auth/register', $this->registration([
            'username' => 'DENIZ',
            'email' => 'DENIZ@example.test',
            'birth_date' => now('Europe/Istanbul')->subYears(17)->toDateString(),
            'accepted_terms' => false,
        ]))->assertUnprocessable()->assertJsonValidationErrors([
            'username', 'email', 'birth_date', 'accepted_terms',
        ]);
        $this->postJson('/api/v1/auth/register', $this->registration([
            'email' => ['deniz@example.test'],
        ]))->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->postJson('/api/v1/auth/register', $this->registration([
            'password' => self::PASSWORD."\0",
        ]))->assertUnprocessable()->assertJsonValidationErrors('password');
    }

    public function test_login_supports_username_and_email_and_throttles_invalid_attempts(): void
    {
        $this->register();
        $this->login(' DENIZ ')->assertOk()->assertJsonPath('data.user.username', 'deniz');
        $this->login(' DENIZ@EXAMPLE.TEST ')->assertOk();
        for ($attempt = 0; $attempt < 5; $attempt++) {
            $this->login('unknown', 'wrong')->assertUnauthorized();
        }
        $this->login('UNKNOWN', 'wrong')->assertTooManyRequests()->assertHeader('Retry-After');
    }

    public function test_me_requires_valid_token_and_logout_revokes_it(): void
    {
        $token = $this->register();
        $this->get('/api/v1/auth/me')->assertUnauthorized()->assertJsonPath('success', false);
        $this->token($token)->getJson('/api/v1/auth/me')
            ->assertOk()->assertJsonPath('data.username', 'deniz');
        $this->token($token)->postJson('/api/v1/auth/logout')->assertOk();
        $this->token($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_profile_updates_fields_and_privacy_without_mass_assigning_protected_fields(): void
    {
        $token = $this->register();
        $city = City::where('name', 'Ankara')->firstOrFail();
        $this->token($token)->putJson('/api/v1/profile', [
            'name' => 'Deniz Yıldız',
            'username' => ' Yeni.Deniz ',
            'bio' => 'Kitap ve müzik.',
            'occupation_school' => 'Mühendis',
            'city_id' => $city->id,
            'nearby_visible' => true,
            'encounter_suggestions' => true,
            'city_discovery' => false,
            'connections' => ['chat', 'friendship'],
            'complete_profile' => true,
            'account_status' => 'disabled',
            'password' => 'ignored',
        ])->assertOk()
            ->assertJsonPath('data.username', 'yeni.deniz')
            ->assertJsonPath('data.city.name', 'Ankara')
            ->assertJsonPath('data.account_status', 'active')
            ->assertJsonPath('data.onboarding_step', 1);
        $this->token($token)->getJson('/api/v1/profile')->assertOk()->assertJsonPath('data', fn (array $profile) => $profile['bio'] === 'Kitap ve müzik.' &&
            $profile['nearby_visible'] && $profile['encounter_suggestions'] &&
            ! $profile['city_discovery'] && $profile['connections'] === ['chat', 'friendship']
        );
        $this->assertTrue(Hash::check(self::PASSWORD, User::sole()->password));
    }

    public function test_catalogs_exclude_inactive_entries_and_interests_are_saved_by_id(): void
    {
        City::where('name', 'Ankara')->update(['is_active' => false]);
        $this->getJson('/api/v1/cities')->assertOk()
            ->assertJsonMissing(['name' => 'Ankara'])->assertJsonFragment(['name' => 'İstanbul']);
        $inactive = Interest::orderBy('sort_order')->firstOrFail();
        $inactive->forceFill(['is_active' => false])->save();
        $this->getJson('/api/v1/interests')->assertOk()->assertJsonCount(20, 'data')
            ->assertJsonMissing(['id' => $inactive->id]);
        $ids = Interest::where('is_active', true)->limit(5)->pluck('id')->all();
        $token = $this->register();
        $this->token($token)->putJson('/api/v1/profile', ['finish_setup' => true])
            ->assertUnprocessable();
        $this->token($token)->putJson('/api/v1/profile', ['complete_profile' => true])->assertOk();
        $this->token($token)->putJson('/api/v1/profile/interests', ['interest_ids' => array_slice($ids, 0, 4)])
            ->assertUnprocessable();
        $this->token($token)->putJson('/api/v1/profile/interests', ['interest_ids' => [...$ids, $inactive->id]])
            ->assertUnprocessable();
        $this->token($token)->putJson('/api/v1/profile/interests', ['interest_ids' => $ids])
            ->assertOk()->assertJsonPath('data.onboarding_step', 2);
        $response = $this->token($token)->getJson('/api/v1/profile/interests')->assertOk();
        $this->assertEqualsCanonicalizing($ids, array_column($response->json('data'), 'id'));
        $this->token($token)->putJson('/api/v1/profile', ['finish_setup' => true, 'city_discovery' => true])
            ->assertOk()->assertJsonPath('data.onboarding_step', 3)->assertJsonPath('data.city_discovery', true);
    }

    public function test_avatar_is_validated_served_and_replaced(): void
    {
        $disk = Storage::fake(config('mobile.avatar_disk'));
        $token = $this->register();
        $this->token($token)->postJson('/api/v1/profile/avatar', [
            'avatar' => UploadedFile::fake()->create('not-an-image.jpg', 10),
        ])->assertUnprocessable()->assertJsonValidationErrors('avatar');
        $first = $this->token($token)->postJson('/api/v1/profile/avatar', [
            'avatar' => UploadedFile::fake()->image('profile.png', 64, 64),
        ])->assertOk()->json('data.avatar');
        $this->flushHeaders()->get($first)->assertOk()->assertHeader('Content-Type', 'image/jpeg');
        $second = $this->token($token)->postJson('/api/v1/profile/avatar', [
            'avatar' => UploadedFile::fake()->image('new.jpg', 96, 96),
        ])->assertOk()->json('data.avatar');
        $this->assertNotSame($first, $second);
        $disk->assertMissing('avatars/'.basename($first));
        $disk->assertExists('avatars/'.basename($second));
        $this->token($token)->getJson('/api/v1/profile')->assertJsonPath('data.avatar', $second);
    }

    public function test_password_reset_is_private_single_use_and_revokes_sessions(): void
    {
        Notification::fake();
        $token = $this->register();
        $response = $this->postJson('/api/v1/auth/forgot-password', ['email' => ' DENIZ@example.test '])->assertOk();
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'unknown@example.test'])
            ->assertOk()->assertExactJson($response->json());
        $notifications = Notification::sent(User::sole(), PasswordResetCode::class);
        $this->assertCount(1, $notifications);
        $fields = [
            'email' => 'deniz@example.test',
            'token' => $notifications->sole()->token,
            'password' => self::NEW_PASSWORD,
            'password_confirmation' => self::NEW_PASSWORD,
        ];
        $this->postJson('/api/v1/auth/reset-password', $fields)->assertOk();
        $this->postJson('/api/v1/auth/reset-password', $fields)->assertUnprocessable()->assertJsonValidationErrors('token');
        $this->token($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->flushHeaders();
        $this->login('deniz')->assertUnauthorized();
        $this->login('deniz', self::NEW_PASSWORD)->assertOk();
    }

    public function test_password_change_checks_current_password_and_revokes_other_sessions(): void
    {
        $token = $this->register();
        $otherToken = $this->login('deniz')->assertOk()->json('data.token');
        $fields = [
            'current_password' => self::PASSWORD,
            'password' => self::NEW_PASSWORD,
            'password_confirmation' => self::NEW_PASSWORD,
        ];
        $this->token($token)->putJson('/api/v1/auth/password', [...$fields, 'current_password' => 'wrong'])
            ->assertUnprocessable()->assertJsonValidationErrors('current_password');
        $this->token($token)->putJson('/api/v1/auth/password', $fields)->assertOk();
        $this->token($otherToken)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->token($token)->getJson('/api/v1/auth/me')->assertOk();
        $this->flushHeaders();
        $this->login('deniz', self::NEW_PASSWORD)->assertOk();
    }

    private function registration(array $overrides = []): array
    {
        return [...[
            'name' => 'Deniz Örnek',
            'username' => 'deniz',
            'email' => 'deniz@example.test',
            'password' => self::PASSWORD,
            'birth_date' => '1998-04-12',
            'city_id' => City::where('name', 'Alanya')->value('id'),
            'accepted_terms' => true,
        ], ...$overrides];
    }

    private function register(): string
    {
        return $this->postJson('/api/v1/auth/register', $this->registration())
            ->assertCreated()->json('data.token');
    }

    private function login(string $identifier, string $password = self::PASSWORD): TestResponse
    {
        return $this->postJson('/api/v1/auth/login', compact('identifier', 'password'));
    }

    private function token(string $token): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($token);
    }
}
