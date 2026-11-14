<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Likes on comments and replies, and private saved collections. */
class CommentLikesAndCollectionsTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $alanya;

    private User $demo;

    private User $elif;

    private User $kaan;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-11-14 12:00:00', 'UTC'));
        $this->alanya = City::where('slug', 'alanya')->value('id');
        $this->demo = $this->user('demo');
        $this->elif = $this->user('elif');
        $this->kaan = $this->user('kaan');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function user(string $name): User
    {
        return User::create(['name' => ucfirst($name).' Test', 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => '1995-01-01', 'password' => 'TestPassword1234', 'city_id' => $this->alanya]);
    }

    private function as(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    private function makePost(User $author, array $extra = []): Post
    {
        return Post::create(['user_id' => $author->id, 'city_id' => $this->alanya, 'type' => 'moment', 'body' => 'Sahilde bir akşam.',
            'visibility' => 'city', 'comments_enabled' => true, 'request_id' => (string) Str::uuid(), ...$extra]);
    }

    private function comment(User $user, Post $post, string $body, ?int $parent = null): array
    {
        return $this->as($user)->postJson('/api/v1/posts/'.$post->id.'/comments', ['body' => $body] + ($parent ? ['parent_id' => $parent] : []))
            ->assertCreated()->json('data');
    }

    private function like(User $user, Post $post, int $comment): \Illuminate\Testing\TestResponse
    {
        return $this->as($user)->postJson('/api/v1/posts/'.$post->id.'/comments/'.$comment.'/like');
    }

    private function unlike(User $user, Post $post, int $comment): \Illuminate\Testing\TestResponse
    {
        return $this->as($user)->deleteJson('/api/v1/posts/'.$post->id.'/comments/'.$comment.'/like');
    }

    private function list(User $user, Post $post): array
    {
        return $this->as($user)->getJson('/api/v1/posts/'.$post->id.'/comments')->assertOk()->json('data.items');
    }

    // --------------------------------------------------------------------------------- comment likes

    public function test_top_level_comments_and_replies_can_be_liked_unliked_and_counted_idempotently(): void
    {
        $post = $this->makePost($this->demo);
        $top = $this->comment($this->elif, $post, 'Ana yorum');
        $reply = $this->comment($this->kaan, $post, 'Cevap', $top['id']);
        $this->assertSame(0, $top['likes_count']);
        $this->assertFalse($top['liked_by_me']);

        $first = $this->like($this->demo, $post, $top['id'])->assertOk()->assertJsonPath('data.likes_count', 1)->assertJsonPath('data.liked_by_me', true);
        $this->assertSame($top['id'], $first->json('data.id'));
        // Idempotent: a second like never double counts.
        $this->like($this->demo, $post, $top['id'])->assertOk()->assertJsonPath('data.likes_count', 1);
        $this->like($this->kaan, $post, $top['id'])->assertOk()->assertJsonPath('data.likes_count', 2);
        $this->like($this->demo, $post, $reply['id'])->assertOk()->assertJsonPath('data.likes_count', 1)->assertJsonPath('data.parent_id', $top['id']);
        $this->assertSame(3, DB::table('comment_likes')->count());

        $list = $this->list($this->demo, $post);
        $this->assertSame(2, $list[0]['likes_count']);
        $this->assertTrue($list[0]['liked_by_me']);
        $this->assertSame(1, $list[0]['replies'][0]['likes_count']);
        $this->assertTrue($list[0]['replies'][0]['liked_by_me']);
        // Per viewer: Elif never liked anything.
        $other = $this->list($this->elif, $post);
        $this->assertSame(2, $other[0]['likes_count']);
        $this->assertFalse($other[0]['liked_by_me']);
        $replies = $this->as($this->elif)->getJson('/api/v1/posts/'.$post->id.'/comments/'.$top['id'].'/replies')->json('data.items');
        $this->assertSame(1, $replies[0]['likes_count']);

        // Unlike: idempotent as well, count follows.
        $this->unlike($this->demo, $post, $top['id'])->assertOk()->assertJsonPath('data.likes_count', 1)->assertJsonPath('data.liked_by_me', false);
        $this->unlike($this->demo, $post, $top['id'])->assertOk()->assertJsonPath('data.likes_count', 1);
        $this->unlike($this->kaan, $post, $top['id'])->assertOk()->assertJsonPath('data.likes_count', 0);
    }

    public function test_like_notifications_reach_the_author_once_never_the_liker_and_open_the_post(): void
    {
        $post = $this->makePost($this->demo);
        $top = $this->comment($this->elif, $post, 'Ana yorum');
        DB::table('app_notifications')->truncate();

        // Own like: no notification.
        $this->like($this->elif, $post, $top['id'])->assertOk();
        $this->assertSame(0, DB::table('app_notifications')->count());
        $this->unlike($this->elif, $post, $top['id'])->assertOk();

        // Someone else's like: "Yorumunu beğendi."
        $this->like($this->demo, $post, $top['id'])->assertOk();
        $this->assertSame(['comment_like'], DB::table('app_notifications')->where('user_id', $this->elif->id)->pluck('type')->all());
        $item = $this->as($this->elif)->getJson('/api/v1/notifications')->assertOk()->json('data.items.0');
        $this->assertSame('Yorumunu beğendi.', $item['text']);
        $this->assertSame('/comments', $item['route']);
        $this->assertSame($post->id, $item['entity_id'], 'A tap opens the comments of the post.');
        $this->assertTrue($item['available']);

        // like → unlike → like: no duplicate.
        $this->unlike($this->demo, $post, $top['id'])->assertOk();
        $this->like($this->demo, $post, $top['id'])->assertOk();
        $this->unlike($this->demo, $post, $top['id'])->assertOk();
        $this->like($this->demo, $post, $top['id'])->assertOk();
        $this->assertSame(1, DB::table('app_notifications')->where('type', 'comment_like')->count());

        // Reply likes notify the reply's author with the same text and route.
        $reply = $this->comment($this->kaan, $post, 'Cevap', $top['id']);
        $this->like($this->demo, $post, $reply['id'])->assertOk();
        $this->assertSame(1, DB::table('app_notifications')->where('user_id', $this->kaan->id)->where('type', 'comment_like')->count());
        $this->assertSame($post->id, $this->as($this->kaan)->getJson('/api/v1/notifications')->json('data.items.0.entity_id'));
    }

    public function test_blocked_deleted_and_moderated_comments_cannot_be_liked_and_leave_no_public_counts(): void
    {
        $post = $this->makePost($this->kaan);
        $top = $this->comment($this->elif, $post, 'Ana yorum');
        $reply = $this->comment($this->kaan, $post, 'Cevap', $top['id']);
        $this->like($this->demo, $post, $top['id'])->assertOk();
        $this->like($this->demo, $post, $reply['id'])->assertOk();

        // Block: the pair can neither like nor see each other's likes.
        $this->as($this->elif)->putJson('/api/v1/blocks/'.$this->demo->id)->assertSuccessful();
        $this->like($this->demo, $post, $top['id'])->assertNotFound();
        $this->like($this->elif, $post, $reply['id'])->assertOk()->assertJsonPath('data.likes_count', 1);
        $this->assertSame(1, $this->list($this->elif, $post)[0]['replies'][0]['likes_count'], 'The blocked person’s like is not counted for the blocker.');
        $this->as($this->elif)->deleteJson('/api/v1/blocks/'.$this->demo->id)->assertSuccessful();

        // Owner delete removes the like rows of the comment and of its replies.
        $this->as($this->elif)->deleteJson('/api/v1/posts/'.$post->id.'/comments/'.$top['id'])->assertOk();
        $this->assertSame(0, DB::table('comment_likes')->count());
        $this->like($this->demo, $post, $top['id'])->assertNotFound();
        $this->like($this->demo, $post, $reply['id'])->assertNotFound();

        // Moderation removal does the same.
        $other = $this->comment($this->kaan, $post, 'Başka yorum');
        $this->like($this->demo, $post, $other['id'])->assertOk();
        $admin = \App\Models\Admin::create(['name' => 'Y', 'email' => 'admin@example.test', 'password' => 'Secret1234!', 'role' => 'super_admin']);
        $this->actingAs($admin, 'admin')->post('/admin/comments/'.$other['id'].'/moderate', ['action' => 'remove', 'note' => 'test'])->assertRedirect();
        $this->assertSame(0, DB::table('comment_likes')->where('comment_id', $other['id'])->count());
        $this->like($this->demo, $post, $other['id'])->assertNotFound();
    }

    public function test_account_deletion_removes_their_likes_and_the_likes_on_their_comments(): void
    {
        $post = $this->makePost($this->demo);
        $mine = $this->comment($this->elif, $post, 'Elif yorumu');
        $kaans = $this->comment($this->kaan, $post, 'Kaan yorumu');
        $this->like($this->kaan, $post, $mine['id'])->assertOk();
        $this->like($this->elif, $post, $kaans['id'])->assertOk();
        $this->as($this->elif)->deleteJson('/api/v1/auth/account', ['password' => 'TestPassword1234', 'confirmation' => 'SİL'])->assertOk();
        $this->assertSame(0, DB::table('comment_likes')->count());
        $this->assertSame(0, $this->list($this->demo, $post)[0]['likes_count']);
    }

    // --------------------------------------------------------------------------------- collections

    private function save(User $user, Post $post): void
    {
        $this->as($user)->postJson('/api/v1/posts/'.$post->id.'/save')->assertOk();
    }

    private function collection(User $user, string $name): array
    {
        return $this->as($user)->postJson('/api/v1/saved-collections', ['name' => $name])->assertCreated()->json('data');
    }

    private function members(User $user, int $collection, string $query = ''): array
    {
        return $this->as($user)->getJson('/api/v1/saved-collections/'.$collection.'/posts'.$query)->assertOk()->json('data');
    }

    public function test_collections_can_be_created_renamed_and_deleted_with_validation_and_limits(): void
    {
        $alanya = $this->collection($this->demo, '  Alanya  ');
        $this->assertSame('Alanya', $alanya['name']);
        $this->assertSame(0, $alanya['posts_count']);
        // Duplicate names (case-insensitive, whitespace-normalised) are refused, per user only.
        $this->as($this->demo)->postJson('/api/v1/saved-collections', ['name' => 'ALANYA'])->assertStatus(422)->assertJsonValidationErrors('name');
        $this->as($this->demo)->postJson('/api/v1/saved-collections', ['name' => 'alanya '])->assertStatus(422);
        $this->collection($this->elif, 'Alanya');
        // Required / 40 characters.
        $this->as($this->demo)->postJson('/api/v1/saved-collections', ['name' => '   '])->assertStatus(422);
        $this->as($this->demo)->postJson('/api/v1/saved-collections', ['name' => str_repeat('a', 41)])->assertStatus(422);
        $this->as($this->demo)->postJson('/api/v1/saved-collections', ['name' => str_repeat('ş', 40)])->assertCreated();

        // Rename: collisions refused, changing only the case of itself is fine.
        $second = $this->collection($this->demo, 'Sonra Bak');
        $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$second['id'], ['name' => 'alanya'])->assertStatus(422);
        $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$alanya['id'], ['name' => 'ALANYA'])->assertOk()->assertJsonPath('data.name', 'ALANYA');
        $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$second['id'], ['name' => 'Güzel Anılar'])->assertOk();
        $names = collect($this->as($this->demo)->getJson('/api/v1/saved-collections')->assertOk()->json('data.items'))->pluck('name')->all();
        $this->assertContains('Güzel Anılar', $names);
        $this->assertNotContains('Sonra Bak', $names);

        // Delete.
        $this->as($this->demo)->deleteJson('/api/v1/saved-collections/'.$second['id'])->assertOk();
        $this->assertCount(2, $this->as($this->demo)->getJson('/api/v1/saved-collections')->json('data.items'));

        // Limit: 30 per user.
        foreach (range(1, 30) as $i) {
            DB::table('saved_collections')->insert(['user_id' => $this->kaan->id, 'name' => "Koleksiyon $i", 'name_key' => "koleksiyon $i", 'created_at' => now(), 'updated_at' => now()]);
        }
        $this->as($this->kaan)->postJson('/api/v1/saved-collections', ['name' => 'Otuz bir'])->assertStatus(422)->assertJsonValidationErrors('name');
    }

    public function test_posts_join_several_collections_leaving_one_keeps_the_save_and_deleting_a_collection_never_unsaves(): void
    {
        $post = $this->makePost($this->elif);
        $other = $this->makePost($this->elif, ['body' => 'İkinci']);
        $alanya = $this->collection($this->demo, 'Alanya');
        $later = $this->collection($this->demo, 'Sonra Bak');

        // Only saved posts can be grouped.
        $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$alanya['id'].'/posts/'.$post->id)->assertStatus(422)->assertJsonValidationErrors('post');
        $this->save($this->demo, $post);
        $this->save($this->demo, $other);
        $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$alanya['id'].'/posts/'.$post->id)->assertOk()->assertJsonPath('data.contains_post', true)->assertJsonPath('data.posts_count', 1);
        $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$alanya['id'].'/posts/'.$post->id)->assertOk()->assertJsonPath('data.posts_count', 1);
        $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$later['id'].'/posts/'.$post->id)->assertOk();
        $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$later['id'].'/posts/'.$other->id)->assertOk();

        $membership = collect($this->as($this->demo)->getJson('/api/v1/saved-collections?post_id='.$post->id)->json('data.items'))->pluck('contains_post', 'name');
        $this->assertTrue($membership['Alanya']);
        $this->assertTrue($membership['Sonra Bak']);
        $this->assertSame([$post->id], collect($this->members($this->demo, $alanya['id'])['items'])->pluck('id')->all());
        $this->assertCount(2, $this->members($this->demo, $later['id'])['items']);

        // Leaving a collection leaves the main list alone.
        $this->as($this->demo)->deleteJson('/api/v1/saved-collections/'.$alanya['id'].'/posts/'.$post->id)->assertOk()->assertJsonPath('data.contains_post', false);
        $this->assertContains($post->id, collect($this->as($this->demo)->getJson('/api/v1/posts/saved')->json('data.items'))->pluck('id')->all());

        // Deleting a collection never un-saves its posts.
        $this->as($this->demo)->deleteJson('/api/v1/saved-collections/'.$later['id'])->assertOk();
        $saved = collect($this->as($this->demo)->getJson('/api/v1/posts/saved')->json('data.items'))->pluck('id')->all();
        $this->assertEqualsCanonicalizing([$post->id, $other->id], $saved);
        $this->assertSame(0, DB::table('saved_collection_posts')->count());

        // Un-saving removes the post from every collection.
        $again = $this->collection($this->demo, 'Yolculuklar');
        $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$again['id'].'/posts/'.$post->id)->assertOk();
        $this->as($this->demo)->deleteJson('/api/v1/posts/'.$post->id.'/save')->assertOk();
        $this->assertSame(0, DB::table('saved_collection_posts')->count());
        $this->assertSame([], $this->members($this->demo, $again['id'])['items']);
    }

    public function test_unavailable_posts_leave_collection_responses_and_the_list_paginates(): void
    {
        $collection = $this->collection($this->demo, 'Alanya');
        $kept = [];
        foreach (range(1, 22) as $i) {
            Carbon::setTestNow(now()->addMinute());
            $post = $this->makePost($this->elif, ['body' => "Gönderi $i"]);
            $this->save($this->demo, $post);
            $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$collection['id'].'/posts/'.$post->id)->assertOk();
            $kept[] = $post;
        }
        $first = $this->members($this->demo, $collection['id']);
        $this->assertCount(20, $first['items']);
        $this->assertSame(2, $first['next_page']);
        $this->assertSame('Gönderi 22', $first['items'][0]['body'], 'Newest addition first.');
        $second = $this->members($this->demo, $collection['id'], '?page=2');
        $this->assertCount(2, $second['items']);
        $this->assertNull($second['next_page']);

        // Deleted, moderated, blocked and suspended authors no longer show up (nor count).
        $kept[0]->delete();
        $kept[1]->forceFill(['moderated_at' => now()])->save();
        $kept[1]->delete();
        $this->assertSame(20, $this->as($this->demo)->getJson('/api/v1/saved-collections')->json('data.items.0.posts_count'));
        $blocked = $this->makePost($this->kaan, ['body' => 'Engelli']);
        $this->save($this->demo, $blocked);
        $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$collection['id'].'/posts/'.$blocked->id)->assertOk();
        $this->as($this->demo)->putJson('/api/v1/blocks/'.$this->kaan->id)->assertSuccessful();
        $all = [];
        foreach ([1, 2] as $page) {
            $all = array_merge($all, $this->members($this->demo, $collection['id'], '?page='.$page)['items']);
        }
        $bodies = collect($all)->pluck('body');
        $this->assertNotContains('Engelli', $bodies->all());
        $this->assertNotContains('Gönderi 1', $bodies->all());
        $this->assertNotContains('Gönderi 2', $bodies->all());
        $this->assertSame(20, $bodies->count());
        $this->elif->forceFill(['account_status' => 'suspended'])->save();
        $this->assertSame([], $this->members($this->demo, $collection['id'])['items']);
    }

    public function test_collections_are_private_to_their_owner_and_removed_with_the_account(): void
    {
        $post = $this->makePost($this->kaan);
        $this->save($this->demo, $post);
        $secret = $this->collection($this->demo, 'Gizli Anılar');
        $this->as($this->demo)->putJson('/api/v1/saved-collections/'.$secret['id'].'/posts/'.$post->id)->assertOk();

        // Nobody else can read, rename, delete or fill it; its id looks like a missing one.
        $this->as($this->elif)->getJson('/api/v1/saved-collections/'.$secret['id'].'/posts')->assertNotFound();
        $this->as($this->elif)->putJson('/api/v1/saved-collections/'.$secret['id'], ['name' => 'Ele geçti'])->assertNotFound();
        $this->as($this->elif)->deleteJson('/api/v1/saved-collections/'.$secret['id'])->assertNotFound();
        $this->as($this->elif)->putJson('/api/v1/saved-collections/'.$secret['id'].'/posts/'.$post->id)->assertNotFound();
        $this->as($this->elif)->deleteJson('/api/v1/saved-collections/'.$secret['id'].'/posts/'.$post->id)->assertNotFound();
        $this->assertSame([], $this->as($this->elif)->getJson('/api/v1/saved-collections')->json('data.items'));
        // Neither the name nor the grouping leaks through the post, the author, search or the saved list of somebody else.
        foreach (['/api/v1/posts/'.$post->id, '/api/v1/posts/saved', '/api/v1/users/demo', '/api/v1/feed?city_id='.$this->alanya] as $url) {
            $this->assertStringNotContainsString('Gizli Anılar', $this->as($this->kaan)->getJson($url)->getContent());
        }
        $this->assertSame('Gizli Anılar', DB::table('saved_collections')->value('name'));

        $this->as($this->demo)->deleteJson('/api/v1/auth/account', ['password' => 'TestPassword1234', 'confirmation' => 'SİL'])->assertOk();
        $this->assertSame(0, DB::table('saved_collections')->count());
        $this->assertSame(0, DB::table('saved_collection_posts')->count());
    }
}
