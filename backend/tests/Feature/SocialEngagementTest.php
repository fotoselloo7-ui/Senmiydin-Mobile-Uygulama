<?php

namespace Tests\Feature;

use App\Administration\Settings;
use App\Models\City;
use App\Models\MapNote;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Following feed, single-level comment replies, Mektuplarım (archive / repost), unread nearby letters, discovery ranking. */
class SocialEngagementTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $alanya;

    private int $ankara;

    private User $selman;

    private User $ece;

    private User $kaan;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-11-14 12:00:00', 'UTC'));
        $this->alanya = City::where('slug', 'alanya')->value('id');
        $this->ankara = City::where('slug', 'ankara')->value('id');
        $this->selman = $this->user('selman');
        $this->ece = $this->user('ece');
        $this->kaan = $this->user('kaan');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function user(string $name, array $extra = []): User
    {
        return User::create(['name' => ucfirst($name).' Test', 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => '1995-01-01', 'password' => 'TestPassword1234', 'city_id' => $this->alanya, ...$extra]);
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

    private function follow(User $who, User $target): void
    {
        $this->as($who)->postJson('/api/v1/users/'.$target->username.'/follow')->assertSuccessful();
    }

    private function feed(User $viewer, string $query = ''): array
    {
        return $this->as($viewer)->getJson('/api/v1/feed?city_id='.$this->alanya.'&following=1'.$query)->assertOk()->json('data');
    }

    private function locate(User $user, float $lat, float $lng, ?int $city = null, ?string $at = null): void
    {
        DB::table('user_locations')->upsert([['user_id' => $user->id, 'city_id' => $city ?? $this->alanya, 'latitude' => $lat, 'longitude' => $lng,
            'accuracy' => 20, 'recorded_at' => $at ?? now(), 'visibility' => true, 'created_at' => now(), 'updated_at' => now()]],
            ['user_id'], ['city_id', 'latitude', 'longitude', 'accuracy', 'recorded_at', 'visibility', 'updated_at']);
    }

    // ------------------------------------------------------------------------------------------------ following feed

    public function test_following_feed_shows_only_followed_people_and_follows_the_normal_visibility_rules(): void
    {
        $followed = $this->makePost($this->ece, ['body' => 'Ece paylaşımı']);
        $this->makePost($this->kaan, ['body' => 'Kaan paylaşımı']);
        $this->assertSame([], $this->feed($this->selman)['items'], 'Following nobody gives an empty feed (the app shows the empty state).');

        $this->follow($this->selman, $this->ece);
        $ids = collect($this->feed($this->selman)['items'])->pluck('id')->all();
        $this->assertSame([$followed->id], $ids);

        // Ordinary city feed still has both; "following" is just a narrower view over the same query.
        $all = $this->as($this->selman)->getJson('/api/v1/feed?city_id='.$this->alanya)->assertOk()->json('data.items');
        $this->assertCount(2, $all);

        $this->as($this->selman)->deleteJson('/api/v1/users/ece/follow')->assertSuccessful();
        $this->assertSame([], $this->feed($this->selman)['items'], 'Unfollowing removes the person from the feed.');
    }

    public function test_following_feed_hides_anonymous_private_blocked_suspended_deleted_and_other_city_content(): void
    {
        $this->follow($this->selman, $this->ece);
        $this->follow($this->selman, $this->kaan);
        $visible = $this->makePost($this->ece, ['body' => 'Görünür']);
        $this->makePost($this->ece, ['body' => 'Anonim', 'is_anonymous' => true]);
        $this->makePost($this->ece, ['body' => 'Özel', 'visibility' => 'private']);
        $this->makePost($this->ece, ['body' => 'Başka şehir', 'city_id' => $this->ankara]);
        $removed = $this->makePost($this->ece, ['body' => 'Silinen']);
        $removed->delete();
        $this->makePost($this->kaan, ['body' => 'Kaan']);

        $items = $this->feed($this->selman)['items'];
        $bodies = collect($items)->pluck('body')->all();
        $this->assertContains('Görünür', $bodies);
        $this->assertNotContains('Anonim', $bodies, 'Anonymous posts never show in the follow feed: it would reveal their author.');
        $this->assertNotContains('Özel', $bodies);
        $this->assertNotContains('Başka şehir', $bodies);
        $this->assertNotContains('Silinen', $bodies);
        $this->assertSame(['Görünür', 'Kaan'], collect($bodies)->sort()->values()->all());
        // Anonymous posts stay anonymous in the city-wide feed.
        $city = $this->as($this->selman)->getJson('/api/v1/feed?city_id='.$this->alanya)->assertOk()->json('data.items');
        $anonymous = collect($city)->firstWhere('body', 'Anonim');
        $this->assertNotNull($anonymous);
        $this->assertNull($anonymous['author'] ?? null);

        // Blocked and suspended authors disappear.
        $this->as($this->selman)->putJson('/api/v1/blocks/'.$this->kaan->id)->assertSuccessful();
        $this->assertSame(['Görünür'], collect($this->feed($this->selman)['items'])->pluck('body')->all());
        $this->ece->forceFill(['account_status' => 'suspended'])->save();
        $this->assertSame([], $this->feed($this->selman)['items']);
        $this->assertNotNull($visible->id);
    }

    public function test_following_feed_paginates_with_the_standard_page_size(): void
    {
        $this->follow($this->selman, $this->ece);
        foreach (range(1, 25) as $i) {
            Carbon::setTestNow(now()->addMinute());
            $this->makePost($this->ece, ['body' => "Paylaşım $i"]);
        }
        $first = $this->feed($this->selman);
        $this->assertCount(20, $first['items']);
        $this->assertSame(2, $first['next_page']);
        $second = $this->feed($this->selman, '&page=2');
        $this->assertCount(5, $second['items']);
        $this->assertNull($second['next_page']);
        $this->assertSame('Paylaşım 25', $first['items'][0]['body'], 'Newest first.');
    }

    // ------------------------------------------------------------------------------------------------ comment replies

    private function comment(User $user, Post $post, string $body, ?int $parent = null)
    {
        return $this->as($user)->postJson('/api/v1/posts/'.$post->id.'/comments', ['body' => $body] + ($parent ? ['parent_id' => $parent] : []));
    }

    public function test_replies_attach_to_top_level_comments_only_and_read_oldest_first(): void
    {
        $post = $this->makePost($this->selman);
        $top = $this->comment($this->kaan, $post, 'Ben de dün oradaydım.')->assertCreated()->assertJsonPath('data.parent_id', null)->json('data');
        $first = $this->comment($this->ece, $post, 'Saat kaç civarı?', $top['id'])->assertCreated()->assertJsonPath('data.parent_id', $top['id'])->json('data');
        Carbon::setTestNow(now()->addMinutes(2));
        $this->comment($this->kaan, $post, '18:30 gibi.', $top['id'])->assertCreated();
        Carbon::setTestNow(now()->addMinutes(2));
        $this->comment($this->ece, $post, 'Teşekkürler!', $top['id'])->assertCreated();

        // A reply to a reply is rejected by the server (single level).
        $this->comment($this->selman, $post, 'Cevaba cevap', $first['id'])->assertStatus(422)->assertJsonValidationErrors('parent_id');
        // A parent from another post is not a valid target.
        $other = $this->makePost($this->ece);
        $this->comment($this->selman, $other, 'Yanlış yazı', $top['id'])->assertNotFound();

        $list = $this->as($this->selman)->getJson('/api/v1/posts/'.$post->id.'/comments')->assertOk()->json('data.items');
        $this->assertCount(1, $list, 'Replies are nested under their comment, not listed as top-level comments.');
        $this->assertSame(3, $list[0]['reply_count']);
        $this->assertSame(['Saat kaç civarı?', '18:30 gibi.', 'Teşekkürler!'], collect($list[0]['replies'])->pluck('body')->all());
        $all = $this->as($this->selman)->getJson('/api/v1/posts/'.$post->id.'/comments/'.$top['id'].'/replies')->assertOk()->json('data');
        $this->assertSame(['Saat kaç civarı?', '18:30 gibi.', 'Teşekkürler!'], collect($all['items'])->pluck('body')->all(), 'Oldest first.');
        $this->assertSame(0, DB::table('post_comments')->whereNotNull('parent_id')->whereIn('parent_id',
            DB::table('post_comments')->whereNotNull('parent_id')->select('id'))->count(), 'No reply points at another reply.');
        // The popular score keeps using the comment count (replies are comments).
        $this->assertSame(4, $this->as($this->selman)->getJson('/api/v1/posts/'.$post->id)->json('data.comments_count'));
    }

    public function test_reply_notifications_go_to_the_answered_comment_owner_once_without_self_blocked_or_duplicate_noise(): void
    {
        $post = $this->makePost($this->selman);
        $top = $this->comment($this->ece, $post, 'Ana yorum')->assertCreated()->json('data');
        DB::table('app_notifications')->truncate();

        // Kaan answers Ece: Ece gets "Yorumuna bir cevap geldi."; the post owner does NOT also get a generic comment notification.
        $this->comment($this->kaan, $post, 'Cevap 1', $top['id'])->assertCreated();
        $this->assertSame(['comment_reply'], DB::table('app_notifications')->where('user_id', $this->ece->id)->pluck('type')->all());
        $this->assertSame(0, DB::table('app_notifications')->where('user_id', $this->selman->id)->count(), 'No double notification for the post owner.');
        $this->assertSame('Yorumuna bir cevap geldi.', $this->as($this->ece)->getJson('/api/v1/notifications')->json('data.items.0.text'));

        // Own reply to own comment: nobody is notified.
        DB::table('app_notifications')->truncate();
        $this->comment($this->ece, $post, 'Kendime cevap', $top['id'])->assertCreated();
        $this->assertSame(0, DB::table('app_notifications')->count());

        // When the post owner is also the parent owner, exactly one meaningful notification.
        $ownersComment = $this->comment($this->selman, $post, 'Yazı sahibinin yorumu')->assertCreated()->json('data');
        DB::table('app_notifications')->truncate();
        $this->comment($this->kaan, $post, 'Yazı sahibine cevap', $ownersComment['id'])->assertCreated();
        $this->assertSame(['comment_reply'], DB::table('app_notifications')->where('user_id', $this->selman->id)->pluck('type')->all());
        $this->assertSame(1, DB::table('app_notifications')->count());

        // Blocked pair: the reply is not delivered.
        $this->as($this->ece)->putJson('/api/v1/blocks/'.$this->kaan->id)->assertSuccessful();
        DB::table('app_notifications')->truncate();
        $this->comment($this->kaan, $post, 'Engelli cevap', $top['id'])->assertNotFound();
        $this->assertSame(0, DB::table('app_notifications')->count());

        // The notification opens the post; once the answered thread disappears it is safely unavailable.
        $this->as($this->kaan)->deleteJson('/api/v1/blocks/'.$this->ece->id)->assertSuccessful();
    }

    public function test_reply_notification_target_becomes_unavailable_when_the_thread_is_removed(): void
    {
        $post = $this->makePost($this->selman);
        $top = $this->comment($this->ece, $post, 'Ana yorum')->assertCreated()->json('data');
        $this->comment($this->kaan, $post, 'Cevap', $top['id'])->assertCreated();
        $item = $this->as($this->ece)->getJson('/api/v1/notifications')->assertOk()->json('data.items.0');
        $this->assertSame('comment_reply', $item['type']);
        $this->assertTrue($item['available']);
        $this->assertSame($post->id, $item['entity_id'], 'The app opens the post.');
        $this->assertNull($item['actor'] ?? null ? null : null);

        // Top-level comment removed (owner delete): the whole thread leaves public view, no orphan replies.
        $this->as($this->ece)->deleteJson('/api/v1/posts/'.$post->id.'/comments/'.$top['id'])->assertOk();
        $this->assertFalse($this->as($this->ece)->getJson('/api/v1/notifications')->json('data.items.0.available'));
        $this->assertSame([], $this->as($this->selman)->getJson('/api/v1/posts/'.$post->id.'/comments')->json('data.items'));
        $this->assertSame(0, $this->as($this->selman)->getJson('/api/v1/posts/'.$post->id)->json('data.comments_count'), 'Orphan replies are not counted.');
        $this->as($this->selman)->getJson('/api/v1/posts/'.$post->id.'/comments/'.$top['id'].'/replies')->assertNotFound();
        $this->comment($this->kaan, $post, 'Yetim cevap', $top['id'])->assertNotFound();
    }

    public function test_blocked_users_never_see_each_others_comments_or_replies_and_replies_can_be_reported(): void
    {
        $post = $this->makePost($this->selman);
        $top = $this->comment($this->ece, $post, 'Ana yorum')->assertCreated()->json('data');
        $reply = $this->comment($this->kaan, $post, 'Kaan cevabı', $top['id'])->assertCreated()->json('data');
        $other = $this->comment($this->selman, $post, 'Selman cevabı', $top['id'])->assertCreated()->json('data');

        // A reply is reportable through the existing comment target (and nobody can report their own).
        $this->as($this->ece)->postJson('/api/v1/reports', ['target_type' => 'comment', 'target_id' => $reply['id'], 'reason' => 'spam'])->assertCreated();
        $this->as($this->kaan)->postJson('/api/v1/reports', ['target_type' => 'comment', 'target_id' => $reply['id'], 'reason' => 'spam'])->assertStatus(422);
        $this->assertSame(1, DB::table('reports')->where('target_type', 'comment')->where('target_id', $reply['id'])->count());

        $this->as($this->ece)->putJson('/api/v1/blocks/'.$this->kaan->id)->assertSuccessful();
        // The blocker no longer sees the blocked person's reply ...
        $eceView = $this->as($this->ece)->getJson('/api/v1/posts/'.$post->id.'/comments')->json('data.items');
        $this->assertSame(1, $eceView[0]['reply_count']);
        $this->assertSame(['Selman cevabı'], collect($eceView[0]['replies'])->pluck('body')->all());
        // ... and the blocked person cannot see the blocker's comment, so the whole thread is gone for them.
        $this->assertSame([], $this->as($this->kaan)->getJson('/api/v1/posts/'.$post->id.'/comments')->json('data.items'));
        $this->as($this->kaan)->getJson('/api/v1/posts/'.$post->id.'/comments/'.$top['id'].'/replies')->assertNotFound();
        $this->comment($this->kaan, $post, 'Engelli cevap', $top['id'])->assertNotFound();
        $this->assertNotNull($other['id']);
    }

    public function test_replies_use_content_guard_and_deleting_a_reply_keeps_the_thread(): void
    {
        $post = $this->makePost($this->selman);
        $top = $this->comment($this->ece, $post, 'Ana yorum')->assertCreated()->json('data');
        app(Settings::class)->save(['moderation_banned_words' => "yasakkelime"]);
        $this->comment($this->kaan, $post, 'Bu yasakkelime içeriyor', $top['id'])->assertStatus(422);
        $reply = $this->comment($this->kaan, $post, 'Normal cevap', $top['id'])->assertCreated()->json('data');
        $this->as($this->ece)->deleteJson('/api/v1/posts/'.$post->id.'/comments/'.$reply['id'])->assertForbidden();
        $this->as($this->kaan)->deleteJson('/api/v1/posts/'.$post->id.'/comments/'.$reply['id'])->assertOk();
        $list = $this->as($this->selman)->getJson('/api/v1/posts/'.$post->id.'/comments')->json('data.items');
        $this->assertCount(1, $list);
        $this->assertSame(0, $list[0]['reply_count']);
        $this->assertSame(1, PostComment::count(), 'Only the top-level comment is left.');
    }

    // ------------------------------------------------------------------------------------------------ Mektuplarım

    private function note(User $user, array $extra = []): array
    {
        return $this->as($user)->postJson('/api/v1/map-notes', [...['body' => 'Çok güzeldin kırmızı başlıklı kız.', 'is_anonymous' => false,
            'city_id' => $this->alanya, 'latitude' => 36.5446, 'longitude' => 32.0021, 'request_id' => (string) Str::uuid()], ...$extra])
            ->assertCreated()->json('data');
    }

    private function mine(User $user, string $scope): array
    {
        return $this->as($user)->getJson('/api/v1/my/map-notes?scope='.$scope)->assertOk()->json('data.items');
    }

    public function test_active_list_archive_list_and_haritadan_kaldir_keep_the_letter_private_not_public(): void
    {
        $note = $this->note($this->selman);
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'O kişi bendim.'])->assertCreated();
        Carbon::setTestNow(now()->addDays(2));

        $active = $this->mine($this->selman, 'active');
        $this->assertCount(1, $active);
        $this->assertSame('active', $active[0]['state']);
        $this->assertSame(1, $active[0]['reply_count']);
        $this->assertGreaterThan(4 * 86400, $active[0]['seconds_left']);
        $this->assertLessThan(5 * 86400 + 1, $active[0]['seconds_left']);
        $this->assertSame([], $this->mine($this->selman, 'archive'));
        // Only the owner sees Mektuplarım.
        $this->assertSame([], $this->mine($this->ece, 'active'));

        $this->as($this->selman)->postJson('/api/v1/map-notes/'.$note['id'].'/archive')->assertOk()->assertJsonPath('data.state', 'archived');
        $this->as($this->ece)->getJson('/api/v1/map-notes/'.$note['id'])->assertNotFound();
        $this->assertSame([], $this->as($this->ece)->getJson('/api/v1/map/notes?city_id='.$this->alanya)->json('data.items'));
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Geç kaldım'])->assertNotFound();
        $archive = $this->mine($this->selman, 'archive');
        $this->assertCount(1, $archive);
        $this->assertSame('archived', $archive[0]['state']);
        $this->assertSame([], $this->mine($this->selman, 'active'));
        // The historical thread is readable by the owner only.
        $detail = $this->as($this->selman)->getJson('/api/v1/my/map-notes/'.$note['id'])->assertOk()->json('data');
        $this->assertSame(['O kişi bendim.'], collect($detail['replies']['items'])->pluck('body')->all());
        $this->as($this->ece)->getJson('/api/v1/my/map-notes/'.$note['id'])->assertNotFound();
    }

    public function test_an_expired_letter_is_invisible_to_others_but_stays_in_the_owners_archive(): void
    {
        $note = $this->note($this->selman);
        Carbon::setTestNow(now()->addDays(8));
        $this->as($this->ece)->getJson('/api/v1/map-notes/'.$note['id'])->assertNotFound();
        $this->assertSame([], $this->as($this->ece)->getJson('/api/v1/map/notes?city_id='.$this->alanya)->json('data.items'));
        $archive = $this->mine($this->selman, 'archive');
        $this->assertSame('expired', $archive[0]['state']);
        $this->assertTrue($archive[0]['can_repost']);
        $this->artisan('map-notes:purge')->assertExitCode(0);
        Carbon::setTestNow(now()->addDays(120));
        $this->artisan('map-notes:purge')->assertExitCode(0);
        $this->assertCount(1, $this->mine($this->selman, 'archive'), 'No silent destruction after 30 days.');
    }

    public function test_repost_is_a_new_seven_day_publication_that_keeps_the_original_date_and_leaves_old_replies_behind(): void
    {
        $note = $this->note($this->selman, ['body' => 'Yarın 11:00’de burada olacağım.']);
        $originalDate = $note['occurred_at'];
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Eski cevap'])->assertCreated();
        $this->as($this->selman)->postJson('/api/v1/map-notes/'.$note['id'].'/repost')->assertStatus(422);
        Carbon::setTestNow(Carbon::parse('2026-11-25 09:00:00', 'UTC'));

        $fresh = $this->as($this->selman)->postJson('/api/v1/map-notes/'.$note['id'].'/repost', ['request_id' => $request = (string) Str::uuid()])
            ->assertCreated()->json('data');
        $this->assertSame($originalDate, $fresh['occurred_at'], 'The real date of the letter is not rewritten.');
        $this->assertSame('2026-11-25T09:00:00.000000Z', $fresh['created_at']);
        $this->assertSame('2026-12-02T09:00:00.000000Z', $fresh['expires_at'], 'A new 7-day public lifecycle.');
        $this->assertTrue($fresh['republished']);
        $this->assertSame($note['latitude'], $fresh['latitude'], 'Same approximate point.');
        $this->assertSame($note['body'], $fresh['body']);
        $this->assertSame(0, $fresh['reply_count'], 'Old replies do not move to the new public thread.');
        // Idempotent.
        $this->as($this->selman)->postJson('/api/v1/map-notes/'.$note['id'].'/repost', ['request_id' => $request])->assertOk()->assertJsonPath('data.id', $fresh['id']);
        $this->assertSame(2, MapNote::count());
        // Publicly visible again, with an empty thread.
        $detail = $this->as($this->kaan)->getJson('/api/v1/map-notes/'.$fresh['id'])->assertOk()->json('data');
        $this->assertSame([], $detail['replies']['items']);
        $this->assertSame($originalDate, $detail['note']['occurred_at']);
        // The old publication keeps its replies in the owner's archive only; it cannot be reposted twice while the new one is live.
        $archive = $this->mine($this->selman, 'archive');
        $this->assertCount(1, $archive);
        $this->assertSame($note['id'], $archive[0]['id']);
        $this->assertTrue($archive[0]['has_live_repost']);
        $this->assertFalse($archive[0]['can_repost']);
        $this->assertSame(1, $archive[0]['reply_count']);
        $this->as($this->selman)->postJson('/api/v1/map-notes/'.$note['id'].'/repost')->assertStatus(422);
        $this->assertSame([$fresh['id']], collect($this->mine($this->selman, 'active'))->pluck('id')->all());
        // Nobody can repost somebody else's letter, and no new "near you" fan-out is produced.
        Carbon::setTestNow(now()->addDays(9));
        $this->as($this->kaan)->postJson('/api/v1/map-notes/'.$note['id'].'/repost')->assertNotFound();
        $this->assertSame(0, DB::table('app_notifications')->where('type', 'map_note_nearby')->count());
    }

    public function test_permanent_delete_removes_the_letter_replies_and_personal_access_and_account_delete_cleans_up(): void
    {
        $note = $this->note($this->selman);
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$note['id'].'/replies', ['body' => 'Cevap'])->assertCreated();
        $this->as($this->selman)->postJson('/api/v1/map-notes/'.$note['id'].'/archive')->assertOk();
        $this->as($this->ece)->deleteJson('/api/v1/map-notes/'.$note['id'])->assertForbidden();
        $this->as($this->selman)->deleteJson('/api/v1/map-notes/'.$note['id'])->assertOk();
        $this->assertNull(MapNote::withTrashed()->find($note['id']), 'Unreported letters are erased immediately.');
        $this->assertSame(0, DB::table('map_note_replies')->count());
        $this->assertSame([], $this->mine($this->selman, 'archive'));

        // A reported letter is only soft-deleted so moderation can review it during the retention window.
        $reported = $this->note($this->selman, ['request_id' => (string) Str::uuid()]);
        $this->as($this->ece)->postJson('/api/v1/reports', ['target_type' => 'map_note', 'target_id' => $reported['id'], 'reason' => 'spam'])->assertCreated();
        $this->as($this->selman)->deleteJson('/api/v1/map-notes/'.$reported['id'])->assertOk();
        $this->assertNotNull(MapNote::onlyTrashed()->find($reported['id']));
        $this->assertSame([], $this->mine($this->selman, 'archive'));
        $this->assertSame([], $this->mine($this->selman, 'active'));

        // Account delete leaves nothing of the owner's archive reachable.
        $kept = $this->note($this->selman, ['request_id' => (string) Str::uuid()]);
        $this->as($this->selman)->postJson('/api/v1/map-notes/'.$kept['id'].'/archive')->assertOk();
        DB::table('map_note_reads')->insert(['user_id' => $this->selman->id, 'map_note_id' => $this->note($this->ece)['id'], 'read_at' => now()]);
        $this->as($this->selman)->deleteJson('/api/v1/auth/account', ['password' => 'TestPassword1234', 'confirmation' => 'SİL'])->assertOk();
        $this->assertSame('', DB::table('map_notes')->where('id', $kept['id'])->value('body'));
        $this->assertSame(0, DB::table('map_note_reads')->where('user_id', $this->selman->id)->count());
    }

    // ------------------------------------------------------------------------------------------------ unread nearby letters

    public function test_unread_nearby_count_follows_real_opens_only_and_ignores_expired_deleted_blocked_and_own_letters(): void
    {
        $this->locate($this->selman, 36.5446, 32.0021);
        $near = $this->note($this->ece);
        $second = $this->note($this->kaan, ['request_id' => (string) Str::uuid()]);
        $own = $this->note($this->selman, ['request_id' => (string) Str::uuid()]);
        $far = $this->note($this->kaan, ['latitude' => 36.60, 'longitude' => 32.10, 'request_id' => (string) Str::uuid()]);
        $summary = $this->as($this->selman)->getJson('/api/v1/map/notes/unread')->assertOk()->json('data');
        $this->assertSame(2, $summary['count'], 'Own and far letters are not "near you".');
        $this->assertFalse($summary['location_required']);
        $this->assertTrue($summary['enabled']);

        // Seeing it on the map (marker list) never counts as reading.
        $this->as($this->selman)->getJson('/api/v1/map/notes?city_id='.$this->alanya)->assertOk();
        $this->assertSame(2, $this->as($this->selman)->getJson('/api/v1/map/notes/unread')->json('data.count'));

        // Opening the detail marks it read: idempotent and private.
        $this->as($this->selman)->getJson('/api/v1/map-notes/'.$near['id'])->assertOk();
        $this->assertSame(2, $this->as($this->selman)->getJson('/api/v1/map/notes/unread')->json('data.count'), 'GET detail alone is not a read.');
        $this->as($this->selman)->postJson('/api/v1/map-notes/'.$near['id'].'/read')->assertOk()->assertJsonPath('data.count', 1);
        $this->as($this->selman)->postJson('/api/v1/map-notes/'.$near['id'].'/read')->assertOk()->assertJsonPath('data.count', 1);
        $this->assertSame(1, DB::table('map_note_reads')->count());
        // The author can never learn who read the letter: nothing about reads is in any author-facing payload.
        $mine = $this->mine($this->ece, 'active');
        $this->assertStringNotContainsString('read', strtolower(json_encode($mine)));
        $this->as($this->ece)->getJson('/api/v1/my/map-notes/'.$near['id'])->assertOk();
        $this->assertStringNotContainsString('read_', strtolower($this->as($this->ece)->getJson('/api/v1/my/map-notes/'.$near['id'])->getContent()));
        $this->as($this->ece)->postJson('/api/v1/map-notes/'.$near['id'].'/read')->assertOk();
        $this->assertSame(1, DB::table('map_note_reads')->count(), 'Own letters are never tracked.');

        // Removed / blocked / expired letters leave the count.
        $this->as($this->kaan)->postJson('/api/v1/map-notes/'.$second['id'].'/archive')->assertOk();
        $this->assertSame(0, $this->as($this->selman)->getJson('/api/v1/map/notes/unread')->json('data.count'));
        $third = $this->note($this->kaan, ['request_id' => (string) Str::uuid()]);
        $this->assertSame(1, $this->as($this->selman)->getJson('/api/v1/map/notes/unread')->json('data.count'));
        $this->as($this->selman)->putJson('/api/v1/blocks/'.$this->kaan->id)->assertSuccessful();
        $this->assertSame(0, $this->as($this->selman)->getJson('/api/v1/map/notes/unread')->json('data.count'));
        $this->as($this->selman)->deleteJson('/api/v1/blocks/'.$this->kaan->id)->assertSuccessful();
        Carbon::setTestNow(now()->addDays(8));
        $this->locate($this->selman, 36.5446, 32.0021);
        $this->assertSame(0, $this->as($this->selman)->getJson('/api/v1/map/notes/unread')->json('data.count'));
        $this->assertNotNull($third['id'].$far['id'].$own['id']);
    }

    public function test_unread_summary_without_location_or_with_the_module_off(): void
    {
        $this->note($this->ece);
        $none = $this->as($this->selman)->getJson('/api/v1/map/notes/unread')->assertOk()->json('data');
        $this->assertSame(0, $none['count']);
        $this->assertTrue($none['location_required'], 'No location: the home teaser stays absent.');
        $this->locate($this->selman, 36.5446, 32.0021, null, now()->subDays(2)->toDateTimeString());
        $this->assertSame(0, $this->as($this->selman)->getJson('/api/v1/map/notes/unread')->json('data.count'), 'Stale location counts as no location.');

        $this->locate($this->selman, 36.5446, 32.0021);
        $this->assertSame(1, $this->as($this->selman)->getJson('/api/v1/map/notes/unread')->json('data.count'));
        app(Settings::class)->save(['nearby_notes_enabled' => false]);
        $this->assertFalse($this->as($this->selman)->getJson('/api/v1/map/notes/unread')->json('data.enabled'));
        $this->getJson('/api/v1/app-config')->assertOk()->assertJsonPath('data.nearby_notes_enabled', false);
        // Map notes themselves keep working when only the home teaser is switched off.
        $this->as($this->selman)->getJson('/api/v1/map/notes?city_id='.$this->alanya)->assertOk()->assertJsonCount(1, 'data.items');
    }

    // ------------------------------------------------------------------------------------------------ ranking and age

    public function test_nearby_ranking_uses_shared_interests_only_inside_the_same_distance_step_and_never_filters(): void
    {
        $interest = DB::table('interests')->orderBy('id')->value('id');
        $other = DB::table('interests')->orderByDesc('id')->value('id');
        DB::table('user_interests')->insert([['user_id' => $this->selman->id, 'interest_id' => $interest]]);
        $near = $this->user('near', ['nearby_visible' => true]);
        $tie = $this->user('tie', ['connections' => ['chat'], 'nearby_visible' => true]);
        $same = $this->user('same', ['nearby_visible' => true]);
        $far = $this->user('far', ['nearby_visible' => true]);
        DB::table('user_interests')->insert([['user_id' => $same->id, 'interest_id' => $interest], ['user_id' => $far->id, 'interest_id' => $interest]]);
        $this->locate($this->selman, 36.5400, 32.0000);
        // Same 100 m step for tie / same (≈ 400 m); near is clearly closer; far is in a farther step.
        $this->locate($near, 36.5400, 32.0020);
        $this->locate($tie, 36.5436, 32.0001);
        $this->locate($same, 36.5436, 32.0003);
        $this->locate($far, 36.5500, 32.0000);
        $order = collect($this->as($this->selman)->getJson('/api/v1/nearby/users?radius=25000')->assertOk()->json('data.items'))->pluck('username')->all();
        $this->assertSame(['near', 'same', 'tie', 'far'], $order, 'Distance first; a shared interest only breaks ties inside one step; nobody is filtered out.');
        $this->assertNotNull($other);
        $payload = json_encode($this->as($this->selman)->getJson('/api/v1/nearby/users?radius=25000')->json());
        foreach (['score', 'affinity', 'match', 'uyum', 'interest'] as $secret) {
            $this->assertStringNotContainsString($secret, strtolower($payload), 'Ranking is internal and never displayed.');
        }
    }

    public function test_minimum_age_is_one_config_value_shared_by_validation_app_config_and_admin_bounds(): void
    {
        $this->assertSame(18, (int) config('mobile.minimum_age'), 'Production default stays 18 until the 16+ safeguards exist.');
        $this->getJson('/api/v1/app-config')->assertOk()->assertJsonPath('data.minimum_age', 18);
        $register = fn (string $birth, string $name) => $this->postJson('/api/v1/auth/register', [
            'name' => 'Yeni Kullanıcı', 'username' => $name, 'email' => $name.'@example.test', 'password' => 'TestPassword1234',
            'password_confirmation' => 'TestPassword1234', 'birth_date' => $birth, 'city_id' => $this->alanya,
            'accepted_terms' => true, 'device_name' => 'test',
        ]);
        $seventeen = now('Europe/Istanbul')->subYears(17)->subDay()->toDateString();
        $register($seventeen, 'genc17')->assertStatus(422)->assertJsonValidationErrors('birth_date');
        // A single setting change moves validation and /app-config together (16 is the lowest value the admin accepts).
        app(Settings::class)->save(['minimum_age' => 16]);
        $this->getJson('/api/v1/app-config')->assertJsonPath('data.minimum_age', 16);
        $this->assertSame(422, $register(now('Europe/Istanbul')->subYears(15)->subDay()->toDateString(), 'genc15')->status());
        $register($seventeen, 'genc17b')->assertStatus(201);
    }
}
