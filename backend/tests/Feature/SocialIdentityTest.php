<?php
namespace Tests\Feature;

use App\Auth\IdentityVerifier;
use App\Models\City;
use App\Models\User;
use Firebase\JWT\JWT;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SocialIdentityTest extends TestCase
{
    use RefreshDatabase;
    protected $seed = true;
    private string $key = '';

    protected function setUp(): void
    {
        parent::setUp();
        $config = tempnam(sys_get_temp_dir(), 'senmiydin-test-openssl-');
        file_put_contents($config, "[req]\ndistinguished_name=dn\n[dn]\n");
        try {
            $resource = openssl_pkey_new(['config' => $config, 'private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
            openssl_pkey_export($resource, $this->key, null, ['config' => $config]);
        } finally { unlink($config); }
        $details = openssl_pkey_get_details($resource);
        $encode = fn ($value) => rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
        Http::preventStrayRequests();
        Http::fake(['https://www.googleapis.com/oauth2/v3/certs' => Http::response(['keys' => [[
            'kty' => 'RSA', 'alg' => 'RS256', 'kid' => 'test-key',
            'n' => $encode($details['rsa']['n']), 'e' => $encode($details['rsa']['e']),
        ]]])]);
        config(['social.google.audiences' => ['test-client']]);
    }

    private function signed(array $extra = []): string
    {
        return JWT::encode($extra + [
            'iss' => 'https://accounts.google.com', 'aud' => 'test-client', 'sub' => 'test-subject',
            'iat' => time(), 'exp' => time() + 300, 'email' => 'deniz@example.test', 'email_verified' => true,
        ], $this->key, 'RS256', 'test-key');
    }

    public function test_google_identity_requires_signature_issuer_audience_and_expiry(): void
    {
        foreach ([
            $this->signed(['aud' => 'another-client']), $this->signed(['iss' => 'https://attacker.example']),
            $this->signed(['exp' => time() - 10]), $this->signed(['iat' => time() - 1000]), 'forged.token.value',
        ] as $token) {
            $this->postJson('/api/v1/auth/social/google', ['id_token' => $token])->assertUnprocessable();
        }
        $this->assertDatabaseCount('users', 0);
    }

    public function test_social_registration_uses_normal_age_terms_and_password_validation_then_authenticates_the_identity(): void
    {
        $token = $this->signed();
        $this->postJson('/api/v1/auth/social/google', ['id_token' => $token])->assertStatus(412);
        $fields = ['id_token' => $token, 'username' => 'deniz', 'name' => 'Deniz', 'password' => 'Account12345!',
            'birth_date' => '1995-01-01', 'city_id' => City::first()->id, 'accepted_terms' => false];
        $this->postJson('/api/v1/auth/social/google', $fields)->assertUnprocessable()->assertJsonValidationErrors('accepted_terms');
        $this->postJson('/api/v1/auth/social/google', [...$fields, 'accepted_terms' => true])->assertCreated()
            ->assertJsonPath('data.user.email', 'deniz@example.test');
        $this->postJson('/api/v1/auth/social/google', ['id_token' => $token])->assertOk();
        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseCount('social_identities', 1);
        User::first()->forceFill(['account_status' => 'deleted'])->save();
        $this->postJson('/api/v1/auth/social/google', ['id_token' => $token])->assertUnauthorized();
    }

    public function test_a_matching_email_never_silently_links_an_existing_password_account(): void
    {
        User::create(['name' => 'Deniz', 'username' => 'deniz', 'email' => 'deniz@example.test', 'password' => 'Account12345!',
            'birth_date' => '1995-01-01', 'city_id' => City::first()->id]);
        $this->postJson('/api/v1/auth/social/google', ['id_token' => $this->signed(), 'username' => 'newaccount'])
            ->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->assertDatabaseCount('social_identities', 0);
    }

    public function test_absent_provider_credentials_fail_closed_without_affecting_email_login(): void
    {
        config(['social.google.audiences' => [], 'social.apple.audiences' => []]);
        $this->postJson('/api/v1/auth/social/google', ['id_token' => 'anything'])->assertStatus(503);
        $this->postJson('/api/v1/auth/social/apple/challenge')->assertStatus(503);
        $this->assertFalse(app(IdentityVerifier::class)->configured('apple'));
        Http::assertNothingSent();
    }

    public function test_apple_android_callback_requires_a_known_state_and_targets_only_the_app_package(): void
    {
        $state = str_repeat('a', 64);
        $this->post('/auth/apple/callback', ['state' => $state, 'code' => 'test-code', 'id_token' => 'test-id-token'])->assertUnprocessable();
        \Illuminate\Support\Facades\Cache::put('apple-nonce:'.$state, true, 300);
        $response = $this->post('/auth/apple/callback', ['state' => $state, 'code' => 'test-code', 'id_token' => 'test-id-token',
            'redirect_uri' => 'https://attacker.example'])->assertStatus(303)->assertHeader('Cache-Control', 'no-store, private');
        $this->assertStringContainsString('package=com.senmiydin.app;scheme=signinwithapple;end', $response->headers->get('Location'));
        $this->assertStringNotContainsString('attacker.example', $response->headers->get('Location'));
    }

    public function test_apple_code_exchange_nonce_replay_and_erasure_revocation_are_connected(): void
    {
        $opensslConfig = tempnam(sys_get_temp_dir(), 'senmiydin-test-config-');
        file_put_contents($opensslConfig, "[req]\ndistinguished_name=dn\n[dn]\n");
        $resource = openssl_pkey_new(['config' => $opensslConfig, 'private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_EC, 'curve_name' => 'prime256v1']);
        $private = '';
        openssl_pkey_export($resource, $private, null, ['config' => $opensslConfig]);
        unlink($opensslConfig);
        $keyPath = tempnam(sys_get_temp_dir(), 'senmiydin-test-apple-');
        file_put_contents($keyPath, $private);
        $this->beforeApplicationDestroyed(fn () => unlink($keyPath));
        config(['social.apple.audiences' => ['com.senmiydin.app'], 'social.apple.team_id' => 'TESTTEAM',
            'social.apple.key_id' => 'TESTKEY', 'social.apple.private_key_path' => $keyPath]);
        $details = openssl_pkey_get_details(openssl_pkey_get_private($this->key));
        $encode = fn ($value) => rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
        Http::fake(['https://appleid.apple.com/auth/keys' => Http::response(['keys' => [[
            'kty' => 'RSA', 'alg' => 'RS256', 'kid' => 'test-key',
            'n' => $encode($details['rsa']['n']), 'e' => $encode($details['rsa']['e']),
        ]]])]);
        $nonce = $this->postJson('/api/v1/auth/social/apple/challenge')->assertOk()->json('data.nonce');
        $jwt = $this->signed(['iss' => 'https://appleid.apple.com', 'aud' => 'com.senmiydin.app', 'nonce' => hash('sha256', $nonce)]);
        Http::fake([
            'https://appleid.apple.com/auth/token' => Http::response(['id_token' => $jwt, 'refresh_token' => 'test-refresh-token']),
            'https://appleid.apple.com/auth/revoke' => Http::response([], 200),
        ]);
        $fields = ['id_token' => $jwt, 'authorization_code' => 'test-code', 'nonce' => $nonce,
            'name' => 'Deniz', 'username' => 'appledeniz', 'password' => 'Account12345!', 'accepted_terms' => true,
            'city_id' => City::first()->id, 'birth_date' => '1995-01-01'];
        $token = $this->postJson('/api/v1/auth/social/apple', $fields)->assertCreated()->json('data.token');
        $identity = \Illuminate\Support\Facades\DB::table('social_identities')->first();
        $this->assertNotSame('test-refresh-token', $identity->refresh_token);
        $this->postJson('/api/v1/auth/social/apple', $fields)->assertUnprocessable();
        app('auth')->forgetGuards();
        $this->withToken($token)->deleteJson('/api/v1/auth/account', ['password' => 'Account12345!', 'confirmation' => 'SİL'])->assertOk();
        $this->assertDatabaseCount('social_identities', 0);
        $this->assertDatabaseCount('oauth_revocations', 1);
        $this->artisan('oauth:revoke-deleted')->assertSuccessful();
        $this->assertDatabaseCount('oauth_revocations', 0);
        Http::assertSent(fn ($request) => $request->url() === 'https://appleid.apple.com/auth/revoke' && $request['token'] === 'test-refresh-token');
    }
}
