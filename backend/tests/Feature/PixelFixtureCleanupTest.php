<?php

namespace Tests\Feature;

use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Senmiydin\Development\PixelFixtures;
use Tests\TestCase;

require_once __DIR__.'/../../../tool/PixelFixtures.php';

class PixelFixtureCleanupTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    public function test_cleanup_removes_only_owned_records_and_queues_their_media(): void
    {
        Storage::fake(config('mobile.avatar_disk'));
        Storage::fake(config('mobile.post_media_disk'));
        $service = new PixelFixtures;
        $state = $service->create();
        $a = $state['accounts']['encounter_writer']['id'];
        $b = $state['accounts']['encounter_reader']['id'];
        $city = User::findOrFail($a)->city_id;
        $unrelated = User::create(['name' => 'Ada Kaya', 'username' => 'ada', 'email' => 'ada@example.test', 'password' => 'Parola1234!', 'birth_date' => '1995-04-12', 'city_id' => $city]);
        $kept = Post::create(['user_id' => $unrelated->id, 'city_id' => $city, 'type' => 'moment', 'body' => 'Güzel bir gün.', 'visibility' => 'city', 'request_id' => (string) Str::uuid()]);
        $source = Post::create(['user_id' => $a, 'city_id' => $city, 'type' => 'encounter', 'body' => 'Sahilde karşılaştık.', 'visibility' => 'city', 'request_id' => (string) Str::uuid()]);
        $request = DB::table('encounter_requests')->insertGetId(['requester_id' => $a, 'target_user_id' => $b, 'source_post_id' => $source->id, 'status' => 'accepted', 'created_at' => now(), 'updated_at' => now()]);
        $encounter = DB::table('encounters')->insertGetId(['request_id' => $request, 'confirmed_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        $story = new Post(['user_id' => $b, 'city_id' => $city, 'type' => 'encounter', 'body' => 'Yeniden merhaba.', 'visibility' => 'city', 'request_id' => (string) Str::uuid()]);
        $story->forceFill(['encounter_id' => $encounter, 'story_title' => 'İkinci merhaba', 'story_status' => 'published'])->save();
        $path = 'posts/'.Str::uuid().'.jpg';
        $story->media()->create(['disk' => config('mobile.post_media_disk'), 'file_path' => $path, 'sort_order' => 0, 'mime_type' => 'image/jpeg', 'width' => 30, 'height' => 20]);
        DB::table('post_comments')->insert(['user_id' => $a, 'post_id' => $kept->id, 'body' => 'Ne güzel!', 'created_at' => now(), 'updated_at' => now()]);
        foreach (['post_likes', 'post_saves'] as $table) {
            DB::table($table)->insert(['user_id' => $a, 'post_id' => $kept->id, 'created_at' => now()]);
        }
        DB::table('user_follows')->insert(['follower_id' => $a, 'followed_id' => $unrelated->id, 'created_at' => now()]);
        DB::table('app_notifications')->insert(['user_id' => $unrelated->id, 'actor_id' => $a, 'type' => 'comment', 'entity_id' => $kept->id, 'created_at' => now()]);
        $travel = Post::create(['user_id' => $a, 'city_id' => $city, 'type' => 'travel', 'body' => 'Bir sonraki molada kahve içelim mi?', 'visibility' => 'city', 'request_id' => (string) Str::uuid()]);
        DB::table('post_travel_details')->insert(['post_id' => $travel->id, 'transport_type' => 'bus', 'origin_city_id' => $city, 'destination_city_id' => $city, 'departure_at' => now(), 'operator_name' => 'Pamukkale', 'vehicle_identifier' => '07 NM 365']);
        DB::table('location_matches')->insert(['user_id' => $b, 'post_id' => $travel->id, 'distance_meters' => 50, 'matched_at' => now()]);
        $chat = DB::table('conversations')->insertGetId(['first_user_id' => min($a, $b), 'second_user_id' => max($a, $b), 'requester_id' => $a, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $image = 'messages/'.Str::uuid().'.jpg';
        DB::table('messages')->insert(['conversation_id' => $chat, 'sender_id' => $a, 'request_id' => (string) Str::uuid(), 'body' => 'Merhaba!', 'type' => 'image', 'image_path' => $image, 'created_at' => now(), 'updated_at' => now()]);
        $result = $service->cleanup($state);
        $this->assertTrue($result['clean']);
        $this->assertSame(9, $result['users']);
        $this->assertDatabaseHas('users', ['id' => $unrelated->id]);
        $this->assertDatabaseHas('posts', ['id' => $kept->id, 'body' => 'Güzel bir gün.']);
        foreach (['post_comments', 'post_likes', 'post_saves', 'user_follows', 'encounter_requests', 'encounters', 'post_media', 'app_notifications', 'post_travel_details', 'location_matches', 'messages', 'conversations'] as $table) {
            $this->assertDatabaseCount($table, 0);
        }
        $this->assertDatabaseHas('media_deletions', ['path' => $path]);
        $this->assertSame(0, $service->cleanup($state)['users']);
    }

    public function test_modified_ownership_ledger_cannot_delete_another_identity(): void
    {
        Storage::fake(config('mobile.avatar_disk'));
        $service = new PixelFixtures;
        $state = $service->create();
        $state['accounts']['location']['email'] = 'someone@example.test';
        try {
            $service->cleanup($state);
            $this->fail('Expected ownership refusal.');
        } catch (\RuntimeException $error) {
            $this->assertStringContainsString('ownership mismatch', $error->getMessage());
        }
        $this->assertDatabaseCount('users', 9);
    }

    public function test_legacy_cleanup_refuses_an_unknown_real_account(): void
    {
        $user = User::create(['name' => 'Ada Kaya', 'username' => 'ada', 'email' => 'ada@example.test', 'password' => 'Parola1234!', 'birth_date' => '1995-04-12', 'city_id' => DB::table('cities')->value('id')]);
        try {
            (new PixelFixtures)->cleanupKnownLegacyAccounts([['id' => $user->id, 'username' => 'ada', 'email' => 'ada@example.test']]);
            $this->fail('Expected legacy refusal.');
        } catch (\RuntimeException $error) {
            $this->assertStringContainsString('unknown legacy', $error->getMessage());
        }
        $this->assertDatabaseHas('users', ['id' => $user->id]);
    }

    public function test_demo_quality_assertion_detects_numeric_and_uuid_leaks_without_deleting_content(): void
    {
        $user = User::create(['name' => 'Deniz Kaya', 'username' => 'demo', 'email' => 'demo@senmiydin.local', 'password' => 'Parola1234!', 'birth_date' => '1995-04-12', 'city_id' => DB::table('cities')->value('id')]);
        $post = Post::create(['user_id' => $user->id, 'city_id' => $user->city_id, 'type' => 'moment', 'body' => 'Güzel bir gün.', 'visibility' => 'city', 'request_id' => (string) Str::uuid()]);
        foreach (['Sahilde ikinci merhaba 1794153212180', 'Sahilde ikinci merhaba '.Str::uuid()] as $body) {
            $post->forceFill(['body' => $body])->save();
            try {
                (new PixelFixtures)->assertDemoQuality();
                $this->fail('Expected suffix detection.');
            } catch (\RuntimeException $error) {
                $this->assertStringContainsString('internal suffix', $error->getMessage());
            }
            $this->assertDatabaseHas('posts', ['id' => $post->id, 'body' => $body]);
        }
        $post->forceFill(['body' => 'Sahilde ikinci merhaba'])->save();
        (new PixelFixtures)->assertDemoQuality();
    }

    public function test_fixture_cli_bootstraps_and_refuses_production_before_any_database_change(): void
    {
        $process = new \Symfony\Component\Process\Process(
            [PHP_BINARY, dirname(base_path()).'/tool/pixel_fixtures.php', '--cleanup'],
            dirname(base_path()),
            ['APP_ENV'=>'production']
        );
        $process->setTimeout(20);
        $process->run();
        $this->assertSame(1, $process->getExitCode());
        $this->assertStringContainsString('REFUSE: device fixtures require development or testing.', $process->getErrorOutput());
    }

    public function test_production_environment_cannot_prepare_or_clean_fixtures(): void
    {
        $this->app['env'] = 'production';
        $this->expectException(\RuntimeException::class);
        PixelFixtures::guard();
    }
}
