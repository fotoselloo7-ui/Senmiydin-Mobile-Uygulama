<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\User;
use App\Notifications\Inbox;
use App\Safety\AgeSafety;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Endpoint-bypass audit. Two 17-year-olds build up a complete social history (follows, posts, comments, replies,
 * likes, saves, collections, a chat with a photo, a map note with a reply, an accepted encounter, notifications);
 * one of them then turns 18. From that moment every single read/write endpoint must treat them as strangers
 * in both directions: no alternative route may still show or accept the other band's data.
 */
class AgeBandTransitionTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $city;

    private User $near;   // turns 18 on 2026-11-20

    private User $peer;   // stays 17

    private array $ids = [];

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Carbon::setTestNow(Carbon::parse('2026-11-14 12:00:00', 'UTC'));
        $this->city = City::where('slug', 'alanya')->value('id');
        $this->near = $this->user('near', '2008-11-20');
        $this->peer = $this->user('peer', '2009-03-01');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function user(string $name, string $birth): User
    {
        return User::create(['name' => ucfirst($name).' Test', 'username' => $name, 'email' => $name.'@example.test',
            'birth_date' => $birth, 'password' => 'TestPassword1234', 'city_id' => $this->city,
            'nearby_visible' => true, 'city_discovery' => true, 'active_city_id' => $this->city]);
    }

    private function as(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    private function locate(User $user): void
    {
        DB::table('user_locations')->upsert([['user_id' => $user->id, 'city_id' => $this->city, 'latitude' => 36.5446, 'longitude' => 32.0021,
            'accuracy' => 20, 'recorded_at' => now(), 'visibility' => true, 'created_at' => now(), 'updated_at' => now()]],
            ['user_id'], ['city_id', 'latitude', 'longitude', 'accuracy', 'recorded_at', 'visibility', 'updated_at']);
    }

    private function makePost(User $user, string $body): int
    {
        return $this->as($user)->postJson('/api/v1/posts', ['body' => $body, 'type' => 'moment', 'city_id' => $this->city,
            'visibility' => 'city', 'is_anonymous' => false, 'request_id' => (string) Str::uuid()])->assertCreated()->json('data.id');
    }

    /** Everything the two teens did together while they were allowed to. */
    private function buildHistory(): void
    {
        $this->locate($this->near);
        $this->locate($this->peer);
        $this->as($this->near)->postJson('/api/v1/users/peer/follow')->assertSuccessful();
        $this->as($this->peer)->postJson('/api/v1/users/near/follow')->assertSuccessful();

        $this->ids['nearPost'] = $this->makePost($this->near, 'Near gönderisi');
        $this->ids['peerPost'] = $this->makePost($this->peer, 'Peer gönderisi');
        $this->ids['peerComment'] = $this->as($this->peer)->postJson('/api/v1/posts/'.$this->ids['nearPost'].'/comments',
            ['body' => 'Peer yorumu', 'request_id' => (string) Str::uuid()])->assertCreated()->json('data.id');
        $this->ids['nearReply'] = $this->as($this->near)->postJson('/api/v1/posts/'.$this->ids['peerPost'].'/comments',
            ['body' => 'Near yorumu', 'request_id' => (string) Str::uuid()])->assertCreated()->json('data.id');
        $this->ids['nearOnPeerReply'] = $this->as($this->near)->postJson('/api/v1/posts/'.$this->ids['nearPost'].'/comments',
            ['body' => 'Near yanıtı', 'parent_id' => $this->ids['peerComment'], 'request_id' => (string) Str::uuid()])->assertCreated()->json('data.id');
        $this->as($this->near)->postJson('/api/v1/posts/'.$this->ids['peerPost'].'/like')->assertSuccessful();
        $this->as($this->peer)->postJson('/api/v1/posts/'.$this->ids['nearPost'].'/like')->assertSuccessful();
        $this->as($this->near)->postJson('/api/v1/posts/'.$this->ids['peerPost'].'/save')->assertSuccessful();
        $this->as($this->peer)->postJson('/api/v1/posts/'.$this->ids['nearPost'].'/save')->assertSuccessful();
        $this->as($this->near)->postJson('/api/v1/posts/'.$this->ids['peerPost'].'/comments/'.$this->ids['peerComment'].'/like')->assertStatus(404);
        $this->as($this->near)->postJson('/api/v1/posts/'.$this->ids['nearPost'].'/comments/'.$this->ids['peerComment'].'/like')->assertSuccessful();
        $collection = $this->as($this->near)->postJson('/api/v1/saved-collections', ['name' => 'Favoriler'])->assertCreated()->json('data.id');
        $this->as($this->near)->putJson("/api/v1/saved-collections/$collection/posts/".$this->ids['peerPost'])->assertSuccessful();
        $this->ids['nearCollection'] = $collection;

        // Chat: request, acceptance, a text and a photo each way.
        $this->as($this->near)->postJson('/api/v1/users/'.$this->peer->id.'/messages', ['body' => 'Selam', 'request_id' => (string) Str::uuid()])->assertCreated();
        $this->ids['conversation'] = DB::table('conversations')->value('id');
        $this->as($this->peer)->postJson('/api/v1/conversations/'.$this->ids['conversation'].'/request/accept')->assertSuccessful();
        $this->as($this->peer)->postJson('/api/v1/users/'.$this->near->id.'/messages', ['body' => 'Merhaba', 'request_id' => (string) Str::uuid()])->assertCreated();
        $photo = $this->as($this->peer)->postJson('/api/v1/users/'.$this->near->id.'/messages', [
            'request_id' => (string) Str::uuid(), 'image' => UploadedFile::fake()->image('p.png', 40, 40),
        ])->assertCreated()->json('data.message');
        $this->ids['messageImage'] = $photo['id'];
        $this->ids['nearMessage'] = DB::table('messages')->where('sender_id', $this->near->id)->value('id');
        $this->ids['peerMessage'] = DB::table('messages')->where('sender_id', $this->peer->id)->orderBy('id')->value('id');

        // Map note + reply.
        $note = $this->as($this->near)->postJson('/api/v1/map-notes', ['body' => 'Seni burada gördüm yarın yine buradayım.', 'is_anonymous' => false,
            'city_id' => $this->city, 'latitude' => 36.5446, 'longitude' => 32.0021, 'request_id' => (string) Str::uuid()])->assertCreated()->json('data');
        $this->ids['note'] = $note['id'];
        $this->ids['noteGroup'] = $note['group'];
        $this->ids['reply'] = $this->as($this->peer)->postJson('/api/v1/map-notes/'.$note['id'].'/replies',
            ['body' => 'Ben de oradaydım', 'request_id' => (string) Str::uuid()])->assertCreated()->json('data.id');
        $peerNote = $this->as($this->peer)->postJson('/api/v1/map-notes', ['body' => 'Peer burada not bıraktı bugün.', 'is_anonymous' => false,
            'city_id' => $this->city, 'latitude' => 36.5447, 'longitude' => 32.0022, 'request_id' => (string) Str::uuid()])->assertCreated()->json('data');
        $this->ids['peerNote'] = $peerNote['id'];
        $this->ids['peerNoteGroup'] = $peerNote['group'];

        // Encounter request (peer → near), accepted.
        $this->as($this->peer)->postJson('/api/v1/posts', ['body' => 'Sahilde karşılaştık', 'type' => 'encounter', 'city_id' => $this->city,
            'visibility' => 'city', 'is_anonymous' => false, 'encounter_target_id' => $this->near->id, 'request_id' => (string) Str::uuid()])->assertCreated();
        $this->ids['encounterRequest'] = DB::table('encounter_requests')->value('id');
        $this->ids['encounterPost'] = DB::table('posts')->where('type', 'encounter')->value('id');
        $this->as($this->near)->postJson('/api/v1/encounter-requests/'.$this->ids['encounterRequest'].'/accept')->assertOk();
        $this->ids['encounter'] = DB::table('encounters')->value('id');

        Inbox::add($this->near->id, $this->peer->id, 'follow');
        Inbox::add($this->peer->id, $this->near->id, 'like', $this->ids['nearPost']);
        $this->ids['nearInbox'] = DB::table('app_notifications')->where('user_id', $this->near->id)->value('id');
        $this->ids['peerInbox'] = DB::table('app_notifications')->where('user_id', $this->peer->id)->value('id');
        $this->assertNotNull($this->ids['nearInbox']);
        $this->assertNotNull($this->ids['peerInbox']);
    }

    private function turnEighteen(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-11-21 09:00:00', 'Europe/Istanbul'));
        $this->assertSame('adult', AgeSafety::bandOf($this->near->id));
        $this->assertSame('teen', AgeSafety::bandOf($this->peer->id));
        $this->locate($this->near);
        $this->locate($this->peer);
    }

    public function test_before_the_birthday_the_history_is_fully_visible(): void
    {
        $this->buildHistory();
        $this->as($this->near)->getJson('/api/v1/users/peer')->assertOk();
        $this->as($this->near)->getJson('/api/v1/conversations/'.$this->ids['conversation'])->assertOk();
        $this->as($this->near)->getJson('/api/v1/notifications')->assertOk()->assertJsonPath('data.items.0.actor.username', 'peer');
        $this->as($this->near)->getJson('/api/v1/map-notes/'.$this->ids['peerNote'])->assertOk();
    }

    public function test_after_the_eighteenth_birthday_the_adult_cannot_reach_teen_data_by_any_endpoint(): void
    {
        $this->buildHistory();
        $this->turnEighteen();
        $this->assertNoCrossBandAccess($this->near, $this->peer, 'peer');
    }

    public function test_after_the_eighteenth_birthday_the_teen_cannot_reach_adult_data_by_any_endpoint(): void
    {
        $this->buildHistory();
        $this->turnEighteen();
        $this->assertNoCrossBandAccess($this->peer, $this->near, 'near');
    }

    /** A participant of an already existing request is told "no" (403) or "not found" (404); never success. */
    private function assertDenied(\Illuminate\Testing\TestResponse $response): void
    {
        $this->assertContains($response->getStatusCode(), [403, 404], 'Cross-band action must be refused.');
    }

    /** Every route that could still expose or accept $other's data to $viewer. */
    private function assertNoCrossBandAccess(User $viewer, User $other, string $otherName): void
    {
        $get = fn (string $url) => $this->as($viewer)->getJson($url);
        $otherPost = $other->is($this->near) ? $this->ids['nearPost'] : $this->ids['peerPost'];
        $myPost = $other->is($this->near) ? $this->ids['peerPost'] : $this->ids['nearPost'];
        $otherNote = $other->is($this->near) ? $this->ids['note'] : $this->ids['peerNote'];
        $otherName = ucfirst($otherName).' Test';

        // Profiles, search, follow graph.
        $get('/api/v1/users/'.$other->username)->assertNotFound();
        $get('/api/v1/users/'.$other->username.'/posts')->assertNotFound();
        $get('/api/v1/users/'.$other->username.'/followers')->assertNotFound();
        $get('/api/v1/users/'.$other->username.'/following')->assertNotFound();
        $get('/api/v1/users/'.$other->username.'/encounters')->assertNotFound();
        $this->as($viewer)->postJson('/api/v1/users/'.$other->username.'/follow')->assertNotFound();
        $this->as($viewer)->deleteJson('/api/v1/users/'.$other->username.'/follow')->assertNotFound();
        $get('/api/v1/search?type=users&q='.$other->username)->assertOk()->assertJsonCount(0, 'data.items');
        $get('/api/v1/search?type=users&encounter=1&q='.$other->username)->assertOk()->assertJsonCount(0, 'data.items');
        $this->assertStringNotContainsString($otherName, $get('/api/v1/search?type=users&q=Test')->getContent());

        // Posts, comments, likes, saves, collections.
        $this->assertStringNotContainsString($otherName, $get('/api/v1/feed')->assertOk()->getContent());
        foreach (['new', 'popular', 'following', 'nearby'] as $sort) {
            $this->assertStringNotContainsString($otherName, $get('/api/v1/feed?sort='.$sort)->getContent(), "feed sort=$sort");
        }
        $this->assertStringNotContainsString($otherName, $get('/api/v1/posts/saved')->assertOk()->getContent());
        $get('/api/v1/posts/'.$otherPost)->assertNotFound();
        $get('/api/v1/posts/'.$otherPost.'/comments')->assertNotFound();
        $this->as($viewer)->postJson('/api/v1/posts/'.$otherPost.'/like')->assertNotFound();
        $this->as($viewer)->postJson('/api/v1/posts/'.$otherPost.'/save')->assertNotFound();
        $this->as($viewer)->deleteJson('/api/v1/posts/'.$otherPost.'/like')->assertNotFound();
        $this->as($viewer)->postJson('/api/v1/posts/'.$otherPost.'/comments', ['body' => 'x', 'request_id' => (string) Str::uuid()])->assertNotFound();
        $this->as($viewer)->putJson('/api/v1/posts/'.$otherPost, ['body' => 'hack'])->assertStatus(404);
        $this->as($viewer)->deleteJson('/api/v1/posts/'.$otherPost)->assertStatus(404);
        $get('/api/v1/posts/'.$myPost.'/comments')->assertOk();
        $comments = $get('/api/v1/posts/'.$myPost.'/comments')->getContent();
        $this->assertStringNotContainsString($otherName, $comments, 'The other band\'s comments disappear from my own post.');
        $this->assertStringNotContainsString('Peer yorumu', $comments);
        $this->assertStringNotContainsString('Near yorumu', $comments);
        $this->assertStringNotContainsString('Near yanıtı', $comments);
        if ($viewer->is($this->near)) {
            $get('/api/v1/posts/'.$myPost.'/comments/'.$this->ids['peerComment'].'/replies')->assertNotFound();
            $this->as($viewer)->postJson('/api/v1/posts/'.$myPost.'/comments/'.$this->ids['peerComment'].'/like')->assertNotFound();
            $this->as($viewer)->deleteJson('/api/v1/posts/'.$myPost.'/comments/'.$this->ids['peerComment'])->assertStatus(404);
        } else {
            $this->as($viewer)->postJson('/api/v1/posts/'.$myPost.'/comments/'.$this->ids['nearReply'].'/like')->assertNotFound();
            $this->as($viewer)->deleteJson('/api/v1/posts/'.$myPost.'/comments/'.$this->ids['nearReply'])->assertStatus(404);
        }
        $this->assertStringNotContainsString($otherName, $get('/api/v1/saved-collections')->assertOk()->getContent());
        if ($viewer->is($this->near)) {
            // The adult's own collection still holds the (now teen) post: it must not be listed or be re-addable.
            $this->assertStringNotContainsString('Peer gönderisi', $get('/api/v1/saved-collections/'.$this->ids['nearCollection'].'/posts')->assertOk()->getContent());
            $this->as($viewer)->putJson('/api/v1/saved-collections/'.$this->ids['nearCollection'].'/posts/'.$otherPost)->assertNotFound();
        }

        // Nearby people, map people, map posts.
        $this->assertStringNotContainsString($otherName, $get('/api/v1/nearby/users')->assertOk()->getContent());
        $this->assertStringNotContainsString($other->username, $get('/api/v1/nearby/users?radius=25000')->getContent());
        $this->assertStringNotContainsString($otherName, $get('/api/v1/map/posts?city_id='.$this->city)->assertOk()->getContent());
        $this->assertStringNotContainsString($otherName, $get('/api/v1/location-history')->assertOk()->getContent());

        // Map notes: markers, group, unread, detail, replies, read/reply/repost.
        $markers = $get('/api/v1/map/notes?city_id='.$this->city)->assertOk()->json('data.items');
        $otherText = $other->is($this->near) ? 'Seni burada' : 'Peer burada';
        $this->assertStringNotContainsString($otherText, json_encode($markers));
        $otherGroup = $this->ids[$other->is($this->near) ? 'noteGroup' : 'peerNoteGroup'];
        $this->assertStringNotContainsString($otherText, $get('/api/v1/map/notes/'.$otherGroup)->assertOk()->getContent(), 'group endpoint');
        $get('/api/v1/map/notes/unread')->assertOk();
        $get('/api/v1/map-notes/'.$otherNote)->assertNotFound();
        $get('/api/v1/map-notes/'.$otherNote.'/replies')->assertNotFound();
        $this->as($viewer)->postJson('/api/v1/map-notes/'.$otherNote.'/read')->assertNotFound();
        $this->as($viewer)->postJson('/api/v1/map-notes/'.$otherNote.'/replies', ['body' => 'Merhaba', 'request_id' => (string) Str::uuid()])->assertNotFound();
        $this->as($viewer)->postJson('/api/v1/map-notes/'.$otherNote.'/repost')->assertStatus(404);
        if ($viewer->is($this->near)) {
            $this->as($viewer)->deleteJson('/api/v1/map-note-replies/'.$this->ids['reply'])->assertNotFound();
        }
        $mine = $other->is($this->near) ? 'peerNote' : 'note';
        $this->assertStringNotContainsString('Ben de oradaydım', $get('/api/v1/map-notes/'.$this->ids[$mine].'/replies')->getContent());
        $this->assertStringNotContainsString('Ben de oradaydım', $get('/api/v1/my/map-notes/'.$this->ids[$mine])->getContent(), 'own note detail');

        // Chat: list, detail, messages, peer lookup, image, send, respond, read, delete.
        $this->assertStringNotContainsString($otherName, $get('/api/v1/conversations')->assertOk()->getContent());
        $get('/api/v1/conversations/'.$this->ids['conversation'])->assertNotFound();
        $get('/api/v1/conversations/'.$this->ids['conversation'].'/messages')->assertNotFound();
        $get('/api/v1/users/'.$other->id.'/conversation')->assertNotFound();
        $get('/api/v1/message-images/'.$this->ids['messageImage'])->assertNotFound();
        $this->as($viewer)->postJson('/api/v1/users/'.$other->id.'/messages', ['body' => 'x', 'request_id' => (string) Str::uuid()])->assertNotFound();
        $this->as($viewer)->putJson('/api/v1/conversations/'.$this->ids['conversation'].'/read', ['through' => $this->ids['peerMessage']])->assertNotFound();
        $this->as($viewer)->postJson('/api/v1/conversations/'.$this->ids['conversation'].'/request/accept')->assertNotFound();
        $this->as($viewer)->deleteJson('/api/v1/conversations/'.$this->ids['conversation'].'/messages/'.$this->ids['nearMessage'])->assertStatus(404);
        $unread = $get('/api/v1/unread-counts')->assertOk()->json('data');
        $this->assertSame(0, (int) ($unread['messages'] ?? 0), 'Messages from the other band never raise a badge.');

        // Encounters: requests, detail, actions, featured, public profile.
        $this->assertStringNotContainsString($otherName, $get('/api/v1/encounter-requests')->assertOk()->getContent());
        $this->assertStringNotContainsString($otherName, $get('/api/v1/encounter-requests?inbox=1')->getContent());
        $get('/api/v1/encounter-requests/'.$this->ids['encounterRequest'])->assertNotFound();
        $this->assertDenied($this->as($viewer)->postJson('/api/v1/encounter-requests/'.$this->ids['encounterRequest'].'/accept'));
        $this->assertDenied($this->as($viewer)->postJson('/api/v1/encounter-requests/'.$this->ids['encounterRequest'].'/reject'));
        $this->assertDenied($this->as($viewer)->deleteJson('/api/v1/encounter-requests/'.$this->ids['encounterRequest']));
        $get('/api/v1/encounters/'.$this->ids['encounter'])->assertNotFound();
        $this->assertStringNotContainsString($otherName, $get('/api/v1/encounters/featured')->assertOk()->getContent());
        $this->assertSame(0, (int) $get('/api/v1/encounter-requests/pending-count')->assertOk()->json('data.count'));
        // The requester's own source post may stay readable by its author, but never carries the other band's identity.
        $source = $this->as($viewer)->getJson('/api/v1/posts/'.$this->ids['encounterPost']);
        if ($source->getStatusCode() === 200) {
            $this->assertStringNotContainsString($otherName, $source->getContent());
            $this->assertStringNotContainsString('"'.$other->username.'"', $source->getContent());
        }

        // Notifications created while they were peers.
        $items = $get('/api/v1/notifications')->assertOk()->json('data.items');
        foreach ($items as $item) {
            // Anonymous location notices (no actor) may remain as "unavailable"; nothing may name or open the other band.
            $this->assertNull($item['actor'], 'No actor of the other band is shown.');
            $this->assertFalse($item['available'], 'Cross-band targets are never reachable from the inbox.');
        }
        $inbox = $this->ids[$viewer->is($this->near) ? 'nearInbox' : 'peerInbox'];
        $get('/api/v1/notifications/'.$inbox)->assertNotFound();
        $this->assertSame(count(array_filter($items, fn ($item) => ! $item['read'])), (int) $get('/api/v1/unread-counts')->json('data.notifications'), 'The badge only counts what the list shows.');

        // Blocks list never reveals the other band either; reports against them are not possible.
        $this->as($viewer)->putJson('/api/v1/blocks/'.$other->id)->assertStatus(404);
    }

    public function test_the_boundary_is_exact_in_europe_istanbul_and_uses_the_model_date_cast(): void
    {
        $user = $this->user('birthday', '2008-11-15');
        // 2026-11-14 23:59:59 in Istanbul (= 20:59:59 UTC): 17 years 364 days.
        Carbon::setTestNow(Carbon::parse('2026-11-14 23:59:59', 'Europe/Istanbul'));
        $this->assertSame('teen', AgeSafety::bandOf($user->id));
        $this->assertSame('teen', AgeSafety::band($user->fresh()->birth_date));
        $this->assertTrue(AgeSafety::scope(User::query(), $this->peer->id)->whereKey($user->id)->exists());
        // One second later it is the 18th birthday in Istanbul (2026-11-15 00:00:00 +03:00 = 21:00:00 UTC on the 14th).
        Carbon::setTestNow(Carbon::parse('2026-11-15 00:00:00', 'Europe/Istanbul'));
        $this->assertSame('adult', AgeSafety::bandOf($user->id));
        $this->assertSame('adult', AgeSafety::band($user->fresh()->birth_date), 'The Eloquent date cast must give the same band.');
        $this->assertFalse(AgeSafety::scope(User::query(), $this->peer->id)->whereKey($user->id)->exists());
        // The authenticated-viewer shortcut (a loaded model) agrees with the SQL path.
        $this->as($user)->getJson('/api/v1/profile')->assertJsonPath('data.age_band', 'adult');
        $this->as($user)->getJson('/api/v1/users/near')->assertNotFound();
        $this->as($user)->getJson('/api/v1/search?type=users&q=adult')->assertOk();
    }
}
