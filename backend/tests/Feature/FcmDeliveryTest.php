<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\User;
use App\Notifications\PushDelivery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/** The real FCM HTTP v1 path (service-account JWT -> OAuth token -> message send), with Google's endpoints faked. */
class FcmDeliveryTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private string $credentials;

    protected function setUp(): void
    {
        parent::setUp();
        $options = ['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA];
        // Some Windows PHP builds need the bundled openssl.cnf to generate a key.
        $bundled = dirname(PHP_BINARY).'/extras/ssl/openssl.cnf';
        if (! file_exists((string) getenv('OPENSSL_CONF')) && file_exists($bundled)) {
            $options['config'] = $bundled;
        }
        $key = openssl_pkey_new($options);
        if ($key === false) {
            $this->markTestSkipped('OpenSSL could not generate a throwaway RSA key on this machine.');
        }
        openssl_pkey_export($key, $pem, null, $options);
        $this->credentials = tempnam(sys_get_temp_dir(), 'fcm');
        file_put_contents($this->credentials, json_encode(['project_id' => 'senmiydin-test', 'client_email' => 'push@senmiydin-test.iam.gserviceaccount.com', 'private_key' => $pem]));
        config(['push.driver' => 'fcm', 'push.project' => 'senmiydin-test', 'push.credentials' => $this->credentials]);
        Cache::flush();
    }

    protected function tearDown(): void
    {
        @unlink($this->credentials);
        parent::tearDown();
    }

    public function test_a_notification_is_sent_through_the_real_fcm_path_once(): void
    {
        $city = City::where('slug', 'alanya')->value('id');
        $user = User::create(['name' => 'Ada Test', 'username' => 'ada', 'email' => 'ada@example.test', 'birth_date' => '1995-01-01', 'password' => 'TestPassword1234', 'city_id' => $city]);
        $token = $user->createToken('device');
        DB::table('user_devices')->insert(['user_id' => $user->id, 'personal_access_token_id' => $token->accessToken->id, 'platform' => 'android',
            'device_identifier' => (string) \Illuminate\Support\Str::uuid(), 'push_token' => Crypt::encryptString('device-token'), 'token_hash' => hash('sha256', 'device-token'),
            'is_active' => true, 'last_seen_at' => now()]);
        $id = DB::table('app_notifications')->insertGetId(['user_id' => $user->id, 'type' => 'follow', 'actor_id' => null, 'entity_id' => null, 'created_at' => now()]);

        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'access-token-1', 'expires_in' => 3600]),
            'fcm.googleapis.com/*' => Http::response(['name' => 'projects/senmiydin-test/messages/1']),
        ]);

        app(PushDelivery::class)->send($id);
        app(PushDelivery::class)->send($id);

        Http::assertSentCount(2);
        Http::assertSent(fn ($request) => str_contains($request->url(), 'oauth2.googleapis.com/token')
            && $request['grant_type'] === 'urn:ietf:params:oauth:grant-type:jwt-bearer'
            && substr_count($request['assertion'], '.') === 2);
        Http::assertSent(fn ($request) => $request->url() === 'https://fcm.googleapis.com/v1/projects/senmiydin-test/messages:send'
            && $request->hasHeader('Authorization', 'Bearer access-token-1')
            && $request['message']['token'] === 'device-token'
            && $request['message']['notification']['title'] === 'SenMiydin?');
        $this->assertNotNull(DB::table('app_notifications')->where('id', $id)->value('pushed_at'), 'A delivered notification is never pushed twice.');
    }
}
