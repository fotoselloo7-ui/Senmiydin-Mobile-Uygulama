<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\MapNote;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Sharing outside the app: public ids, share links, the public preview page and the deep-link verification files. */
class PublicShareTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $city;

    private User $ada;

    private User $ece;

    private User $teen;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-11-15 12:00:00', 'UTC'));
        $this->city = City::where('slug', 'alanya')->value('id');
        $make = fn (string $name, string $birth) => User::create(['name' => ucfirst($name).' Test', 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => $birth, 'password' => 'TestPassword1234', 'city_id' => $this->city, 'active_city_id' => $this->city]);
        $this->ada = $make('ada', '1995-01-01');
        $this->ece = $make('ece', '1996-02-02');
        $this->teen = $make('genc', '2010-06-01');
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

    private function makePost(User $author, array $extra = []): Post
    {
        return Post::create(['user_id' => $author->id, 'city_id' => $this->city, 'body' => 'Sahilde yürürken seni gördüm, selam! 🌊', 'type' => 'memory',
            'is_anonymous' => false, 'visibility' => 'city', 'comments_enabled' => true, 'request_id' => (string) Str::uuid(), ...$extra]);
    }

    private function makeNote(User $author, array $extra = []): MapNote
    {
        return MapNote::create(['user_id' => $author->id, 'city_id' => $this->city, 'body' => 'Kırmızı montlu kız, yarın aynı yerde.', 'is_anonymous' => false,
            'approx_latitude' => 36.5446, 'approx_longitude' => 32.0021, 'place_label' => 'Alanya · Yaklaşık bölge', 'content_hash' => Str::random(40),
            'request_id' => (string) Str::uuid(), 'expires_at' => now()->addDays(7), 'occurred_at' => now(), ...$extra]);
    }

    public function test_new_posts_and_notes_get_random_public_ids_unrelated_to_their_row_ids(): void
    {
        $posts = collect(range(1, 5))->map(fn () => $this->makePost($this->ada));
        $ids = $posts->pluck('public_id');
        $this->assertCount(5, $ids->unique());
        foreach ($posts as $post) {
            $this->assertMatchesRegularExpression('/^[a-z0-9]{12}$/', $post->public_id);
            $this->assertNotSame((string) $post->id, $post->public_id);
        }
        $this->assertMatchesRegularExpression('/^[a-z0-9]{12}$/', $this->makeNote($this->ada)->public_id);
    }

    public function test_a_public_adult_post_has_a_share_link_and_a_preview_page_with_open_graph_tags(): void
    {
        $post = $this->makePost($this->ada);
        $feed = $this->as($this->ece)->getJson('/api/v1/posts/'.$post->id)->assertOk()->json('data');
        $this->assertSame(config('website.url').'/p/'.$post->public_id, $feed['share_url']);

        $page = $this->get('/p/'.$post->public_id)->assertOk();
        $page->assertHeader('X-Robots-Tag', 'noindex, nofollow');
        $page->assertSee('Sahilde yürürken seni gördüm', false);
        $page->assertSee('Ada Test', false);
        $page->assertSee('<link rel="canonical" href="'.config('website.url').'/p/'.$post->public_id.'">', false);
        $page->assertSee('property="og:title"', false);
        $page->assertSee('property="og:image"', false);
        $page->assertSee('name="twitter:card"', false);
    }

    public function test_a_shared_post_with_a_photo_previews_that_photo_and_private_or_teen_photos_never_leave(): void
    {
        Storage::fake('local');
        Storage::disk('local')->put('posts/a.jpg', 'fake-jpeg-bytes');
        $post = $this->makePost($this->ada);
        $post->media()->create(['disk' => 'local', 'file_path' => 'posts/a.jpg', 'sort_order' => 0, 'width' => 1080, 'height' => 1350, 'mime_type' => 'image/jpeg']);
        $image = url('/p/'.$post->public_id.'/image');

        $page = $this->get('/p/'.$post->public_id)->assertOk();
        $page->assertSee('<meta property="og:image" content="'.$image.'">', false);
        $page->assertSee('<meta property="og:image:width" content="1080">', false);
        $page->assertSee('<meta property="og:image:height" content="1350">', false);
        $page->assertSee('class="photo"', false);
        $this->get('/p/'.$post->public_id.'/image')->assertOk()->assertHeader('Content-Type', 'image/jpeg');

        $private = $this->makePost($this->ada, ['visibility' => 'private']);
        $private->media()->create(['disk' => 'local', 'file_path' => 'posts/a.jpg', 'sort_order' => 0, 'width' => 1, 'height' => 1, 'mime_type' => 'image/jpeg']);
        $teen = $this->makePost($this->teen);
        $teen->media()->create(['disk' => 'local', 'file_path' => 'posts/a.jpg', 'sort_order' => 0, 'width' => 1, 'height' => 1, 'mime_type' => 'image/jpeg']);
        $this->get('/p/'.$private->public_id.'/image')->assertNotFound();
        $this->get('/p/'.$teen->public_id.'/image')->assertNotFound();
        $this->get('/p/'.$this->makePost($this->ada)->public_id.'/image')->assertNotFound();
    }

    public function test_the_page_follows_accept_language_and_the_lang_parameter(): void
    {
        $post = $this->makePost($this->ada);
        $this->withHeaders(['Accept-Language' => 'en-US'])->get('/p/'.$post->public_id)->assertSee('Open in SenMiydin?', false);
        $this->get('/p/'.$post->public_id.'?lang=tr')->assertSee('SenMiydin?&#039;de Aç', false);
        $this->get('/p/'.$post->public_id.'?lang=en')->assertSee('Open in SenMiydin?', false);
    }

    public function test_an_anonymous_post_never_shows_who_wrote_it_on_the_page_or_in_the_link_metadata(): void
    {
        $post = $this->makePost($this->ada, ['is_anonymous' => true, 'body' => 'İtiraf: bu bir test.']);
        $html = $this->get('/p/'.$post->public_id)->assertOk()->getContent();
        $this->assertStringContainsString('Anonim', $html);
        $this->assertStringNotContainsString('Ada Test', $html);
        $this->assertStringNotContainsString('@ada', $html);
        $this->assertStringNotContainsString('ada@example.test', $html);
        $this->assertStringNotContainsString('"'.$this->ada->id.'"', $html);
    }

    public function test_private_removed_moderated_unconfirmed_and_teen_content_is_a_plain_404_and_has_no_share_link(): void
    {
        $private = $this->makePost($this->ada, ['visibility' => 'private']);
        $moderated = $this->makePost($this->ada);
        DB::table('posts')->where('id', $moderated->id)->update(['moderated_at' => now()]);
        $removed = $this->makePost($this->ada);
        $removed->delete();
        $teen = $this->makePost($this->teen);
        foreach ([$private, $moderated, $removed, $teen] as $post) {
            $this->get('/p/'.$post->public_id)->assertNotFound();
        }
        $this->assertNull($this->as($this->ece)->getJson('/api/v1/posts/'.$private->id)->json('data.share_url'));
        $this->assertNotNull($this->as($this->teen)->getJson('/api/v1/posts/'.$teen->id)->assertOk()->json('data.id'));
        $this->assertNull($this->as($this->teen)->getJson('/api/v1/posts/'.$teen->id)->json('data.share_url'), 'Teen content never leaves the app.');
        $this->get('/p/aaaaaaaaaaaa')->assertNotFound();
        $this->get('/p/not-valid')->assertNotFound();
    }

    public function test_an_encounter_story_is_shareable_only_once_the_other_person_confirmed_and_it_is_published(): void
    {
        $post = $this->makePost($this->ada, ['type' => 'encounter'])->load('author');
        $post->encounter_id = 1;
        $post->story_status = Post::STORY_PENDING;
        $this->assertFalse(\App\Sharing\PublicShare::postShareable($post));
        $post->story_status = Post::STORY_REJECTED;
        $this->assertFalse(\App\Sharing\PublicShare::postShareable($post));
        $post->story_status = Post::STORY_PUBLISHED;
        $this->assertTrue(\App\Sharing\PublicShare::postShareable($post));
    }

    public function test_an_active_map_note_is_shareable_with_only_the_approximate_area_never_a_coordinate(): void
    {
        $note = $this->makeNote($this->ada);
        $json = $this->as($this->ece)->getJson('/api/v1/map-notes/'.$note->id)->assertOk()->json('data.note');
        $this->assertSame(config('website.url').'/n/'.$note->public_id, $json['share_url']);
        $html = $this->get('/n/'.$note->public_id)->assertOk()->getContent();
        $this->assertStringContainsString('Kırmızı montlu kız', $html);
        $this->assertStringContainsString('Alanya · Yaklaşık bölge', $html);
        $this->assertStringNotContainsString('36.54', $html);
        $this->assertStringNotContainsString('32.00', $html);
    }

    public function test_an_anonymous_map_note_shows_no_identity(): void
    {
        $note = $this->makeNote($this->ada, ['is_anonymous' => true]);
        $html = $this->get('/n/'.$note->public_id)->assertOk()->getContent();
        $this->assertStringContainsString('Anonim', $html);
        $this->assertStringNotContainsString('Ada Test', $html);
        $this->assertStringNotContainsString('@ada', $html);
    }

    public function test_expired_archived_moderated_deleted_and_teen_notes_have_no_public_link(): void
    {
        $expired = $this->makeNote($this->ada, ['expires_at' => now()->subMinute()]);
        $archived = $this->makeNote($this->ada);
        DB::table('map_notes')->where('id', $archived->id)->update(['archived_at' => now()]);
        $moderated = $this->makeNote($this->ada);
        DB::table('map_notes')->where('id', $moderated->id)->update(['moderated_at' => now()]);
        $deleted = $this->makeNote($this->ada);
        $deleted->delete();
        $teen = $this->makeNote($this->teen);
        foreach ([$expired, $archived, $moderated, $deleted, $teen] as $note) {
            $this->get('/n/'.$note->public_id)->assertNotFound();
        }
        $mine = $this->as($this->ada)->getJson('/api/v1/my/map-notes?scope=archive')->assertOk()->json('data.items');
        foreach ($mine as $row) {
            $this->assertNull($row['share_url'], 'A letter taken off the map has no public link.');
        }
    }

    public function test_the_app_resolves_a_link_to_its_own_object_and_blocked_or_unknown_links_are_404(): void
    {
        $post = $this->makePost($this->ada);
        $note = $this->makeNote($this->ada);
        $this->as($this->ece)->getJson('/api/v1/share-links/'.$post->public_id)->assertOk()->assertJsonPath('data', ['type' => 'post', 'id' => $post->id]);
        $this->as($this->ece)->getJson('/api/v1/share-links/'.$note->public_id)->assertOk()->assertJsonPath('data', ['type' => 'map_note', 'id' => $note->id]);
        $this->as($this->ece)->getJson('/api/v1/share-links/zzzzzzzzzzzz')->assertNotFound();
        DB::table('user_blocks')->insert(['blocker_id' => $this->ada->id, 'blocked_id' => $this->ece->id, 'created_at' => now()]);
        $this->as($this->ece)->getJson('/api/v1/share-links/'.$post->public_id)->assertNotFound();
        $this->app['auth']->forgetGuards();
        $this->flushHeaders();
        $this->getJson('/api/v1/share-links/'.$post->public_id)->assertUnauthorized();
    }

    public function test_deep_link_files_are_only_served_with_real_configuration(): void
    {
        $this->get('/.well-known/assetlinks.json')->assertNotFound();
        $this->get('/.well-known/apple-app-site-association')->assertNotFound();

        config(['deployment.android_app_link_sha256' => 'AA:BB:CC, DD:EE:FF', 'deployment.apple_team_id' => 'ABCDE12345']);
        $links = $this->get('/.well-known/assetlinks.json')->assertOk()->json();
        $this->assertSame('com.senmiydin.app', $links[0]['target']['package_name']);
        $this->assertSame(['AA:BB:CC', 'DD:EE:FF'], $links[0]['target']['sha256_cert_fingerprints']);
        $apple = $this->get('/.well-known/apple-app-site-association')->assertOk()->json();
        $this->assertSame(['ABCDE12345.com.senmiydin.app'], $apple['applinks']['details'][0]['appIDs']);
    }

    public function test_app_ads_txt_is_served_only_for_a_real_admob_publisher_id(): void
    {
        config(['website.admob_publisher_id' => null]);
        $this->get('/app-ads.txt')->assertNotFound();
        config(['website.admob_publisher_id' => 'pub-not-valid']);
        $this->get('/app-ads.txt')->assertNotFound();
        config(['website.admob_publisher_id' => 'pub-3008758416596112']);
        $response = $this->get('/app-ads.txt')->assertOk();
        $this->assertStringStartsWith('text/plain', $response->headers->get('Content-Type'));
        $this->assertSame("google.com, pub-3008758416596112, DIRECT, f08c47fec0942fa0
", $response->getContent());
    }
}
