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

    /**
     * The automated audit: every Turkish sentence the mobile API code can send has an English text, either as an
     * exact entry or through a pattern. A new untranslated sentence fails here, not on a user's screen.
     */
    public function test_every_sentence_the_api_can_send_has_an_english_text(): void
    {
        app()->setLocale('en');
        $missing = [];
        foreach (\Tests\Support\ApiSentences::all() as $sentence => $file) {
            // Inbox texts live in lang/{tr,en}/inbox.php; these two files only raise internal English errors.
            if (in_array($file, ['Inbox.php', 'AppleTokens.php', 'PushDelivery.php'], true)) {
                continue;
            }
            // A fragment of a sentence built with a number ("En fazla 4 fotoğraf ekleyebilirsin.") is checked below as a whole.
            if (str_starts_with($sentence, ' ') || ! preg_match('/[çğıöşüÇĞİÖŞÜâî]|^[A-ZÇĞİÖŞÜ][a-zçğıöşü]+ /u', $sentence)) {
                continue;
            }
            if (\App\Http\ApiResponse::localize($sentence) === $sentence && preg_match('/[çğıöşüÇĞİÖŞÜ]/u', $sentence)) {
                $missing[] = "$file: $sentence";
            }
        }
        $this->assertSame([], $missing);
        foreach ([
            'En fazla 4 fotoğraf ekleyebilirsin.' => 'You can add up to 4 photos.',
            'En fazla 20 koleksiyon oluşturabilirsin.' => 'You can create up to 20 collections.',
            'Koleksiyon adı en fazla 40 karakter olabilir.' => 'A collection name can be up to 40 characters.',
            'Notun en fazla 700 karakter olabilir.' => 'Your note can be up to 700 characters.',
            'Yanıtın en fazla 500 karakter olabilir.' => 'Your reply can be up to 500 characters.',
            'Alanya · Yaklaşık bölge' => 'Alanya · Approximate area',
        ] as $turkish => $english) {
            $this->assertSame($english, \App\Http\ApiResponse::localize($turkish));
        }
        app()->setLocale('tr');
        $this->assertSame('Alanya · Yaklaşık bölge', \App\Http\ApiResponse::localize('Alanya · Yaklaşık bölge'));
    }

    public function test_a_field_error_without_a_written_message_is_never_an_english_sentence_in_a_turkish_app(): void
    {
        $turkish = $this->withHeader('Accept-Language', 'tr')->getJson('/api/v1/places/search')->assertUnprocessable()->json('errors.q.0');
        $this->assertSame('Bu bilgi geçerli değil. Kontrol edip tekrar dene.', $turkish);
        $english = $this->withHeader('Accept-Language', 'en')->getJson('/api/v1/places/search')->assertUnprocessable()->json('errors.q.0');
        $this->assertDoesNotMatchRegularExpression('/[çğıöşüÇĞİÖŞÜ]/u', $english);
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
