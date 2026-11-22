<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\User;
use App\Notifications\Inbox;
use App\Notifications\PushDelivery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class CommunicationApiTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;
    private User $demo;
    private User $elif;
    private User $third;
    private int $city;

    protected function setUp(): void
    {
        parent::setUp();
        $this->city = City::where('slug', 'alanya')->value('id');
        $this->demo = $this->user('deniz');
        $this->elif = $this->user('elif');
        $this->third = $this->user('ece');
    }

    public function test_first_message_creates_a_unique_request_and_only_the_recipient_accepts(): void
    {
        $fields = ['body' => 'Merhaba', 'request_id' => (string) Str::uuid()];
        $path = '/api/v1/users/'.$this->elif->id.'/messages';
        $id = $this->asUser($this->demo)->postJson($path, $fields)->assertCreated()
            ->assertJsonPath('data.conversation.status', 'pending')->json('data.conversation.id');
        $this->postJson($path, $fields)->assertOk()->assertJsonPath('data.conversation.id', $id);
        $this->postJson($path, [...$fields, 'request_id' => (string) Str::uuid()])->assertConflict();
        $this->assertDatabaseCount('conversations', 1);
        $this->assertDatabaseCount('conversation_participants', 2);
        $this->assertDatabaseCount('messages', 1);

        $chat = "/api/v1/conversations/$id";
        $this->postJson("$chat/request/accept")->assertForbidden();
        $this->asUser($this->third)->getJson($chat)->assertNotFound();
        $this->getJson("$chat/messages")->assertNotFound();
        $this->putJson("$chat/read", ['through' => 1])->assertNotFound();
        $this->asUser($this->elif)->getJson('/api/v1/conversations?requests=1')
            ->assertJsonPath('data.items.0.id', $id)->assertJsonPath('data.items.0.outgoing', false)
            ->assertJsonPath('data.items.0.unread', 1)->assertJsonPath('data.items.0.last_message.body', 'Merhaba');
        $this->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.type', 'message_request');
        // the stranger's first message is also counted as a request waiting in "İstekler" (the sender never has one)
        $this->getJson('/api/v1/unread-counts')->assertJsonPath('data.requests', 1)->assertJsonPath('data.messages', 1);
        $this->asUser($this->demo)->getJson('/api/v1/unread-counts')->assertJsonPath('data.requests', 0);
        $this->asUser($this->elif)->postJson("$chat/request/accept")->assertOk()->assertJsonPath('data.status', 'active');
        $this->getJson('/api/v1/unread-counts')->assertJsonPath('data.requests', 0);
        $this->postJson("$chat/request/accept")->assertOk();
        $this->getJson('/api/v1/conversations?requests=0')->assertJsonPath('data.items.0.id', $id);
        $this->assertDatabaseCount('conversations', 1);
    }

    public function test_rejected_request_cannot_be_reopened_and_message_privacy_is_enforced(): void
    {
        $this->asUser($this->elif)->putJson('/api/v1/profile', ['message_privacy' => 'following'])
            ->assertOk()->assertJsonPath('data.message_privacy', 'following');
        $path = '/api/v1/users/'.$this->elif->id.'/messages';
        $fields = ['body' => 'Selam', 'request_id' => (string) Str::uuid()];
        $this->asUser($this->demo)->postJson($path, $fields)->assertForbidden();
        $this->asUser($this->elif)->postJson('/api/v1/users/deniz/follow')->assertOk();
        $id = $this->asUser($this->demo)->postJson($path, $fields)->assertCreated()->json('data.conversation.id');
        $this->asUser($this->elif)->postJson("/api/v1/conversations/$id/request/reject")
            ->assertOk()->assertJsonPath('data.status', 'rejected');
        $this->postJson("/api/v1/conversations/$id/request/accept")->assertConflict();
        $this->asUser($this->demo)->postJson($path, [...$fields, 'request_id' => (string) Str::uuid()])->assertConflict();
        $this->assertDatabaseCount('messages', 1);
        $this->travel(25)->hours();
        $this->postJson($path, [...$fields, 'request_id' => (string) Str::uuid()])->assertCreated()
            ->assertJsonPath('data.conversation.id', $id)->assertJsonPath('data.conversation.status', 'pending');
        $this->assertDatabaseCount('conversations', 1);
    }

    public function test_read_receipts_unread_counts_and_hiding_are_scoped_to_the_member(): void
    {
        $id = $this->activeChat();
        $chat = "/api/v1/conversations/$id";
        $incoming = $this->send($this->elif, $this->demo, 'Sahilde görüşelim')->json('data.message.id');
        $this->asUser($this->demo)->getJson('/api/v1/unread-counts')->assertJsonPath('data.messages', 1);
        $this->getJson("$chat/messages")->assertJsonPath('data.items.0.body', 'Sahilde görüşelim')
            ->assertJsonPath('data.items.0.read_at', null)->assertJsonPath('data.items.0.request_id', null);
        $this->putJson("$chat/read", ['through' => $incoming])->assertOk();
        $this->getJson('/api/v1/unread-counts')->assertJsonPath('data.messages', 0);
        $this->deleteJson($chat)->assertOk();
        $this->getJson('/api/v1/conversations')->assertJsonCount(0, 'data.items');

        $this->asUser($this->elif)->getJson("$chat/messages")->assertJsonPath('data.items.0.id', $incoming)
            ->assertJsonPath('data.items.0.mine', true)->assertJsonPath('data.items.0.read_at', fn ($time) => $time !== null);
        $this->getJson('/api/v1/conversations')->assertJsonCount(1, 'data.items');
        $this->send($this->elif, $this->demo, 'Akşam uygun mu?');
        $this->asUser($this->demo)->getJson('/api/v1/conversations?q=elif')->assertJsonPath('data.items.0.id', $id);
        $this->getJson("$chat/messages?before=$incoming")->assertJsonCount(1, 'data.items');
    }

    public function test_message_image_is_validated_and_private_and_senders_can_hide_their_copy(): void
    {
        Storage::fake(config('mobile.post_media_disk'));
        $id = $this->activeChat();
        $path = '/api/v1/users/'.$this->elif->id.'/messages';
        $this->asUser($this->demo)->postJson($path, [
            'request_id' => (string) Str::uuid(), 'image' => UploadedFile::fake()->create('wrong.jpg', 10, 'image/jpeg'),
        ])->assertUnprocessable();
        $data = $this->postJson($path, [
            'request_id' => (string) Str::uuid(), 'image' => UploadedFile::fake()->image('sahil.png', 40, 40),
        ])->assertCreated()->assertJsonPath('data.message.type', 'image')->json('data.message');
        $this->asUser($this->third)->get($data['image'])->assertNotFound();
        $this->asUser($this->elif)->get($data['image'])->assertOk()->assertHeader('Content-Type', 'image/jpeg');
        $item = "/api/v1/conversations/$id/messages/".$data['id'];
        $this->deleteJson("$item?scope=everyone")->assertForbidden();
        $this->asUser($this->demo)->deleteJson($item)->assertOk();
        $this->get($data['image'])->assertNotFound();
        $this->asUser($this->elif)->get($data['image'])->assertOk();
        $this->assertDatabaseHas('messages', ['id' => $data['id'], 'type' => 'image']);
    }

    public function test_block_also_filters_notifications_conversations_unread_counts_and_unblock_restores_normal_behaviour(): void
    {
        // elif interacts with deniz: follow + message request + like, all producing notifications for deniz.
        $post = $this->publish($this->demo);
        $this->asUser($this->elif)->postJson('/api/v1/users/deniz/follow')->assertOk();
        $this->postJson('/api/v1/posts/'.$post['id'].'/like')->assertOk();
        $chat = $this->send($this->elif, $this->demo, 'Merhaba')->json('data.conversation.id');

        $this->asUser($this->demo)->postJson('/api/v1/conversations/'.$chat.'/request/accept')->assertOk();
        $before = $this->getJson('/api/v1/notifications')->assertOk()->json('data.items');
        $this->assertGreaterThanOrEqual(3, count($before));
        $this->getJson('/api/v1/conversations')->assertJsonCount(1, 'data.items');
        $unreadBefore = $this->getJson('/api/v1/unread-counts')->json('data');
        $this->assertGreaterThan(0, $unreadBefore['notifications'] + $unreadBefore['messages']);

        $this->putJson('/api/v1/blocks/'.$this->elif->id)->assertOk();
        $this->getJson('/api/v1/notifications')->assertOk()->assertJsonCount(0, 'data.items');
        $this->getJson('/api/v1/conversations')->assertOk()->assertJsonCount(0, 'data.items');
        $this->getJson('/api/v1/conversations/'.$chat)->assertNotFound();
        $this->getJson('/api/v1/unread-counts')->assertJsonPath('data.notifications', 0)->assertJsonPath('data.messages', 0);
        // The blocked account cannot raise new notifications for the blocker either.
        $this->asUser($this->elif)->postJson('/api/v1/posts/'.$post['id'].'/like')->assertNotFound();

        // Blocking purges the old interaction records; unblocking restores normal behaviour for new ones only.
        $this->assertDatabaseCount('app_notifications', 0);
        $this->asUser($this->demo)->deleteJson('/api/v1/blocks/'.$this->elif->id)->assertOk();
        $this->getJson('/api/v1/notifications')->assertOk()->assertJsonCount(0, 'data.items');
        $this->asUser($this->elif)->postJson('/api/v1/users/deniz/follow')->assertOk();
        $this->asUser($this->demo)->getJson('/api/v1/notifications')->assertOk()->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.type', 'follow');
    }

    public function test_block_hides_profiles_search_nearby_feed_and_cancels_pending_requests(): void
    {
        $this->asUser($this->demo)->postJson('/api/v1/users/elif/follow')->assertOk();
        $this->asUser($this->elif)->postJson('/api/v1/users/deniz/follow')->assertOk();
        $post = $this->publish($this->elif);
        $tagged = $this->publish($this->demo, ['type' => 'encounter', 'encounter_target_id' => $this->elif->id]);
        $chat = $this->send($this->demo, $this->elif, 'Merhaba')->json('data.conversation.id');
        foreach ([$this->demo, $this->elif] as $user) {
            $this->asUser($user)->putJson('/api/v1/location', ['latitude' => 36.544, 'longitude' => 32, 'accuracy' => 25])->assertOk();
        }
        $this->asUser($this->demo)->getJson('/api/v1/nearby/users')->assertJsonCount(1, 'data.items');
        $this->putJson('/api/v1/blocks/'.$this->elif->id)->assertOk();
        $this->getJson('/api/v1/blocks')->assertJsonPath('data.items.0.username', 'elif');
        $this->getJson('/api/v1/users/elif')->assertNotFound();
        $this->getJson('/api/v1/search?type=users&q=elif')->assertJsonCount(0, 'data.items');
        $this->getJson('/api/v1/nearby/users')->assertJsonCount(0, 'data.items');
        $this->getJson('/api/v1/posts/'.$post['id'])->assertNotFound();
        $feed = $this->getJson('/api/v1/feed')->assertOk()->json('data.items');
        $this->assertNotContains($post['id'], array_column($feed, 'id'));
        $this->postJson('/api/v1/posts', $this->draft(['type' => 'encounter', 'encounter_target_id' => $this->elif->id]))->assertUnprocessable();
        $this->asUser($this->elif)->postJson('/api/v1/users/'.$this->demo->id.'/messages', [
            'body' => 'Merhaba', 'request_id' => (string) Str::uuid(),
        ])->assertNotFound();
        $this->getJson('/api/v1/encounter-requests')->assertJsonCount(0, 'data.items');
        $this->assertDatabaseHas('conversations', ['id' => $chat, 'status' => 'cancelled']);
        $this->assertDatabaseHas('encounter_requests', ['id' => $tagged['encounter_request_id'], 'status' => 'cancelled']);
        $this->assertDatabaseCount('user_follows', 0);

        $this->asUser($this->demo)->deleteJson('/api/v1/blocks/'.$this->elif->id)->assertOk();
        $this->getJson('/api/v1/blocks')->assertJsonCount(0, 'data.items');
        $this->getJson('/api/v1/search?type=users&q=elif')->assertJsonPath('data.items.0.username', 'elif');
        $this->assertDatabaseCount('user_follows', 0);
    }

    public function test_notifications_are_real_authorized_and_can_be_read_individually_or_all_at_once(): void
    {
        $post = $this->publish($this->elif)['id'];
        $this->postJson("/api/v1/posts/$post/like")->assertOk();
        $this->asUser($this->demo)->postJson("/api/v1/posts/$post/like")->assertOk();
        $this->postJson("/api/v1/posts/$post/like")->assertOk();
        $this->postJson("/api/v1/posts/$post/comments", ['body' => 'Güzel bir anı'])->assertCreated();
        $this->postJson('/api/v1/users/elif/follow')->assertOk();
        $tag = $this->publish($this->demo, ['type' => 'encounter', 'encounter_target_id' => $this->elif->id]);

        $page = $this->asUser($this->elif)->getJson('/api/v1/notifications')->assertJsonCount(4, 'data.items')->json('data.items');
        $this->assertEquals(['encounter_request', 'follow', 'comment', 'like'], array_column($page, 'type'));
        $this->assertEquals($tag['encounter_request_id'], $page[0]['entity_id']);
        $notice = '/api/v1/notifications/'.$page[0]['id'];
        $this->getJson($notice)->assertJsonPath('data.actor.username', 'deniz');
        $this->putJson("$notice/read")->assertOk();
        $this->getJson('/api/v1/notifications?unread=1')->assertJsonCount(3, 'data.items');
        $this->asUser($this->third)->putJson("$notice/read")->assertNotFound();
        $this->asUser($this->elif)->putJson('/api/v1/notifications/read')->assertOk();
        $this->getJson('/api/v1/unread-counts')->assertJsonPath('data.notifications', 0);
        $invitation = $tag['encounter_request_id'];
        $encounter = $this->postJson("/api/v1/encounter-requests/$invitation/accept")->assertOk()->json('data.encounter_id');
        $this->asUser($this->demo)->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.type', 'encounter_accepted');
        $this->publish($this->demo, ['type' => 'encounter', 'encounter_id' => $encounter, 'story_title' => 'Sahilde yeniden']);
        $this->asUser($this->elif)->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.type', 'encounter_story_approval');
        $this->postJson("/api/v1/encounters/$encounter/story/approve", ['revision' => 1])->assertOk();
        $this->asUser($this->demo)->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.type', 'encounter_story_published');
    }

    public function test_reports_preserve_references_and_deduplicate_without_exposing_private_messages(): void
    {
        $id = $this->activeChat();
        $message = $this->send($this->elif, $this->demo, 'Bir mesaj')->json('data.message.id');
        $this->deleteJson("/api/v1/conversations/$id/messages/$message")->assertOk();
        $post = $this->publish($this->elif)['id'];
        $comment = $this->postJson("/api/v1/posts/$post/comments", ['body' => 'Bir yorum'])->assertCreated()->json('data.id');
        $this->asUser($this->third)->postJson('/api/v1/reports', [
            'target_type' => 'message', 'target_id' => $message, 'reason' => 'spam',
        ])->assertNotFound();

        $this->asUser($this->demo);
        foreach (['user' => $this->elif->id, 'post' => $post, 'comment' => $comment, 'message' => $message] as $type => $target) {
            $fields = ['target_type' => $type, 'target_id' => $target, 'reason' => 'spam'];
            $this->postJson('/api/v1/reports', $fields)->assertCreated();
            $this->postJson('/api/v1/reports', $fields)->assertOk();
        }
        $this->assertDatabaseCount('reports', 4);
        $this->assertDatabaseHas('reports', ['target_type' => 'message', 'target_id' => $message, 'status' => 'pending']);
    }

    public function test_a_sender_can_take_a_message_back_and_a_receiver_can_remove_it_from_their_own_view(): void
    {
        $id = $this->activeChat();
        $mine = $this->send($this->demo, $this->elif, 'Yanlış kişiye yazdım')->json('data.message.id');
        $theirs = $this->send($this->elif, $this->demo, 'Bu bir cevap')->json('data.message.id');
        $ids = fn (User $who) => collect($this->asUser($who)->getJson("/api/v1/conversations/$id/messages")->assertOk()->json('data.items'))->pluck('id')->all();
        $this->assertContains($mine, $ids($this->elif));

        // The receiver can only remove it from their own view; it stays for the sender, and they cannot take it back for everyone.
        $this->asUser($this->elif)->deleteJson("/api/v1/conversations/$id/messages/$mine?scope=everyone")->assertForbidden();
        $this->asUser($this->elif)->deleteJson("/api/v1/conversations/$id/messages/$mine")->assertOk();
        $this->assertNotContains($mine, $ids($this->elif));
        $this->assertContains($mine, $ids($this->demo));

        // The sender takes a message back for everyone: neither side sees it afterwards.
        $this->asUser($this->demo)->deleteJson("/api/v1/conversations/$id/messages/$theirs?scope=everyone")->assertForbidden();
        $own = $this->send($this->demo, $this->elif, 'Bunu geri alıyorum')->json('data.message.id');
        $this->assertContains($own, $ids($this->elif));
        $this->asUser($this->demo)->deleteJson("/api/v1/conversations/$id/messages/$own?scope=everyone")->assertOk();
        $this->assertNotContains($own, $ids($this->elif));
        $this->assertNotContains($own, $ids($this->demo));
        $this->assertNotNull(\App\Models\Message::find($own)->recalled_at);
        // A recalled message is never counted as unread.
        $this->assertDatabaseHas('messages', ['id' => $own, 'sender_id' => $this->demo->id]);
        $this->asUser($this->elif)->getJson('/api/v1/unread-counts')->assertOk();
    }

    public function test_device_registration_push_preferences_and_logout(): void
    {
        config(['push.driver' => 'log']);
        $device = (string) Str::uuid();
        $this->asUser($this->elif)->putJson('/api/v1/push-device', [
            'device_identifier' => $device, 'platform' => 'android', 'push_token' => 'local-verification-device-token',
        ])->assertOk();
        $this->assertDatabaseHas('user_devices', ['device_identifier' => $device, 'is_active' => true]);
        $this->assertDatabaseMissing('user_devices', ['push_token' => 'local-verification-device-token']);
        $this->putJson('/api/v1/profile', ['push_preferences' => ['message' => false]])
            ->assertJsonPath('data.push_preferences.message', false)->assertJsonPath('data.push_preferences.like', true);
        Inbox::add($this->elif->id, $this->demo->id, 'message', 99);
        $this->assertDatabaseMissing('app_notifications', ['user_id' => $this->elif->id, 'type' => 'message']);
        Inbox::add($this->elif->id, $this->demo->id, 'follow', $this->demo->id);
        Inbox::add($this->elif->id, $this->demo->id, 'like', 42);
        $this->putJson('/api/v1/profile', ['push_preferences' => ['follow' => false]])
            ->assertJsonPath('data.push_preferences.follow', false);
        Log::spy();
        $items = DB::table('app_notifications')->pluck('id', 'type');
        app(PushDelivery::class)->send($items['follow']);
        Log::shouldNotHaveReceived('info');
        app(PushDelivery::class)->send($items['like']);
        Log::shouldHaveReceived('info')->once()->withArgs(fn ($text, $payload) =>
            $text === 'Push notification' && $payload['data']['route'] === '/post' && $payload['data']['entity_id'] === '42');
        $this->getJson('/api/v1/notifications')->assertJsonCount(2, 'data.items')
            ->assertJsonPath('data.items.0.available', false)
            ->assertJsonPath('data.items.1.available', true);
        $this->postJson('/api/v1/auth/logout')->assertOk();
        $this->assertDatabaseHas('user_devices', ['device_identifier' => $device, 'is_active' => false, 'personal_access_token_id' => null]);
    }

    private function user(string $name): User
    {
        return User::create(['username' => $name, 'name' => ucfirst($name), 'email' => $name.'@example.test',
            'password' => 'Demo1234!', 'birth_date' => '1998-05-12', 'city_id' => $this->city, 'nearby_visible' => true]);
    }

    private function asUser(User $user): static
    {
        $this->app['auth']->forgetGuards();
        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    private function send(User $from, User $to, string $body)
    {
        return $this->asUser($from)->postJson('/api/v1/users/'.$to->id.'/messages', [
            'body' => $body, 'request_id' => (string) Str::uuid(),
        ])->assertCreated();
    }

    private function activeChat(): int
    {
        $id = $this->send($this->demo, $this->elif, 'Selam')->json('data.conversation.id');
        $this->asUser($this->elif)->postJson("/api/v1/conversations/$id/request/accept")->assertOk();
        return $id;
    }

    private function draft(array $extra): array
    {
        return [...['type' => 'moment', 'city_id' => $this->city, 'body' => 'Sahilden bir anı.',
            'request_id' => (string) Str::uuid(), 'visibility' => 'city', 'is_anonymous' => false], ...$extra];
    }

    private function publish(User $user, array $extra = []): array
    {
        return $this->asUser($user)->postJson('/api/v1/posts', $this->draft($extra))->assertCreated()->json('data');
    }
}
