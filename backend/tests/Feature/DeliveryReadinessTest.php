<?php
namespace Tests\Feature;

use App\Administration\Settings;
use App\Mail\SecurityNotice;
use App\Mail\SupportRequest;
use App\Models\City;
use App\Models\User;
use App\Notifications\Inbox;
use App\Notifications\PushDelivery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Tests\TestCase;

class DeliveryReadinessTest extends TestCase
{
    use RefreshDatabase;
    protected $seed = true;

    public function test_contact_mail_is_queued_to_configured_support_without_copying_private_form_content_into_mail(): void
    {
        Mail::fake();
        app(Settings::class)->save(['support_email' => 'support@example.test']);
        $this->post('/iletisim', ['name' => 'Deniz', 'email' => 'deniz@example.test', 'subject' => 'Soru', 'message' => 'Özel destek içeriği'])
            ->assertRedirect('/iletisim');
        Mail::assertQueued(SupportRequest::class, fn ($mail) => $mail->hasTo('support@example.test'));
        $mail = new SupportRequest(DB::table('web_requests')->value('id'));
        $this->assertStringNotContainsString('Özel destek içeriği', $mail->render());
        $this->assertInstanceOf(\Illuminate\Contracts\Queue\ShouldBeEncrypted::class, new SecurityNotice('notice'));
        $this->assertInstanceOf(\Illuminate\Contracts\Queue\ShouldBeEncrypted::class, new \App\Notifications\PasswordResetCode('test-token'));
    }

    public function test_fcm_delivery_respects_preferences_valid_sessions_and_private_token_handling(): void
    {
        Http::preventStrayRequests();
        Http::fake(['https://fcm.googleapis.com/*' => Http::response(['name' => 'sent'])]);
        config(['push.driver' => 'fcm', 'push.project' => 'test-project']);
        $user = User::create(['name' => 'Deniz', 'username' => 'deniz', 'email' => 'deniz@example.test',
            'password' => 'Account12345!', 'birth_date' => '1995-01-01', 'city_id' => City::first()->id]);
        $token = $user->createToken('mobile');
        $id = DB::table('app_notifications')->insertGetId(['user_id' => $user->id, 'actor_id' => null, 'type' => 'system', 'created_at' => now()]);
        DB::table('user_devices')->insert([
            'user_id' => $user->id, 'personal_access_token_id' => $token->accessToken->id,
            'platform' => 'android', 'device_identifier' => (string) Str::uuid(),
            'push_token' => Crypt::encryptString('test-device-token'), 'token_hash' => hash('sha256', 'test-device-token'),
            'last_seen_at' => now(), 'is_active' => true,
        ]);
        // Exercise HTTP delivery with a test-only access token; credential signing is separately configuration-gated.
        $delivery = new class extends PushDelivery {
            protected function accessToken(string $project): string { return 'test-access-token'; }
        };
        $user->forceFill(['push_preferences' => ['system' => false]])->save();
        $delivery->send($id);
        Http::assertNothingSent();
        $user->forceFill(['push_preferences' => ['system' => true]])->save();
        $delivery->send($id);
        Http::assertSent(fn ($request) => $request['message']['data']['notification_id'] === (string) $id
            && $request['message']['data']['recipient_id'] === (string) $user->id
            && $request['message']['token'] === 'test-device-token');
        $token->accessToken->forceFill(['expires_at' => now()->subMinute()])->save();
        Http::fake(['https://fcm.googleapis.com/*' => Http::response(['name' => 'sent'])]);
        $delivery->send($id);
        Http::assertNothingSent();
    }

    public function test_notification_types_route_to_existing_product_screens(): void
    {
        foreach (['message' => '/conversation', 'message_request' => '/conversation',
            'encounter_request' => '/encounter', 'encounter_accepted' => '/encounter', 'encounter_story' => '/encounter',
            'like' => '/post', 'comment' => '/comments', 'follow' => '/profile', 'nearby_activity' => '/post', 'system' => '/notifications'] as $type => $route) {
            $this->assertSame($route, Inbox::TYPES[$type][0]);
        }
    }

    public function test_production_password_reset_cannot_log_the_secret_code(): void
    {
        $this->app->instance('env', 'production');
        config(['mail.default' => 'log']);
        $user = new User(['name' => 'Deniz', 'email' => 'deniz@example.test']);
        try {
            $user->sendPasswordResetNotification('private-reset-code');
            $this->fail('Production reset code was sent to the log mailer.');
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $error) {
            $this->assertSame(503, $error->getStatusCode());
        }
    }
}
