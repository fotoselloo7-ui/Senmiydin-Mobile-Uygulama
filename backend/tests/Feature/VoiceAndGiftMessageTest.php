<?php

namespace Tests\Feature;

use App\Accounts\EraseAccount;
use App\Media\VoiceMessage;
use App\Models\City;
use App\Models\Gift;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\Support\FakeMedia;
use Tests\TestCase;

/** Voice messages and free virtual gifts inside direct chats. */
class VoiceAndGiftMessageTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private User $demo;

    private User $elif;

    private User $third;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Carbon::setTestNow(Carbon::parse('2026-11-15 12:00:00', 'UTC'));
        $city = City::where('slug', 'alanya')->value('id');
        $make = fn (string $name, string $birth = '1995-01-01') => User::create(['name' => ucfirst($name), 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => $birth, 'password' => 'TestPassword1234', 'city_id' => $city]);
        $this->demo = $make('demo');
        $this->elif = $make('elif');
        $this->third = $make('third');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function as(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    /** An accepted chat Demo ⇄ Elif so voice/gift messages are plain "message" notifications. */
    private function openChat(): int
    {
        $this->as($this->demo)->postJson('/api/v1/users/'.$this->elif->id.'/messages', ['body' => 'Selam', 'request_id' => (string) Str::uuid()])->assertCreated();
        $id = (int) DB::table('conversations')->value('id');
        $this->as($this->elif)->postJson("/api/v1/conversations/$id/request/accept")->assertSuccessful();

        return $id;
    }

    private function voice(?User $from = null, ?User $to = null, ?string $bytes = null, string $name = 'rec.m4a', array $extra = [])
    {
        $from ??= $this->demo;
        $to ??= $this->elif;
        $file = UploadedFile::fake()->createWithContent($name, $bytes ?? FakeMedia::m4a());

        return $this->as($from)->post('/api/v1/users/'.$to->id.'/messages', ['request_id' => (string) Str::uuid(), 'audio' => $file, ...$extra], ['Accept' => 'application/json']);
    }

    // ------------------------------------------------------------------------------------------------- voice

    public function test_a_voice_message_is_stored_privately_and_described_by_its_own_header(): void
    {
        $this->openChat();
        $message = $this->voice(bytes: FakeMedia::m4a(12_340), name: 'whatever.php')->assertCreated()
            ->assertJsonPath('data.message.type', 'voice')->assertJsonPath('data.message.duration_ms', 12340)->json('data.message');
        $this->assertSame('', $message['body']);
        $row = DB::table('messages')->find($message['id']);
        $this->assertMatchesRegularExpression('#^voice/[0-9a-f-]{36}\.m4a$#', $row->audio_path, 'Random name; the client file name is ignored.');
        $this->assertSame(12340, (int) $row->audio_duration_ms);
        Storage::disk('local')->assertExists($row->audio_path);
        $this->assertStringNotContainsString('.php', $row->audio_path);
        $this->assertArrayNotHasKey('audio_path', $message);
        $this->assertStringStartsWith('/api/v1/message-audio/', $message['audio']);
    }

    public function test_the_other_person_can_download_it_nobody_else_can_and_a_sender_deleted_copy_is_hidden_from_the_sender_only(): void
    {
        $this->openChat();
        $message = $this->voice()->assertCreated()->json('data.message');
        $response = $this->as($this->elif)->get($message['audio'])->assertOk()->assertHeader('Content-Type', 'audio/mp4');
        $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
        $this->assertSame('nosniff', $response->headers->get('X-Content-Type-Options'));
        $this->as($this->demo)->get($message['audio'])->assertOk();
        $this->as($this->third)->get($message['audio'])->assertNotFound();
        $this->flushHeaders();
        $this->app['auth']->forgetGuards();
        $this->getJson($message['audio'])->assertUnauthorized();
        $this->app['auth']->forgetGuards();

        $conversation = DB::table('messages')->find($message['id'])->conversation_id;
        $this->as($this->demo)->deleteJson("/api/v1/conversations/$conversation/messages/".$message['id'])->assertOk();
        $this->as($this->demo)->get($message['audio'])->assertNotFound();
        $this->as($this->elif)->get($message['audio'])->assertOk();
        $this->as($this->third)->getJson("/api/v1/conversations/$conversation/messages")->assertNotFound();
    }

    public function test_invalid_oversized_short_long_and_disguised_uploads_are_rejected(): void
    {
        $this->openChat();
        $this->voice(bytes: random_bytes(2000), name: 'x.m4a')->assertUnprocessable()->assertJsonValidationErrors('audio');
        $this->voice(bytes: 'RIFF'.str_repeat("\0", 200).'WAVEfmt ', name: 'x.m4a')->assertUnprocessable();
        $this->voice(bytes: FakeMedia::m4a(10_000, 'qt  '), name: 'quicktime.m4a')->assertUnprocessable();
        $this->voice(bytes: FakeMedia::m4a(10_000, 'M4A ', false), name: 'no-aac.m4a')->assertUnprocessable();
        $this->voice(bytes: FakeMedia::m4a(400), name: 'short.m4a')->assertUnprocessable()->assertJsonValidationErrors('audio');
        $this->voice(bytes: FakeMedia::m4a(0), name: 'silent.m4a')->assertUnprocessable();
        $this->voice(bytes: FakeMedia::m4a(125_000), name: 'long.m4a')->assertUnprocessable();
        $this->voice(bytes: FakeMedia::m4a(10_000, padding: 3 * 1024 * 1024), name: 'big.m4a')->assertUnprocessable();
        $this->voice(bytes: '<?php echo 1;', name: 'shell.php')->assertUnprocessable();
        $this->assertSame(1, DB::table('messages')->count(), 'Only the opening text message exists.');
        // The documented limit is accepted, and the client-declared duration is never trusted.
        $this->voice(bytes: FakeMedia::m4a(120_000), name: 'max.m4a', extra: ['audio_duration_ms' => 1])->assertCreated()->assertJsonPath('data.message.duration_ms', 120000);
        $this->assertSame(120, config('mobile.voice.max_seconds'));
    }

    public function test_a_voice_file_cannot_be_combined_with_text_photo_location_or_gift_and_the_header_reader_is_safe(): void
    {
        $this->openChat();
        $file = fn () => UploadedFile::fake()->createWithContent('r.m4a', FakeMedia::m4a());
        $post = fn (array $extra) => $this->as($this->demo)->post('/api/v1/users/'.$this->elif->id.'/messages', ['request_id' => (string) Str::uuid(), 'audio' => $file(), ...$extra], ['Accept' => 'application/json']);
        $post(['latitude' => 36.5, 'longitude' => 32.0])->assertUnprocessable();
        $post(['gift' => 'rose'])->assertUnprocessable();
        $this->assertNull(VoiceMessage::durationMs('not a file'));
        $this->assertNull(VoiceMessage::durationMs(str_repeat("\xFF", 64)));
        $this->assertSame(5000, VoiceMessage::durationMs(FakeMedia::m4a(5000)));
    }

    public function test_voice_messages_follow_the_normal_message_rules_blocks_teens_requests_and_notifications(): void
    {
        // First message to a stranger is a request; the file is stored and the recipient is told generically.
        $first = $this->voice()->assertCreated()->json('data.message');
        $this->assertDatabaseHas('app_notifications', ['user_id' => $this->elif->id, 'type' => 'message_request']);
        $this->as($this->elif)->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.text', 'Yeni bir mesaj isteğin var.');
        $conversation = DB::table('messages')->find($first['id'])->conversation_id;
        $this->voice()->assertStatus(409);   // a pending request is not a chat yet
        $this->as($this->elif)->postJson("/api/v1/conversations/$conversation/request/accept")->assertSuccessful();
        $this->voice()->assertCreated();
        $this->assertDatabaseHas('app_notifications', ['user_id' => $this->elif->id, 'type' => 'message']);

        // Conversation list: last message carries its type and duration, never a path.
        $item = $this->as($this->elif)->getJson('/api/v1/conversations')->json('data.items.0.last_message');
        $this->assertSame('voice', $item['type']);
        $this->assertSame(12000, $item['duration_ms']);
        $this->assertArrayNotHasKey('audio_path', $item);
        // Pagination and read receipts treat it like every other message.
        $all = $this->as($this->elif)->getJson("/api/v1/conversations/$conversation/messages")->json('data.items');
        $this->assertSame(['voice', 'voice'], array_column(array_slice($all, 0, 2), 'type'));
        $this->as($this->elif)->putJson("/api/v1/conversations/$conversation/read", ['through' => $all[0]['id']])->assertOk();
        $this->assertNotNull(DB::table('messages')->find($all[0]['id'])->read_at);

        // Block: nothing can be sent in either direction and old files stop being served.
        DB::table('user_blocks')->insert(['blocker_id' => $this->elif->id, 'blocked_id' => $this->demo->id, 'created_at' => now()]);
        $this->voice()->assertStatus(404);
        $this->as($this->elif)->get($all[0]['audio'])->assertNotFound();

        // Teen separation is the normal DM barrier.
        $teen = User::create(['name' => 'Teen', 'username' => 'teen', 'email' => 'teen@example.test', 'birth_date' => '2010-06-01', 'password' => 'TestPassword1234', 'city_id' => $this->demo->city_id]);
        $this->voice(to: $teen)->assertStatus(404);
        $this->voice(from: $teen, to: $this->third)->assertStatus(404);
    }

    public function test_an_unavailable_file_is_a_clean_404_and_account_deletion_removes_the_audio(): void
    {
        $this->openChat();
        $message = $this->voice()->assertCreated()->json('data.message');
        $path = DB::table('messages')->find($message['id'])->audio_path;
        Storage::disk('local')->delete($path);
        $this->as($this->elif)->get($message['audio'])->assertNotFound();

        $again = $this->voice()->assertCreated()->json('data.message');
        $second = DB::table('messages')->find($again['id'])->audio_path;
        Storage::disk('local')->assertExists($second);
        app(EraseAccount::class)->erase($this->demo->fresh());
        $row = DB::table('messages')->find($again['id']);
        $this->assertNull($row->audio_path);
        $this->assertNull($row->audio_duration_ms);
        $this->assertDatabaseHas('media_deletions', ['path' => $second]);
        $this->artisan('media:cleanup')->assertExitCode(0);
        Storage::disk('local')->assertMissing($second);
    }

    // -------------------------------------------------------------------------------------------------- gifts

    public function test_the_gift_catalog_is_central_localized_free_and_prepared_for_prices(): void
    {
        $turkish = $this->as($this->demo)->getJson('/api/v1/gifts')->assertOk();
        $this->assertSame(['heart', 'rose', 'coffee', 'flower', 'star', 'clover', 'cake', 'gift'], array_column($turkish->json('data.items'), 'slug'));
        $this->assertSame(['Kalp', 'Gül', 'Kahve', 'Çiçek', 'Yıldız', 'Yonca', 'Pasta', 'Hediye kutusu'], array_column($turkish->json('data.items'), 'name'));
        $this->assertSame([0], array_values(array_unique(array_column($turkish->json('data.items'), 'price_minor'))), 'Gifts are free in this release.');
        $this->demo->forceFill(['preferred_locale' => 'en'])->save();
        $english = $this->as($this->demo)->getJson('/api/v1/gifts')->json('data.items');
        $this->assertSame(['Heart', 'Rose', 'Coffee', 'Flower', 'Star', 'Clover', 'Cake', 'Gift box'], array_column($english, 'name'));
        $this->assertSame('rose', $english[1]['asset']);
        $this->flushHeaders();
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/gifts')->assertUnauthorized();
        // A deactivated gift disappears from the catalog.
        Gift::where('slug', 'cake')->update(['is_active' => false]);
        $this->assertNotContains('cake', array_column($this->as($this->demo)->getJson('/api/v1/gifts')->json('data.items'), 'slug'));
    }

    public function test_only_an_active_catalog_gift_can_be_sent_and_it_notifies_generically(): void
    {
        $this->openChat();
        $send = fn (string $gift, ?User $from = null, ?User $to = null) => $this->as($from ?? $this->demo)->postJson('/api/v1/users/'.($to ?? $this->elif)->id.'/messages', ['gift' => $gift, 'request_id' => (string) Str::uuid()]);
        $message = $send('rose')->assertCreated()->assertJsonPath('data.message.type', 'gift')->assertJsonPath('data.message.gift.slug', 'rose')
            ->assertJsonPath('data.message.gift.name', 'Gül')->json('data.message');
        $this->assertSame('', $message['body']);
        $this->assertDatabaseHas('app_notifications', ['user_id' => $this->elif->id, 'type' => 'message']);
        $this->as($this->elif)->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.text', 'Yeni bir mesajın var.');

        $send('does-not-exist')->assertUnprocessable()->assertJsonValidationErrors('gift');
        $send('<img src=x onerror=1>')->assertUnprocessable();
        $send('../../etc/passwd')->assertUnprocessable();
        Gift::where('slug', 'star')->update(['is_active' => false]);
        $send('star')->assertUnprocessable();
        $this->assertSame(2, DB::table('messages')->where('type', 'gift')->orWhere('type', 'text')->count(), 'Invalid gifts created nothing.');
        // Not combinable with text/voice/photo/location (the card is the whole message).
        $this->as($this->demo)->postJson('/api/v1/users/'.$this->elif->id.'/messages', ['gift' => 'heart', 'latitude' => 36.5, 'longitude' => 32.0, 'request_id' => (string) Str::uuid()])->assertUnprocessable();
    }

    public function test_gifts_obey_blocks_teen_separation_requests_previews_deletion_and_erasure(): void
    {
        $conversation = $this->openChat();
        $gift = fn (User $from, User $to, string $slug = 'heart') => $this->as($from)->postJson('/api/v1/users/'.$to->id.'/messages', ['gift' => $slug, 'request_id' => (string) Str::uuid()]);
        $message = $gift($this->demo, $this->elif)->assertCreated()->json('data.message');

        // Preview in the conversation list and the history.
        $last = $this->as($this->elif)->getJson('/api/v1/conversations')->json('data.items.0.last_message');
        $this->assertSame('gift', $last['type']);
        $this->assertSame('heart', $last['gift']['slug']);
        $history = $this->as($this->elif)->getJson("/api/v1/conversations/$conversation/messages")->json('data.items.0');
        $this->assertSame('gift', $history['type']);

        // A first-time gift to a stranger is a request, exactly like text.
        $request = $gift($this->third, $this->elif)->assertCreated();
        $this->assertDatabaseHas('app_notifications', ['user_id' => $this->elif->id, 'type' => 'message_request']);
        $gift($this->third, $this->elif)->assertStatus(409);

        // Teen separation and blocks use the DM barrier.
        $teen = User::create(['name' => 'Teen', 'username' => 'teen', 'email' => 'teen@example.test', 'birth_date' => '2010-06-01', 'password' => 'TestPassword1234', 'city_id' => $this->demo->city_id]);
        $gift($this->demo, $teen)->assertStatus(404);
        $gift($teen, $this->demo)->assertStatus(404);
        DB::table('user_blocks')->insert(['blocker_id' => $this->elif->id, 'blocked_id' => $this->demo->id, 'created_at' => now()]);
        $gift($this->demo, $this->elif)->assertStatus(404);
        $gift($this->elif, $this->demo)->assertStatus(404);
        DB::table('user_blocks')->delete();

        // Delete for the sender: the receiver keeps it; account erasure removes the gift reference.
        $this->as($this->demo)->deleteJson("/api/v1/conversations/$conversation/messages/".$message['id'])->assertOk();
        $this->assertNotContains($message['id'], array_column($this->as($this->demo)->getJson("/api/v1/conversations/$conversation/messages")->json('data.items'), 'id'));
        $this->assertContains($message['id'], array_column($this->as($this->elif)->getJson("/api/v1/conversations/$conversation/messages")->json('data.items'), 'id'));
        app(EraseAccount::class)->erase($this->demo->fresh());
        $this->assertNull(DB::table('messages')->find($message['id'])->gift_id);
    }

    public function test_the_gift_catalog_table_is_ready_for_a_paid_model_without_schema_changes(): void
    {
        $columns = DB::getSchemaBuilder()->getColumnListing('gifts');
        foreach (['slug', 'name_tr', 'name_en', 'asset', 'is_active', 'sort_order', 'price_minor', 'currency'] as $column) {
            $this->assertContains($column, $columns);
        }
        $this->assertSame(8, Gift::count());
        $this->assertSame(0, (int) Gift::sum('price_minor'));
    }
}
