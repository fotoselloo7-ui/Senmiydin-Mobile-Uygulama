<?php
namespace Tests\Feature;

use App\Administration\Settings;
use App\Models\Admin;
use Database\Seeders\DemoDataSeeder;
use Database\Seeders\DevelopmentAdminSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class ProductionReadinessTest extends TestCase
{
    use RefreshDatabase;
    protected $seed = true;

    private function production(): void
    {
        config(['app.url' => 'https://senmiydin.tr', 'app.debug' => true]);
        $this->app->instance('env', 'production');
        (new \App\Providers\AppServiceProvider($this->app))->boot();
    }

    public function test_production_debug_is_disabled_and_https_is_required_without_trusting_spoofed_proxy_headers(): void
    {
        $this->production();
        $this->assertFalse(config('app.debug'));
        $this->assertTrue(config('session.secure'));
        $this->assertTrue(config('session.http_only'));
        $this->get('http://senmiydin.tr/admin/login')->assertStatus(308)->assertRedirect('https://senmiydin.tr/admin/login');
        $this->withHeader('X-Forwarded-Proto', 'https')->getJson('http://senmiydin.tr/api/v1/app-config')->assertStatus(426);
        $this->get('https://attacker.example/')->assertStatus(400);
        $this->get('https://senmiydin.tr/admin/login')->assertOk()->assertHeader('Strict-Transport-Security', 'max-age=31536000');
    }

    public function test_api_failures_hide_sql_paths_and_stack_traces_even_with_debug_enabled(): void
    {
        config(['app.debug' => true]);
        Route::get('/api/secret-test', fn () => throw new \RuntimeException('SQL password=hidden C:/private/secret'));
        $response = $this->getJson('/api/secret-test')->assertStatus(500)->assertJsonPath('success', false);
        $response->assertDontSee('password=')->assertDontSee('C:/private')->assertJsonMissingPath('trace');
    }

    public function test_production_seeders_refuse_demo_users_and_administrators(): void
    {
        $this->production();
        foreach ([new DemoDataSeeder, new DevelopmentAdminSeeder] as $seeder) {
            try { $seeder->run(); $this->fail('Development seeder ran in production.'); }
            catch (\RuntimeException $error) { $this->assertStringContainsString('environment', $error->getMessage()); }
        }
        $this->assertDatabaseCount('users', 0);
        $this->assertDatabaseCount('admins', 0);
    }

    public function test_version_controls_require_real_stores_and_preserve_feature_defaults(): void
    {
        $admin = Admin::create(['name' => 'Admin', 'email' => 'admin@example.test', 'password' => 'Password123!', 'role' => 'super_admin']);
        $this->actingAs($admin, 'admin')->from('/admin/settings')->post('/admin/settings', ['android_min_version' => '1.0.0'])
            ->assertSessionHasErrors('android_min_version');
        $this->post('/admin/settings', ['android_min_version' => '0.1.0', 'android_latest_version' => '0.2.0', 'play_store_url' => 'https://play.google.com/store/apps/details?id=com.senmiydin.app'])
            ->assertSessionHasNoErrors();
        $this->getJson('/api/v1/app-config')->assertOk()->assertJsonPath('data.versions.android.minimum', '0.1.0')
            ->assertJsonPath('data.nearby_enabled', true)->assertJsonPath('data.featured_enabled', true);
        $this->post('/admin/settings', ['android_latest_version' => '0.0.1'])->assertSessionHasErrors('android_min_version');
    }

    public function test_maintenance_keeps_config_login_admin_and_legal_available(): void
    {
        app(Settings::class)->save(['maintenance_mode' => true]);
        $this->getJson('/api/v1/cities')->assertStatus(503)->assertJsonPath('unavailable', 'maintenance');
        $this->getJson('/api/v1/app-config')->assertOk()->assertJsonPath('data.maintenance', true);
        $this->postJson('/api/v1/auth/login', ['identifier' => 'unknown', 'password' => 'wrong'])->assertUnauthorized();
        $this->getJson('/api/v1/legal/gizlilik')->assertOk()->assertJsonPath('data.title', 'Gizlilik Politikası');
        $this->get('/admin/login')->assertOk();
    }

    public function test_branded_error_pages_do_not_require_database_content(): void
    {
        config(['app.debug' => false]);
        $this->get('/missing-page')->assertNotFound()->assertSee('SenMiydin?')->assertSee('Bu sayfayı bulamadık');
        Route::get('/broken-page', fn () => throw new \RuntimeException('secret'));
        $this->get('/broken-page')->assertStatus(500)->assertSee('Bir sorun oluştu')->assertDontSee('secret');
    }

    public function test_cors_only_exposes_the_configured_origin(): void
    {
        config(['cors.allowed_origins' => ['https://senmiydin.tr']]);
        $this->withHeader('Origin', 'https://attacker.example')->getJson('/api/v1/app-config')->assertHeader('Access-Control-Allow-Origin', 'https://senmiydin.tr');
        $this->withHeader('Origin', 'https://senmiydin.tr')->getJson('/api/v1/app-config')->assertHeader('Access-Control-Allow-Origin', 'https://senmiydin.tr');
    }

    public function test_production_admin_rejects_development_credentials_and_enforces_csrf(): void
    {
        Admin::create(['name' => 'Local', 'email' => 'admin@senmiydin.local', 'password' => 'Admin1234!', 'role' => 'super_admin']);
        $this->production();
        $this->post('https://senmiydin.tr/admin/login', ['email' => 'admin@senmiydin.local', 'password' => 'Admin1234!'])->assertStatus(419);
        $this->withSession(['_token' => 'test-csrf'])->post('https://senmiydin.tr/admin/login',
            ['_token' => 'test-csrf', 'email' => 'admin@senmiydin.local', 'password' => 'Admin1234!'])->assertSessionHasErrors('email');
        $this->assertGuest('admin');
    }

    public function test_only_the_configured_proxy_can_assert_https(): void
    {
        $this->production();
        config(['security.trusted_proxies' => ['127.0.0.1']]);
        $this->withServerVariables(['REMOTE_ADDR' => '127.0.0.1'])->withHeader('X-Forwarded-Proto', 'https')
            ->getJson('http://senmiydin.tr/api/v1/app-config')->assertOk();
    }
}
