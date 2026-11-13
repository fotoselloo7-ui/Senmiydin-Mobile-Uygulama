<?php

namespace Tests\Feature;

use App\Administration\Announcements;
use App\Models\Admin;
use App\Models\City;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\User;
use Database\Seeders\DevelopmentAdminSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class AdministrationTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private Admin $admin;
    private User $user;
    private User $peer;
    private int $city;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = Admin::create(['name' => 'Yönetici', 'email' => 'admin@example.test', 'password' => 'Secret1234!', 'role' => 'super_admin']);
        $this->city = City::where('slug', 'alanya')->value('id');
        $this->user = $this->makeUser('deniz');
        $this->peer = $this->makeUser('elif');
    }

    public function test_admin_signs_in_through_an_independent_session(): void
    {
        $this->get('/admin')->assertRedirect('/admin/login');
        $this->get('/admin/login')->assertOk()->assertSee('Yönetici girişi');
        $this->post('/admin/login', ['email' => $this->admin->email, 'password' => 'Secret1234!'])->assertRedirect('/admin');
        $this->assertAuthenticatedAs($this->admin, 'admin');
        $this->assertGuest('web');
        $this->get('/admin')->assertOk()->assertSee('Genel bakış')->assertSee('Toplam kullanıcı');
        $this->post('/admin/logout')->assertRedirect('/admin/login');
        $this->assertGuest('admin');
    }

    public function test_mobile_accounts_and_moderators_cannot_gain_system_access(): void
    {
        $token = $this->user->createToken('mobile')->plainTextToken;
        $this->withToken($token)->get('/admin/users')->assertRedirect('/admin/login');
        $this->from('/admin/login')->post('/admin/login', ['email' => $this->user->email, 'password' => 'Member123!'])
            ->assertSessionHasErrors('email');
        $this->assertGuest('admin');
        $moderator = Admin::create(['name' => 'Moderatör', 'email' => 'moderator@example.test', 'password' => 'Secret1234!', 'role' => 'moderator']);
        $this->actingAs($moderator, 'admin')->get('/admin/users')->assertOk();
        $this->get('/admin/audit')->assertForbidden();
        $this->get('/admin/settings')->assertForbidden();
        $this->post('/admin/settings', ['maintenance_mode' => true])->assertForbidden();
        $this->assertDatabaseCount('system_settings', 0);
    }

    public function test_development_seed_is_guarded(): void
    {
        $this->assertDatabaseMissing('admins', ['email' => 'admin@senmiydin.local']);
        $this->expectException(\RuntimeException::class);
        $this->seed(DevelopmentAdminSeeder::class);
    }

    public function test_users_can_be_filtered_suspended_banned_and_restored_with_audit(): void
    {
        $id = $this->user->id;
        $this->user->createToken('phone');
        $this->actingAs($this->admin, 'admin')->get('/admin/users?q=deniz')->assertOk()
            ->assertSee('deniz@example.test')->assertDontSee('elif@example.test');
        $this->get("/admin/users/$id")->assertOk()->assertSee('deniz@example.test')->assertDontSee('Member123!');
        foreach (['suspend' => 'suspended', 'ban' => 'banned', 'restore' => 'active'] as $action => $state) {
            $this->from("/admin/users/$id")->post("/admin/users/$id", ['action' => $action, 'note' => 'İnceleme'])
                ->assertRedirect("/admin/users/$id");
            $this->assertDatabaseHas('users', ['id' => $id, 'account_status' => $state]);
            $this->assertDatabaseHas('admin_audit_logs', ['admin_id' => $this->admin->id, 'target_id' => $id, 'action' => 'user.'.$action]);
        }
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->get("/admin/users/$id")->assertOk()->assertSee('Moderasyon geçmişi')->assertSee('Kullanıcı · askıya alındı');
        DB::table('user_blocks')->insert(['blocker_id' => $this->user->id, 'blocked_id' => $this->peer->id, 'created_at' => now()]);
        $this->get('/admin/blocks')->assertOk()->assertSee('@deniz')->assertSee('@elif');
        $this->get('/admin/roles')->assertOk()->assertSee('Süper yönetici');
        $this->get('/admin/modules')->assertOk()->assertSee('Mobil ana sayfa ve keşif modülleri');
        $this->get('/admin/audit')->assertOk()->assertSee('İşlem günlüğü');
    }

    public function test_post_and_comment_moderation_retains_content_and_notes(): void
    {
        $post = $this->makePost(['is_anonymous' => true]);
        $comment = $post->comments()->create(['user_id' => $this->peer->id, 'body' => 'Kıyıda yürüyüş']);
        $this->actingAs($this->admin, 'admin')->get('/admin/posts?anonymous=1')->assertOk()->assertSee($post->body);
        $this->get('/admin/posts/'.$post->id)->assertOk()->assertSee('Anonim paylaşım')->assertSee($this->user->name);
        $this->get('/admin/comments?q=yürüyüş')->assertOk()->assertSee($comment->body);
        foreach (['posts' => $post, 'comments' => $comment] as $section => $record) {
            $url = "/admin/$section/".$record->id;
            $this->from($url)->post("$url/moderate", ['action' => 'remove', 'note' => 'İçerik incelemesi'])->assertRedirect($url);
            $this->assertSoftDeleted($record);
            $this->get($url)->assertOk()->assertSee('İçerik incelemesi');
            $this->post("$url/moderate", ['action' => 'restore'])->assertRedirect($url);
            $this->assertNotSoftDeleted($record);
        }
    }

    public function test_report_review_shows_only_the_reported_message_and_can_remove_it(): void
    {
        $chat = DB::table('conversations')->insertGetId(['first_user_id' => $this->user->id, 'second_user_id' => $this->peer->id,
            'requester_id' => $this->user->id, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        foreach (['Şikâyet edilen mesaj', 'Başka özel mesaj'] as $body) {
            $ids[] = DB::table('messages')->insertGetId(['conversation_id' => $chat, 'sender_id' => $this->peer->id,
                'request_id' => (string) Str::uuid(), 'type' => 'text', 'body' => $body, 'created_at' => now(), 'updated_at' => now()]);
        }
        $id = DB::table('reports')->insertGetId(['reporter_id' => $this->user->id, 'target_type' => 'message',
            'target_id' => $ids[0], 'reason' => 'harassment', 'status' => 'pending', 'created_at' => now()]);
        $path = "/admin/reports/$id";
        $this->actingAs($this->admin, 'admin')->get('/admin/reports?type=message')->assertOk()->assertSee('Şikâyet #'.$id);
        $this->get($path)->assertOk()->assertSee('Şikâyet edilen mesaj')->assertDontSee('Başka özel mesaj');
        $this->get('/admin/messages')->assertNotFound();
        $this->from($path)->post($path, ['status' => 'reviewing'])->assertRedirect($path);
        $this->post($path, ['status' => 'resolved', 'action' => 'remove'])->assertRedirect($path);
        $this->assertDatabaseHas('reports', ['id' => $id, 'status' => 'resolved']);
        $this->assertNotNull(DB::table('messages')->find($ids[0])->moderated_at);
        $this->assertNull(DB::table('messages')->find($ids[1])->moderated_at);
        $this->assertDatabaseHas('admin_audit_logs', ['action' => 'report.resolved', 'target_id' => $id]);
    }

    public function test_featured_order_applies_to_mobile_and_archived_encounters_disappear(): void
    {
        [$request, $story] = $this->makeStory();
        [, $newer] = $this->makeStory();
        $this->actingAs($this->admin, 'admin')->get('/admin/featured')->assertOk()->assertSee($story->story_title);
        $this->from('/admin/featured')->post('/admin/featured/'.$story->id, ['rank' => 5])->assertRedirect('/admin/featured');
        $this->assertDatabaseHas('posts', ['id' => $story->id, 'featured_rank' => 5]);
        $this->withToken($this->user->createToken('app')->plainTextToken)->getJson('/api/v1/encounters/featured')
            ->assertOk()->assertJsonPath('data.items.0.id', $story->id)->assertJsonPath('data.items.1.id', $newer->id);
        $this->get('/admin/encounters/'.$request)->assertOk()->assertSee($story->story_title)->assertSee('İki taraf onayladı');
        $this->from('/admin/encounters/'.$request)->post('/admin/encounters/'.$request.'/moderate', ['action' => 'remove'])->assertRedirect();
        $this->getJson('/api/v1/encounters/featured')->assertJsonCount(1, 'data.items');
        $this->getJson('/api/v1/posts/'.$story->id)->assertNotFound();
    }

    public function test_settings_apply_maintenance_without_locking_admin_out(): void
    {
        $this->actingAs($this->admin, 'admin')->get('/admin/settings')->assertOk()->assertSee('Bakım modu');
        $this->from('/admin/settings')->post('/admin/settings', ['maintenance_mode' => true, 'maintenance_message' => 'Planlı bakım',
            'minimum_age' => 19, 'max_post_photos' => 4, 'web_cta' => 'Şehrine merhaba de', 'web_announcement' => 'Yeni bir duyuru'])->assertRedirect('/admin/settings');
        $this->getJson('/api/v1/cities')->assertStatus(503)->assertJsonPath('unavailable', 'maintenance');
        $this->getJson('/api/v1/app-config')->assertOk()->assertJsonPath('data.maintenance_message', 'Planlı bakım');
        $this->get('/admin')->assertOk();
        $this->get('/')->assertOk()->assertSee('Şehrine merhaba de')->assertSee('Planlı bakım')->assertSee('Yeni bir duyuru');
        $this->post('/admin/settings', ['maintenance_mode' => false])->assertRedirect();
        $this->getJson('/api/v1/cities')->assertOk();
        $this->assertDatabaseHas('admin_audit_logs', ['action' => 'settings.update']);
    }

    public function test_city_catalog_interest_crud_and_scheduled_announcement_targeting(): void
    {
        $this->peer->update(['city_id' => City::where('slug', 'ankara')->value('id')]);
        $this->actingAs($this->admin, 'admin')->get('/admin/interests')->assertOk()->assertSee('Hobi ekle');
        $hobby = ['name' => 'Yelken', 'sort_order' => 100, 'is_active' => true];
        $this->from('/admin/interests')->post('/admin/interests', $hobby)->assertRedirect();
        $id = DB::table('interests')->where('slug', 'yelken')->value('id');
        $this->post('/admin/interests/'.$id, [...$hobby, 'name' => 'Yelkenli', 'slug' => 'yelken', 'is_active' => false])->assertRedirect();
        $this->getJson('/api/v1/interests')->assertOk()->assertDontSee('Yelkenli');
        $this->get('/admin/cities')->assertOk()->assertSee('Alanya');
        $this->post('/admin/cities/'.$this->city, ['is_active' => false])->assertRedirect();
        $this->getJson('/api/v1/cities')->assertDontSee('Alanya');
        $this->post('/admin/cities/'.$this->city, ['is_active' => true])->assertRedirect();

        $this->get('/admin/announcements')->assertOk()->assertSee('Duyuru oluştur');
        $this->from('/admin/announcements')->post('/admin/announcements', [
            'title' => 'Alanya duyurusu', 'body' => 'Şehir etkinliği', 'city_id' => $this->city,
            'publish_at' => now('Europe/Istanbul')->addHours(2)->format('Y-m-d\TH:i'), 'send_push' => false, 'show_in_app' => true,
        ])->assertRedirect();
        $this->assertDatabaseCount('app_notifications', 0);
        $this->travel(3)->hours();
        app(Announcements::class)->run();
        app(Announcements::class)->run();
        $this->assertDatabaseCount('app_notifications', 1);
        $this->assertDatabaseHas('app_notifications', ['user_id' => $this->user->id, 'type' => 'system', 'in_app' => true]);
        $this->withToken($this->user->createToken('app')->plainTextToken)->getJson('/api/v1/app-config')
            ->assertJsonPath('data.announcement.title', 'Alanya duyurusu');
        $this->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.announcement_body', 'Şehir etkinliği')
            ->assertJsonPath('data.items.0.available', true);
        $announcementId = DB::table('announcements')->value('id');
        $this->actingAs($this->admin, 'admin')->from('/admin/announcements')
            ->post('/admin/announcements/'.$announcementId, ['is_active' => false])->assertRedirect('/admin/announcements');
        $this->withToken($this->user->createToken('app')->plainTextToken)->getJson('/api/v1/app-config')
            ->assertJsonPath('data.announcement', null);
        $this->getJson('/api/v1/notifications')->assertJsonPath('data.items.0.available', false);
    }

    public function test_store_links_reject_wrong_paths_packages_and_embedded_credentials(): void
    {
        $this->actingAs($this->admin, 'admin');
        foreach ([
            ['play_store_url', 'https://play.google.com/store/apps/details?id=com.other.app'],
            ['play_store_url', 'https://play.google.com/not-an-app?id=com.senmiydin.app'],
            ['app_store_url', 'https://apps.apple.com/not-an-app'],
            ['app_store_url', 'https://name:secret@apps.apple.com/app/id123456789'],
        ] as [$field, $url]) {
            $this->from('/admin/settings')->post('/admin/settings', [$field=>$url])
                ->assertRedirect('/admin/settings')->assertSessionHasErrors($field);
            $this->assertDatabaseCount('system_settings', 0);
        }
        // These are syntax fixtures only, never real Console account information.
        $this->from('/admin/settings')->post('/admin/settings', [
            'play_store_url'=>'https://play.google.com/store/apps/details?id=com.senmiydin.app',
            'app_store_url'=>'https://apps.apple.com/tr/app/senmiydin/id123456789',
        ])->assertRedirect('/admin/settings')->assertSessionHasNoErrors();
        $this->get('/')->assertOk()->assertSee('https://play.google.com/store/apps/details?id=com.senmiydin.app', false);
        $this->from('/admin/settings')->post('/admin/settings', ['play_store_url'=>'','app_store_url'=>''])
            ->assertRedirect('/admin/settings')->assertSessionHasNoErrors();
        $this->get('/')->assertOk()->assertSee('Yakında')->assertDontSee('href=""', false);
    }

    private function makeUser(string $handle): User
    {
        return User::create(['name' => ucfirst($handle), 'email' => $handle.'@example.test', 'username' => $handle,
            'password' => 'Member123!', 'birth_date' => '1998-01-01', 'city_id' => $this->city]);
    }

    private function makePost(array $attributes = []): Post
    {
        return Post::forceCreate(['body' => 'Sahilde bir anı', 'user_id' => $this->user->id, 'city_id' => $this->city,
            'type' => 'moment', 'visibility' => 'city', 'request_id' => (string) Str::uuid(), ...$attributes]);
    }

    private function makeStory(): array
    {
        $source = $this->makePost();
        $request = DB::table('encounter_requests')->insertGetId(['requester_id' => $this->user->id, 'target_user_id' => $this->peer->id,
            'source_post_id' => $source->id, 'status' => 'accepted', 'created_at' => now(), 'updated_at' => now()]);
        $encounter = DB::table('encounters')->insertGetId(['request_id' => $request, 'confirmed_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        return [$request, $this->makePost(['type' => 'encounter', 'encounter_id' => $encounter,
            'story_title' => 'Ortak hikâye '.$encounter, 'story_status' => 'published', 'story_revision' => 1])];
    }
}
