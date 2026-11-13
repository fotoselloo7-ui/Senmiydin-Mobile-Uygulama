<?php
namespace Tests\Feature;

use App\Accounts\MediaCleanup;
use App\Models\City;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class AccountDeletionTest extends TestCase
{
    use RefreshDatabase;
    protected $seed = true;

    private function user(string $name): User
    {
        return User::create(['name' => $name, 'username' => $name, 'email' => "$name@example.test",
            'password' => 'Account12345!', 'birth_date' => '1995-01-01', 'city_id' => City::first()->id,
            'nearby_visible' => true, 'location_history_enabled' => true]);
    }

    private function token(User $user): static
    {
        app('auth')->forgetGuards();
        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    public function test_erasure_requires_password_and_explicit_confirmation(): void
    {
        $user = $this->user('deniz');
        $this->token($user)->deleteJson('/api/v1/auth/account', ['password' => 'wrong', 'confirmation' => 'SİL'])->assertUnprocessable();
        $this->deleteJson('/api/v1/auth/account', ['password' => 'Account12345!', 'confirmation' => ''])->assertUnprocessable();
        $this->deleteJson('/api/v1/auth/account', ['password' => "Account12345!\0", 'confirmation' => 'SİL'])->assertUnprocessable();
        $this->assertSame('active', $user->fresh()->account_status);
        $this->assertDatabaseCount('personal_access_tokens', 1);
    }

    public function test_erasure_removes_personal_data_media_location_and_all_tokens_without_breaking_relations(): void
    {
        Storage::fake('local');
        Storage::fake('public');
        $user = $this->user('deniz');
        $peer = $this->user('elif');
        $oldToken = $user->createToken('other-device')->plainTextToken;
        $post = $this->token($user)->postJson('/api/v1/posts', [
            'body' => 'Private old words', 'type' => 'moment', 'visibility' => 'city', 'city_id' => $user->city_id, 'is_anonymous' => false,
            'request_id' => (string) Str::uuid(), 'media' => [UploadedFile::fake()->image('photo.jpg')],
        ])->assertCreated()->json('data.id');
        $this->postJson('/api/v1/profile/avatar', ['avatar' => UploadedFile::fake()->image('avatar.jpg')])->assertOk();
        $avatar = $user->fresh()->avatar;
        $this->putJson('/api/v1/location', ['latitude' => 36.544, 'longitude' => 32, 'accuracy' => 25, 'record_history' => true])->assertOk();
        $this->postJson('/api/v1/users/'.$peer->id.'/messages', ['body' => 'Private chat words', 'request_id' => (string) Str::uuid()])->assertCreated();
        $media = DB::table('post_media')->where('post_id', $post)->first();
        $this->deleteJson('/api/v1/auth/account', ['password' => 'Account12345!', 'confirmation' => 'SİL'])->assertOk();
        $erased = $user->fresh();
        $this->assertSame('deleted', $erased->account_status);
        $this->assertNotSame('deniz', $erased->username);
        $this->assertNotSame('deniz@example.test', $erased->email);
        $this->assertNull($erased->avatar);
        $this->assertNotNull($erased->erased_at);
        foreach (['personal_access_tokens', 'user_locations', 'user_location_history', 'user_devices'] as $table) {
            $this->assertDatabaseCount($table, 0);
        }
        $this->assertSame(0, app(MediaCleanup::class)->run());
        Storage::disk($media->disk)->assertMissing($media->file_path);
        Storage::disk(config('mobile.avatar_disk'))->assertMissing($avatar);
        $this->assertDatabaseHas('posts', ['id' => $post, 'body' => '', 'approx_latitude' => null]);
        $this->assertDatabaseHas('messages', ['sender_id' => $user->id, 'body' => '', 'image_path' => null]);
        $this->token($peer)->getJson('/api/v1/users/deniz')->assertNotFound();
        $this->getJson('/api/v1/posts/'.$post)->assertNotFound();
        $this->getJson('/api/v1/search?q=deniz&type=users')->assertOk()->assertJsonCount(0, 'data.items');
        $conversation = DB::table('conversations')->where('first_user_id', min($user->id, $peer->id))->first();
        $this->getJson('/api/v1/conversations/'.$conversation->id)->assertNotFound();
        $this->getJson('/api/v1/nearby/users')->assertOk()->assertJsonCount(0, 'data.items');
        $this->get('/api/v1/avatars/'.basename($avatar))->assertNotFound();
        app('auth')->forgetGuards();
        $this->withToken($oldToken)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->postJson('/api/v1/auth/login', ['identifier' => 'deniz', 'password' => 'Account12345!'])->assertUnauthorized();
        $admin = \App\Models\Admin::create(['name' => 'Admin', 'email' => 'admin@example.test', 'password' => 'AdminPassword123!', 'role' => 'super_admin']);
        $this->actingAs($admin, 'admin')->get('/admin/users/'.$user->id)->assertOk()->assertSee('Yeniden etkinleştirilemez');
        $this->post('/admin/users/'.$user->id, ['action' => 'restore'])->assertConflict();
        $this->assertSame('deleted', $user->fresh()->account_status);
    }

    public function test_media_cleanup_retains_failed_entries_for_retry(): void
    {
        DB::table('media_deletions')->insert(['disk' => 'missing-disk', 'path' => 'private.jpg', 'created_at' => now()]);
        $this->assertSame(1, app(MediaCleanup::class)->run());
        $this->assertDatabaseCount('media_deletions', 1);
        Storage::fake('missing-disk');
        $this->assertSame(0, app(MediaCleanup::class)->run());
        $this->assertDatabaseCount('media_deletions', 0);
    }

    public function test_erasure_rechecks_current_password_after_a_session_snapshot_was_loaded(): void
    {
        $user = $this->user('deniz');
        $this->token($user)->getJson('/api/v1/auth/me')->assertOk();
        DB::table('users')->where('id', $user->id)->update(['password' => \Illuminate\Support\Facades\Hash::make('NewAccount12345!')]);
        $this->deleteJson('/api/v1/auth/account', ['password' => 'Account12345!', 'confirmation' => 'SİL'])->assertUnprocessable();
        $this->assertSame('active', $user->fresh()->account_status);
    }
}
