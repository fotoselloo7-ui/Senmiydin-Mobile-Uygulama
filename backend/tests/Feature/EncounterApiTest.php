<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class EncounterApiTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private int $city;

    private User $requester;

    private User $target;

    private User $viewer;

    protected function setUp(): void
    {
        parent::setUp();
        $this->city = City::where('slug', 'alanya')->value('id');
        $this->requester = $this->user('deniz', 'Deniz Kaya');
        $this->target = $this->user('elif', 'Elif Aydın');
        $this->viewer = $this->user('cem', 'Cem Elif');
    }

    public function test_tag_search_validates_and_ranks_eligible_people(): void
    {
        $this->user('elifuzun', 'Bir Kullanıcı');
        $this->user('elifpasif', 'Elif Pasif')->forceFill(['account_status' => 'deleted'])->save();
        $this->asUser($this->requester)->getJson('/api/v1/search?type=users&encounter=1&q=e')->assertUnprocessable();
        $this->getJson('/api/v1/search?type=users&encounter=1&q=deniz')->assertJsonCount(0, 'data.items');
        $this->getJson('/api/v1/search?type=users&encounter=1&q=elif')
            ->assertOk()->assertJsonCount(3, 'data.items')
            ->assertJsonPath('data.items.0.username', 'elif')->assertJsonPath('data.items.1.username', 'elifuzun')
            ->assertJsonPath('data.items.2.username', 'cem')->assertJsonMissingPath('data.items.0.email');

        for ($i = 0; $i < 22; $i++) {
            $this->user('elif'.$i, 'Bir Kullanıcı');
        }
        $this->getJson('/api/v1/search?type=users&encounter=1&q=%40elif')
            ->assertOk()->assertJsonCount(20, 'data.items')->assertJsonPath('data.next_page', null)
            ->assertJsonPath('data.items.0.username', 'elif');
    }

    public function test_invalid_tags_leave_no_posts_or_requests(): void
    {
        $inactive = $this->user('pasif', 'Pasif Hesap');
        $inactive->forceFill(['account_status' => 'deleted'])->save();
        $this->asUser($this->requester);
        foreach ([
            ['encounter_target_id' => $this->requester->id],
            ['encounter_target_id' => $inactive->id],
            ['encounter_target_id' => $this->target->id, 'is_anonymous' => true],
            ['encounter_target_id' => $this->target->id, 'visibility' => 'private'],
        ] as $fields) {
            $this->postJson('/api/v1/posts', $this->draft($fields))->assertUnprocessable();
        }
        $this->assertDatabaseCount('posts', 0);
        $this->assertDatabaseCount('encounter_requests', 0);
    }

    public function test_pending_tag_is_idempotent_and_private_to_both_accounts(): void
    {
        $fields = $this->draft(['encounter_target_id' => $this->target->id]);
        $this->asUser($this->requester);
        $post = $this->postJson('/api/v1/posts', $fields)->assertCreated()->json('data');
        $id = $post['encounter_request_id'];
        $this->postJson('/api/v1/posts', $fields)->assertOk()->assertJsonPath('data.encounter_request_id', $id);
        $this->assertDatabaseCount('posts', 1);
        $this->assertDatabaseCount('encounter_requests', 1);

        $path = "/api/v1/encounter-requests/$id";
        $this->getJson($path)->assertOk()->assertJsonPath('data.outgoing', true);
        $this->postJson("$path/accept")->assertForbidden();
        $this->asUser($this->target)->getJson('/api/v1/encounter-requests?inbox=1')
            ->assertOk()->assertJsonPath('data.items.0.id', $id)->assertJsonPath('data.items.0.outgoing', false);
        $this->getJson("$path")->assertOk()->assertJsonPath('data.source.id', $post['id']);
        $this->getJson('/api/v1/encounter-requests/pending-count')->assertJsonPath('data.count', 1);
        $this->deleteJson($path)->assertForbidden();

        $this->asUser($this->viewer)->getJson($path)->assertForbidden();
        $this->postJson("$path/accept")->assertForbidden();
        $this->getJson('/api/v1/encounter-requests')->assertJsonCount(0, 'data.items');
        $this->getJson('/api/v1/posts/'.$post['id'])->assertOk()
            ->assertJsonPath('data.encounter_request_id', null)
            ->assertJsonPath('data.encounter_confirmed', false)
            ->assertJsonMissing(['username' => 'elif']);
    }

    public function test_only_the_target_confirms_once_and_updates_both_counts(): void
    {
        $post = $this->tag();
        $path = '/api/v1/encounter-requests/'.$post['encounter_request_id'];
        $this->asUser($this->target);
        $id = $this->postJson("$path/accept")->assertOk()->assertJsonPath('data.status', 'accepted')->json('data.encounter_id');
        $this->postJson("$path/accept")->assertOk()->assertJsonPath('data.encounter_id', $id);
        $this->postJson("$path/reject")->assertConflict();
        $this->getJson('/api/v1/encounter-requests/pending-count')->assertJsonPath('data.count', 0);
        $this->assertDatabaseCount('encounters', 1);

        $this->asUser($this->viewer)->getJson("/api/v1/encounters/$id")->assertForbidden();
        foreach (['deniz', 'elif'] as $username) {
            $this->getJson("/api/v1/users/$username")->assertJsonPath('data.encounter_count', 1);
            $this->getJson("/api/v1/users/$username/encounters")->assertJsonCount(0, 'data.items');
        }
        $this->getJson('/api/v1/posts/'.$post['id'])->assertJsonPath('data.encounter_confirmed', true)
            ->assertJsonMissing(['username' => 'elif']);
    }

    public function test_reject_cancel_and_source_deletion_close_requests_without_confirmation(): void
    {
        $rejected = $this->tag();
        $cancelled = $this->tag();
        $deleted = $this->tag();
        $requestPath = fn (array $post) => '/api/v1/encounter-requests/'.$post['encounter_request_id'];
        $this->asUser($this->target)->postJson($requestPath($rejected).'/reject')
            ->assertOk()->assertJsonPath('data.status', 'rejected');
        $this->asUser($this->requester)->deleteJson($requestPath($cancelled))
            ->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->deleteJson('/api/v1/posts/'.$deleted['id'])->assertOk();

        $this->asUser($this->target);
        foreach ([$rejected, $cancelled, $deleted] as $closed) {
            $this->postJson($requestPath($closed).'/accept')->assertConflict();
        }
        $this->getJson($requestPath($deleted))->assertJsonPath('data.source', null)->assertJsonPath('data.status', 'cancelled');
        $this->getJson('/api/v1/encounter-requests?status=closed')->assertJsonCount(3, 'data.items');
        $this->assertDatabaseCount('encounters', 0);
    }

    public function test_joint_story_is_private_until_the_partner_approves_its_current_revision(): void
    {
        Storage::fake(config('mobile.post_media_disk'));
        $source = $this->tag();
        $invitation = $source['encounter_request_id'];
        $id = $this->asUser($this->target)->postJson("/api/v1/encounter-requests/$invitation/accept")->json('data.encounter_id');
        $review = "/api/v1/encounters/$id/story";
        $draft = $this->draft(['encounter_id' => $id, 'story_title' => 'Sahilde ikinci merhaba']);

        $this->asUser($this->viewer)->postJson('/api/v1/posts', $draft)->assertForbidden();
        $story = $this->asUser($this->target)->postJson('/api/v1/posts', [...$draft, 'media' => [
            UploadedFile::fake()->image('first.jpg', 40, 50),
            UploadedFile::fake()->image('second.jpg', 60, 70),
        ]])->assertCreated()->assertJsonPath('data.story_status', 'pending')->assertJsonPath('data.story_revision', 1)
            ->assertJsonPath('data.media.0.width', 40)->assertJsonPath('data.media.1.height', 70)->json('data');
        $path = '/api/v1/posts/'.$story['id'];
        $media = $story['media'][0]['url'];
        $this->postJson('/api/v1/posts', $this->draft(['encounter_id' => $id, 'story_title' => 'Bir daha']))->assertConflict();
        $this->postJson("$review/approve", ['revision' => 1])->assertForbidden();
        $this->get($media)->assertOk();
        $this->getJson('/api/v1/users/elif/posts')->assertJsonCount(0, 'data.items');

        $this->asUser($this->viewer)->getJson($path)->assertNotFound();
        $this->get($media)->assertNotFound();
        $this->postJson("$review/approve", ['revision' => 1])->assertForbidden();
        $this->getJson('/api/v1/encounters/featured')->assertJsonCount(0, 'data.items');
        $this->getJson('/api/v1/feed')->assertJsonCount(1, 'data.items');

        $this->asUser($this->requester)->get($media)->assertOk();
        $this->getJson('/api/v1/encounter-requests?inbox=1')->assertJsonPath('data.items.0.story.story_status', 'pending');
        $this->getJson('/api/v1/encounter-requests/pending-count')->assertJsonPath('data.count', 1);
        $this->postJson("$path/comments", ['body' => 'Henüz erken'])->assertForbidden();
        $this->postJson("$review/reject", ['revision' => 1])->assertOk()->assertJsonPath('data.story.story_status', 'rejected');
        $this->asUser($this->target)->getJson('/api/v1/encounter-requests?inbox=1')
            ->assertJsonPath('data.items.0.story.story_status', 'rejected');
        $this->putJson($review, ['revision' => 1, 'title' => 'Sahilde yeniden', 'body' => 'İkinci yürüyüş'])
            ->assertOk()->assertJsonPath('data.story.story_revision', 2);
        $this->asUser($this->requester)->postJson("$review/approve", ['revision' => 1])->assertConflict();
        $this->postJson("$review/approve", ['revision' => 2])->assertOk()->assertJsonPath('data.story.story_status', 'published');
        $this->getJson('/api/v1/encounter-requests/pending-count')->assertJsonPath('data.count', 0);

        $this->asUser($this->viewer)->getJson($path)->assertOk()->assertJsonPath('data.story_title', 'Sahilde yeniden')
            ->assertJsonPath('data.story_participants.0.username', 'deniz')
            ->assertJsonPath('data.story_participants.1.username', 'elif')
            ->assertJsonMissingPath('data.story_participants.1.email')->assertJsonCount(2, 'data.media');
        $this->get($media)->assertOk();
        $this->getJson('/api/v1/encounters/featured')->assertJsonPath('data.items.0.id', $story['id']);
        $this->getJson('/api/v1/feed?sort=new')->assertJsonPath('data.items.0.id', $story['id']);
        $this->getJson('/api/v1/users/deniz/encounters')->assertJsonPath('data.items.0.id', $story['id']);
        $this->getJson('/api/v1/users/elif/encounters')->assertJsonPath('data.items.0.id', $story['id']);
        $this->postJson("$path/like")->assertOk();
        $this->postJson("$path/save")->assertOk();
        $this->postJson("$path/comments", ['body' => 'Ne güzel!'])->assertCreated();
        $this->asUser($this->requester)->deleteJson($path)->assertOk();
        $this->asUser($this->viewer)->getJson('/api/v1/encounters/featured')->assertJsonCount(0, 'data.items');
        $this->get($media)->assertNotFound();
    }

    public function test_avatar_identity_is_separate_from_empty_story_media_in_feed_and_featured(): void
    {
        $this->assertStoryMedia(0);
    }

    public function test_only_two_actual_story_attachments_are_serialized_in_feed_and_featured(): void
    {
        $this->assertStoryMedia(2);
    }

    private function assertStoryMedia(int $count): void
    {
        Storage::fake(config('mobile.post_media_disk'));
        foreach ([$this->requester, $this->target] as $person) {
            $person->forceFill(['avatar' => 'avatars/'.Str::uuid().'.jpg'])->save();
        }
        $source = $this->tag();
        $request = $source['encounter_request_id'];
        $encounter = $this->asUser($this->target)->postJson("/api/v1/encounter-requests/$request/accept")
            ->assertOk()->json('data.encounter_id');
        $draft = $this->draft(['encounter_id' => $encounter, 'story_title' => 'Sahilde ikinci merhaba']);
        if ($count) {
            $draft['media'] = [UploadedFile::fake()->image('coast.jpg', 80, 60), UploadedFile::fake()->image('sunset.jpg', 90, 70)];
        }
        $story = $this->postJson('/api/v1/posts', $draft)->assertCreated()->json('data');
        $this->asUser($this->requester)->postJson("/api/v1/encounters/$encounter/story/approve", ['revision' => 1])->assertOk();
        $this->asUser($this->viewer);
        foreach (['/api/v1/encounters/featured', '/api/v1/feed?sort=new'] as $path) {
            $item = collect($this->getJson($path)->assertOk()->json('data.items'))->firstWhere('id', $story['id']);
            $this->assertNotNull($item);
            $this->assertCount(2, $item['story_participants']);
            $this->assertNotEmpty($item['story_participants'][0]['avatar']);
            $this->assertNotEmpty($item['story_participants'][1]['avatar']);
            $this->assertCount($count, $item['media']);
            foreach ($item['media'] as $media) {
                $this->assertStringContainsString('/api/v1/post-media/', $media['url']);
                foreach ($item['story_participants'] as $participant) {
                    $this->assertNotSame($participant['avatar'], $media['url']);
                }
            }
        }
    }

    private function user(string $username, string $name): User
    {
        return User::create([
            'username' => $username, 'name' => $name, 'email' => $username.'@example.test',
            'city_id' => $this->city, 'birth_date' => '1998-04-12', 'password' => 'DenemeParola123',
        ]);
    }

    private function draft(array $overrides = []): array
    {
        return [
            'body' => 'Sahilde bir anı', 'type' => 'encounter', 'city_id' => $this->city,
            'visibility' => 'city', 'is_anonymous' => false, 'request_id' => (string) Str::uuid(),
            ...$overrides,
        ];
    }

    private function tag(): array
    {
        return $this->asUser($this->requester)->postJson('/api/v1/posts', $this->draft([
            'encounter_target_id' => $this->target->id,
        ]))->assertCreated()->json('data');
    }

    private function asUser(User $user): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken('test')->plainTextToken);
    }
}
