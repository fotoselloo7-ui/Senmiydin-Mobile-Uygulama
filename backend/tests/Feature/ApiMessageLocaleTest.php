<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Generic API sentences (404, 403, success texts, field errors) follow the request language. */
class ApiMessageLocaleTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private function user(string $locale): User
    {
        return User::create(['name' => 'Test', 'username' => 'u'.$locale, 'email' => $locale.'@example.test', 'birth_date' => '1995-01-01',
            'password' => 'TestPassword1234', 'city_id' => City::where('slug', 'alanya')->value('id'), 'preferred_locale' => $locale]);
    }

    private function as(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('t')->plainTextToken);
    }

    public function test_generic_errors_are_english_for_english_accounts_and_turkish_otherwise(): void
    {
        $english = $this->user('en');
        $turkish = $this->user('tr');
        $this->as($english)->getJson('/api/v1/posts/999999')->assertNotFound()->assertJsonPath('message', 'The record you were looking for wasn’t found.');
        $this->as($turkish)->getJson('/api/v1/posts/999999')->assertNotFound()->assertJsonPath('message', 'Aradığın kayıt bulunamadı.');
        $this->as($english)->postJson('/api/v1/users/'.$turkish->id.'/messages', ['body' => ''])->assertUnprocessable()->assertJsonPath('message', 'Please check your details.');
        $this->as($english)->postJson('/api/v1/users/ghost/follow')->assertNotFound()->assertJsonPath('message', 'The record you were looking for wasn’t found.');
    }

    public function test_unauthenticated_and_success_messages_follow_the_header_language(): void
    {
        $this->withHeader('Accept-Language', 'en')->getJson('/api/v1/profile')->assertUnauthorized()->assertJsonPath('message', 'Your session has ended. Please sign in again.');
        $this->withHeader('Accept-Language', 'tr')->getJson('/api/v1/profile')->assertUnauthorized()->assertJsonPath('message', 'Oturumun sona erdi. Tekrar giriş yap.');
        $user = $this->user('en');
        $this->as($user)->putJson('/api/v1/profile', ['name' => 'Yeni Ad'])->assertOk()->assertJsonPath('message', 'Your profile was updated.');
    }

    public function test_every_translated_message_has_a_non_empty_distinct_english_text(): void
    {
        $messages = require lang_path('en/messages.php');
        $this->assertGreaterThan(80, count($messages));
        foreach ($messages as $turkish => $english) {
            $this->assertNotSame('', trim($english), $turkish);
            $this->assertDoesNotMatchRegularExpression('/[çğıöşüÇĞİÖŞÜ]/u', $english, "Turkish letters left in: $english");
        }
    }
}
