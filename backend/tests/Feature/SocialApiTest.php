<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class SocialApiTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private User $author;

    private User $reader;

    private int $city;

    protected function setUp(): void
    {
        parent::setUp();
        $this->city = City::where('slug', 'alanya')->value('id');
        $this->author = $this->user('deniz');
        $this->reader = $this->user('ece');
    }

    public function test_text_creation_is_idempotent_and_visible_in_feed(): void
    {
        $fields = $this->draft();
        $first = $this->asUser($this->author)->postJson('/api/v1/posts', $fields)->assertCreated();
        $id = $first->json('data.id');
        $this->asUser($this->author)->postJson('/api/v1/posts', $fields)->assertOk()->assertJsonPath('data.id', $id);
        $this->assertDatabaseCount('posts', 1);
        $this->asUser($this->reader)->getJson('/api/v1/feed')
            ->assertOk()->assertJsonPath('data.items.0.id', $id)
            ->assertJsonPath('data.items.0.author.username', 'deniz')
            ->assertJsonPath('data.items.0.mine', false);
        $this->asUser($this->reader)->getJson("/api/v1/posts/$id")->assertOk();
    }

    public function test_media_upload_preserves_order_and_checks_image_validity_and_limits(): void
    {
        $disk = Storage::fake(config('mobile.post_media_disk'));
        $response = $this->asUser($this->author)->postJson('/api/v1/posts', $this->draft([
            'body' => '',
            'media' => [UploadedFile::fake()->image('two.png', 40, 60), UploadedFile::fake()->image('one.jpg', 20, 30)],
        ]))->assertCreated()->assertJsonPath('data.media.0.width', 40)
            ->assertJsonPath('data.media.1.height', 30);
        $media = $response->json('data.media.0.url');
        $this->asUser($this->reader)->get($media)->assertOk()->assertHeader('Content-Type', 'image/jpeg');
        $this->asUser($this->author)->postJson('/api/v1/posts', $this->draft([
            'media' => [UploadedFile::fake()->image('wrong.gif')],
        ]))->assertUnprocessable()->assertJsonValidationErrors('media.0');
        $this->asUser($this->author)->postJson('/api/v1/posts', $this->draft([
            'media' => array_fill(0, 11, UploadedFile::fake()->image('overflow.jpg')),
        ]))->assertUnprocessable()->assertJsonValidationErrors('media');
        $this->assertCount(2, $disk->allFiles('posts'));
    }

    public function test_anonymous_posts_and_their_owner_comments_hide_identity_and_public_profile_link(): void
    {
        $id = $this->publish(['is_anonymous' => true]);
        $this->assertDatabaseHas('posts', ['id' => $id, 'user_id' => $this->author->id]);
        $this->asUser($this->author)->getJson("/api/v1/posts/$id")->assertJsonPath('data.mine', true);
        $this->asUser($this->reader)->getJson("/api/v1/posts/$id")->assertOk()
            ->assertJsonPath('data.author', null)->assertJsonPath('data.mine', false)->assertJsonMissingPath('data.user_id');
        $this->asUser($this->author)->postJson("/api/v1/posts/$id/comments", ['body' => 'Bir ek bilgi'])
            ->assertCreated()->assertJsonPath('data.author', null);
        $this->asUser($this->reader)->getJson("/api/v1/posts/$id/comments")
            ->assertJsonPath('data.items.0.author', null)->assertJsonPath('data.items.0.mine', false);
        $this->asUser($this->reader)->getJson('/api/v1/users/deniz/posts')->assertJsonCount(0, 'data.items');
        $this->asUser($this->reader)->getJson('/api/v1/users/deniz')->assertJsonPath('data.post_count', 0);
        $this->asUser($this->author)->getJson('/api/v1/users/deniz/posts')->assertJsonPath('data.items.0.id', $id);
    }

    public function test_feed_paginates_by_city_and_popularity_without_per_post_queries(): void
    {
        $ankara = City::where('slug', 'ankara')->value('id');
        $other = $this->publish(['city_id' => $ankara]);
        $hidden = $this->publish(['visibility' => 'private']);
        $liked = $this->publish();
        $this->asUser($this->reader)->postJson("/api/v1/posts/$liked/like")->assertOk();
        $rows = [];
        for ($i = 0; $i < 21; $i++) {
            $rows[] = [...$this->draft(), 'user_id' => $this->author->id, 'created_at' => now(), 'updated_at' => now()];
        }
        Post::insert($rows);
        $this->asUser($this->reader);
        DB::enableQueryLog();
        DB::flushQueryLog();
        $page = $this->getJson('/api/v1/feed')->assertOk()->assertJsonCount(20, 'data.items')
            ->assertJsonPath('data.next_page', 2);
        $this->assertLessThan(12, count(DB::getQueryLog()));
        DB::disableQueryLog();
        $this->assertNotContains($liked, array_column($page->json('data.items'), 'id'));
        $this->asUser($this->reader)->getJson('/api/v1/feed?page=2')->assertJsonCount(2, 'data.items');
        $this->asUser($this->reader)->getJson('/api/v1/feed?sort=popular')->assertJsonPath('data.items.0.id', $liked);
        $this->asUser($this->reader)->getJson("/api/v1/feed?city_id=$ankara&sort=nearby")
            ->assertJsonCount(1, 'data.items')->assertJsonPath('data.items.0.id', $other);
        $this->asUser($this->reader)->getJson("/api/v1/posts/$hidden")->assertNotFound();
    }

    public function test_combined_feed_filters_compose_content_media_radius_and_sort(): void
    {
        Storage::fake(config('mobile.post_media_disk'));
        $this->asUser($this->reader)->putJson('/api/v1/location', [
            'latitude' => 36.5440, 'longitude' => 32.0000, 'accuracy' => 15,
        ])->assertOk();
        $photoEncounterNear = $this->publish([
            'type' => 'encounter', 'location_source' => 'map',
            'place_latitude' => 36.5450, 'place_longitude' => 32.0010,
            'occurred_at' => now()->subMinutes(20)->toIso8601String(),
            'media' => [UploadedFile::fake()->image('encounter-near.jpg', 40, 40)],
        ]);
        $textEncounterNear = $this->publish([
            'type' => 'encounter', 'location_source' => 'map',
            'place_latitude' => 36.5450, 'place_longitude' => 32.0010,
            'occurred_at' => now()->subMinutes(15)->toIso8601String(),
        ]);
        $this->publish([
            'type' => 'moment', 'location_source' => 'map',
            'place_latitude' => 36.5450, 'place_longitude' => 32.0010,
            'occurred_at' => now()->subMinutes(10)->toIso8601String(),
            'media' => [UploadedFile::fake()->image('moment-near.jpg', 40, 40)],
        ]);
        $this->publish([
            'type' => 'encounter', 'location_source' => 'map',
            'place_latitude' => 36.5500, 'place_longitude' => 31.8600,
            'occurred_at' => now()->subMinutes(5)->toIso8601String(),
            'media' => [UploadedFile::fake()->image('encounter-far.jpg', 40, 40)],
        ]);

        $this->asUser($this->reader)
            ->getJson('/api/v1/feed?content=encounter&media=photo&radius=10000&sort=new')
            ->assertOk()
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.id', $photoEncounterNear);

        $this->asUser($this->reader)
            ->getJson('/api/v1/feed?content=encounter&media=text&radius=10000&sort=new')
            ->assertOk()
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.id', $textEncounterNear);
    }

    public function test_like_and_save_are_unique_and_removable(): void
    {
        $id = $this->publish();
        for ($i = 0; $i < 2; $i++) {
            $this->asUser($this->reader)->postJson("/api/v1/posts/$id/like")->assertOk()
                ->assertJsonPath('data.likes_count', 1)->assertJsonPath('data.liked', true);
            $this->asUser($this->reader)->postJson("/api/v1/posts/$id/save")->assertOk()
                ->assertJsonPath('data.saved', true);
        }
        $this->assertDatabaseCount('post_likes', 1);
        $this->assertDatabaseCount('post_saves', 1);
        $this->asUser($this->reader)->getJson('/api/v1/posts/saved')
            ->assertOk()->assertJsonPath('data.items.0.id', $id);
        $this->asUser($this->reader)->deleteJson("/api/v1/posts/$id/like")->assertOk()
            ->assertJsonPath('data.likes_count', 0)->assertJsonPath('data.liked', false);
        $this->asUser($this->reader)->deleteJson("/api/v1/posts/$id/save")->assertOk()->assertJsonPath('data.saved', false);
        $this->asUser($this->reader)->getJson('/api/v1/posts/saved')->assertJsonCount(0, 'data.items');
    }

    public function test_comment_authorization_and_closed_comments(): void
    {
        $id = $this->publish();
        $closed = $this->publish(['comments_enabled' => false]);
        $comment = $this->asUser($this->reader)->postJson("/api/v1/posts/$id/comments", ['body' => 'Merhaba'])
            ->assertCreated()->assertJsonPath('data.mine', true)->json('data.id');
        $this->asUser($this->author)->getJson("/api/v1/posts/$id")->assertJsonPath('data.comments_count', 1);
        $this->asUser($this->author)->getJson("/api/v1/posts/$id/comments")->assertJsonPath('data.items.0.body', 'Merhaba');
        $this->asUser($this->author)->deleteJson("/api/v1/posts/$id/comments/$comment")->assertForbidden();
        $this->asUser($this->reader)->deleteJson("/api/v1/posts/$id/comments/$comment")->assertOk();
        $this->assertSoftDeleted('post_comments', ['id' => $comment]);
        $this->asUser($this->reader)->getJson("/api/v1/posts/$id")->assertJsonPath('data.comments_count', 0);
        $this->asUser($this->reader)->postJson("/api/v1/posts/$closed/comments", ['body' => 'Kapalı'])->assertForbidden();
    }

    public function test_follow_profile_and_connections_use_real_counts(): void
    {
        $this->publish();
        $this->asUser($this->reader)->postJson('/api/v1/users/ece/follow')->assertUnprocessable();
        for ($i = 0; $i < 2; $i++) {
            $this->asUser($this->reader)->postJson('/api/v1/users/deniz/follow')->assertOk()
                ->assertJsonPath('data.followers_count', 1)->assertJsonPath('data.following', true)
                ->assertJsonPath('data.post_count', 1)->assertJsonMissingPath('data.email');
        }
        $this->assertDatabaseCount('user_follows', 1);
        $this->asUser($this->reader)->getJson('/api/v1/users/deniz/followers')->assertJsonPath('data.items.0.username', 'ece');
        $this->asUser($this->reader)->getJson('/api/v1/users/ece/following')->assertJsonPath('data.items.0.username', 'deniz');
        $this->asUser($this->reader)->getJson('/api/v1/users/ece')->assertJsonPath('data.following_count', 1);
        $this->asUser($this->reader)->deleteJson('/api/v1/users/deniz/follow')->assertOk()
            ->assertJsonPath('data.followers_count', 0)->assertJsonPath('data.following', false);
    }

    public function test_search_is_bounded_and_matches_usernames_names_and_visible_posts(): void
    {
        $id = $this->publish(['body' => 'Sahilde güzel bir gün']);
        $this->publish(['body' => 'Sahilde gizli', 'visibility' => 'private']);
        $this->asUser($this->reader)->getJson('/api/v1/search?type=users')->assertUnprocessable();
        $this->asUser($this->reader)->getJson('/api/v1/search?type=users&q=a')->assertUnprocessable();
        $this->asUser($this->reader)->getJson('/api/v1/search?type=users&q=%40DEN')->assertJsonPath('data.items.0.username', 'deniz');
        $this->asUser($this->reader)->getJson('/api/v1/search?type=users&q=Yildiz')->assertJsonPath('data.items.0.username', 'deniz');
        $this->asUser($this->reader)->getJson('/api/v1/search?type=posts&q=sahil')->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.id', $id);
        $this->asUser($this->reader)->getJson('/api/v1/search?type=posts&q=%25%25')->assertJsonCount(0, 'data.items');
    }

    public function test_edit_delete_authorization_and_private_media_access_after_deletion(): void
    {
        $disk = Storage::fake(config('mobile.post_media_disk'));
        $post = $this->asUser($this->author)->postJson('/api/v1/posts', $this->draft([
            'visibility' => 'private',
            'media' => [UploadedFile::fake()->image('private.jpg')],
        ]))->assertCreated()->json('data');
        $id = $post['id'];
        $this->asUser($this->reader)->get($post['media'][0]['url'])->assertNotFound();
        $this->asUser($this->author)->get($post['media'][0]['url'])->assertOk();
        $this->asUser($this->author)->deleteJson("/api/v1/posts/$id")->assertOk();
        $this->asUser($this->author)->get($post['media'][0]['url'])->assertNotFound();
        $this->assertSoftDeleted('posts', ['id' => $id]);
        $this->assertCount(1, $disk->allFiles('posts'));
        $this->travel(31)->days();
        $this->artisan('posts:purge-deleted')->assertExitCode(0);
        $this->assertDatabaseMissing('posts', ['id' => $id]);
        $this->assertSame([], $disk->allFiles('posts'));
        $this->travelBack();

        $public = $this->publish();
        $this->asUser($this->reader)->putJson("/api/v1/posts/$public", ['body' => 'Değişiklik'])->assertForbidden();
        $this->asUser($this->reader)->deleteJson("/api/v1/posts/$public")->assertForbidden();
        $this->asUser($this->author)->putJson("/api/v1/posts/$public", ['body' => 'Değişiklik'])->assertOk()
            ->assertJsonPath('data.body', 'Değişiklik');
        $this->asUser($this->author)->putJson("/api/v1/posts/$public", ['body' => ''])->assertUnprocessable();
        $this->asUser($this->author)->deleteJson("/api/v1/posts/$public")->assertOk();
        $this->asUser($this->reader)->getJson('/api/v1/feed')->assertJsonCount(0, 'data.items');
    }

    private function user(string $username): User
    {
        return User::create([
            'username' => $username, 'name' => $username === 'deniz' ? 'Deniz Yildiz' : 'Ece Test',
            'email' => $username.'@example.test', 'city_id' => $this->city,
            'birth_date' => '1998-04-12', 'password' => 'DenemeParola123',
        ]);
    }

    private function draft(array $overrides = []): array
    {
        return [...[
            'body' => 'Sahilde bir anı', 'type' => 'moment', 'city_id' => $this->city,
            'visibility' => 'city', 'is_anonymous' => false, 'request_id' => (string) Str::uuid(),
        ], ...$overrides];
    }

    private function publish(array $overrides = []): int
    {
        return $this->asUser($this->author)->postJson('/api/v1/posts', $this->draft($overrides))
            ->assertCreated()->json('data.id');
    }

    private function asUser(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }
}
