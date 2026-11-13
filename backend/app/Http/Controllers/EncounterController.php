<?php

namespace App\Http\Controllers;

use App\Notifications\Inbox;
use App\Safety\Blocks;

use App\Http\ApiResponse;
use App\Http\Resources\EncounterRequestResource;
use App\Http\Resources\PostResource;
use App\Models\Encounter;
use App\Models\EncounterRequest;
use App\Models\Post;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class EncounterController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'status' => ['sometimes', Rule::in(['pending', 'accepted', 'closed'])],
            'direction' => ['sometimes', Rule::in(['incoming', 'outgoing'])],
            'inbox' => ['sometimes', 'boolean'],
        ]);
        $viewer = $request->user();
        $items = $this->requests($viewer)->participant($viewer->id);
        match ($data['status'] ?? null) {
            'pending' => $items->where('status', EncounterRequest::PENDING),
            'accepted' => $items->where('status', EncounterRequest::ACCEPTED),
            'closed' => $items->whereIn('status', [EncounterRequest::REJECTED, EncounterRequest::CANCELLED]),
            default => null,
        };
        match ($data['direction'] ?? null) {
            'incoming' => $items->where('target_user_id', $viewer->id),
            'outgoing' => $items->where('requester_id', $viewer->id),
            default => null,
        };
        if ($data['inbox'] ?? false) {
            $items->where(fn (Builder $inbox) => $inbox->where(fn (Builder $incoming) =>
                $incoming->where('target_user_id', $viewer->id)->where('status', EncounterRequest::PENDING))
                ->orWhere(fn (Builder $outgoing) => $outgoing->where('requester_id', $viewer->id)
                    ->whereIn('status', [EncounterRequest::ACCEPTED, EncounterRequest::REJECTED]))
                ->orWhereHas('encounter.story', fn (Builder $story) => $story
                    ->where(fn (Builder $pending) => $pending->where('story_status', Post::STORY_PENDING)
                        ->where('user_id', '<>', $viewer->id))
                    ->orWhere(fn (Builder $result) => $result->where('user_id', $viewer->id)
                        ->whereIn('story_status', [Post::STORY_PUBLISHED, Post::STORY_REJECTED]))));
        }

        return ApiResponse::page($items->orderByRaw('COALESCE(responded_at, created_at) DESC')
            ->orderByDesc('id')->simplePaginate(20), EncounterRequestResource::class);
    }

    public function pendingCount(Request $request): JsonResponse
    {
        $id = $request->user()->id;
        $requests = Blocks::exclude(EncounterRequest::where('target_user_id', $id), $id, 'encounter_requests.requester_id')->where('status', EncounterRequest::PENDING)->count();
        $stories = Post::where('story_status', Post::STORY_PENDING)->where('user_id', '<>', $id)
            ->whereHas('jointEncounter.invitation', fn (Builder $pair) => $pair->participant($id)->activePair())->count();

        return ApiResponse::ok(['count' => $requests + $stories]);
    }

    public function showRequest(Request $request, int $invitation): JsonResponse
    {
        $item = $this->requests($request->user())->findOrFail($invitation);
        Gate::authorize('view', $item);

        return ApiResponse::ok(new EncounterRequestResource($item));
    }

    public function show(Request $request, int $encounter): JsonResponse
    {
        $entry = Encounter::with('invitation')->whereHas('invitation')->findOrFail($encounter);
        Gate::authorize('view', $entry);

        return $this->showRequest($request, $entry->request_id);
    }

    public function accept(Request $request, int $invitation): JsonResponse
    {
        return $this->resolve($request, $invitation, EncounterRequest::ACCEPTED);
    }

    public function reject(Request $request, int $invitation): JsonResponse
    {
        return $this->resolve($request, $invitation, EncounterRequest::REJECTED);
    }

    public function cancel(Request $request, int $invitation): JsonResponse
    {
        return $this->resolve($request, $invitation, EncounterRequest::CANCELLED);
    }

    private function resolve(Request $request, int $id, string $status): JsonResponse
    {
        DB::transaction(function () use ($id, $status): void {
            $initial = EncounterRequest::findOrFail($id);
            Gate::authorize($status === EncounterRequest::CANCELLED ? 'cancel' : 'respond', $initial);
            Blocks::lockPair($initial->requester_id, $initial->target_user_id);
            abort_if(Blocks::between($initial->requester_id, $initial->target_user_id), 403);
            // Keep the same lock order as post deletion.
            $source = $initial->source_post_id ? Post::lockForUpdate()->find($initial->source_post_id) : null;
            $item = EncounterRequest::lockForUpdate()->findOrFail($id);
            if ($item->status === $status) {
                return;
            }
            abort_unless($item->status === EncounterRequest::PENDING && $source, 409);
            if ($status === EncounterRequest::ACCEPTED) {
                abort_unless(EncounterRequest::activePair()->whereKey($id)->exists(), 409);
                $item->encounter()->create(['confirmed_at' => now()]);
            }
            $item->update(['status' => $status, 'responded_at' => now()]);
            if ($status !== EncounterRequest::CANCELLED) {
                Inbox::add($item->requester_id, $item->target_user_id, 'encounter_'.$status, $item->id);
            }
        });

        return $this->showRequest($request, $id);
    }

    public function editStory(Request $request, int $encounter): JsonResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:100'],
            'body' => ['required', 'string', 'max:1000'],
            'revision' => ['required', 'integer', 'min:1'],
        ]);
        $entry = Encounter::with('invitation')->whereHas('invitation')->findOrFail($encounter);
        Gate::authorize('view', $entry);
        DB::transaction(function () use ($entry, $data, $request): void {
            $this->lockParticipants($entry);
            $story = $entry->story()->lockForUpdate()->firstOrFail();
            Gate::authorize('editStory', [$entry, $story]);
            abort_if($story->story_status === Post::STORY_PUBLISHED || (int) $data['revision'] !== $story->story_revision, 409);
            $story->forceFill(['story_title' => $data['title'], 'body' => $data['body'],
                'story_status' => Post::STORY_PENDING, 'story_revision' => $story->story_revision + 1])->save();
            $id = $request->user()->id;
            $other = $entry->invitation->requester_id === $id ? $entry->invitation->target_user_id : $entry->invitation->requester_id;
            Inbox::add($other, $id, 'encounter_story_approval', $entry->request_id);
        });

        return $this->showRequest($request, $entry->request_id);
    }

    public function approveStory(Request $request, int $encounter): JsonResponse
    {
        return $this->reviewStory($request, $encounter, Post::STORY_PUBLISHED);
    }

    public function rejectStory(Request $request, int $encounter): JsonResponse
    {
        return $this->reviewStory($request, $encounter, Post::STORY_REJECTED);
    }

    private function reviewStory(Request $request, int $encounter, string $status): JsonResponse
    {
        $data = $request->validate(['revision' => ['required', 'integer', 'min:1']]);
        $entry = Encounter::with('invitation')->whereHas('invitation')->findOrFail($encounter);
        Gate::authorize('view', $entry);
        DB::transaction(function () use ($entry, $data, $status, $request): void {
            $this->lockParticipants($entry);
            $story = $entry->story()->lockForUpdate()->firstOrFail();
            Gate::authorize('reviewStory', [$entry, $story]);
            abort_unless((int) $data['revision'] === $story->story_revision, 409);
            if ($story->story_status === $status) {
                return;
            }
            abort_unless($story->story_status === Post::STORY_PENDING, 409);
            if ($status === Post::STORY_PUBLISHED) {
                abort_unless(EncounterRequest::activePair()->whereKey($entry->request_id)->exists(), 409);
                $story->forceFill(['visibility' => 'city', 'created_at' => now()]);
            }
            $story->forceFill(['story_status' => $status])->save();
            if ($status === Post::STORY_PUBLISHED) {
                Inbox::add($story->user_id, $request->user()->id, 'encounter_story_published', $entry->request_id);
            }
        });

        return $this->showRequest($request, $entry->request_id);
    }

    public function featured(Request $request): JsonResponse
    {
        $data = $request->validate(['city_id' => ['sometimes', 'integer', Rule::exists('cities', 'id')->where('is_active', true)]]);
        $settings = app(\App\Administration\Settings::class);
        if (! $settings->get('featured_enabled') || ! $settings->get('encounters_enabled')) {
            return ApiResponse::ok(['items' => [], 'next_page' => null]);
        }
        $posts = $this->published($request->user())->where('posts.city_id', $data['city_id'] ?? $request->user()->city_id);

        return ApiResponse::page($posts->orderByRaw('CASE WHEN featured_rank IS NULL THEN 1 ELSE 0 END')
            ->orderBy('featured_rank')->latest()->orderByDesc('id')->simplePaginate(12), PostResource::class);
    }

    public function publicProfile(Request $request, string $username): JsonResponse
    {
        $user = Blocks::exclude(User::where('account_status', 'active'), $request->user()->id, 'users.id')->where('username', $username)->firstOrFail();
        $posts = $this->published($request->user())
            ->whereHas('jointEncounter.invitation', fn (Builder $pair) => $pair->participant($user->id));

        return ApiResponse::page($posts->latest()->orderByDesc('id')->simplePaginate(12), PostResource::class);
    }

    private function published(User $viewer): Builder
    {
        return Post::visibleTo($viewer)->forViewer($viewer)->where('posts.story_status', Post::STORY_PUBLISHED)
            ->where('posts.visibility', 'city')->whereHas('jointEncounter.invitation', fn (Builder $pair) => $pair->activePair());
    }

    private function requests(User $viewer): Builder
    {
        $query = EncounterRequest::with([
            'requester.city', 'target.city', 'encounter',
            'source' => fn (BelongsTo $source) => $source->forViewer($viewer),
            'encounter.story' => fn (HasOne $story) => $story->forViewer($viewer),
        ]);
        Blocks::exclude($query, $viewer->id, 'encounter_requests.requester_id');
        return Blocks::exclude($query, $viewer->id, 'encounter_requests.target_user_id');
    }

    private function lockParticipants(Encounter $entry): void
    {
        $pair = $entry->invitation;
        Blocks::lockPair($pair->requester_id, $pair->target_user_id);
        abort_if(Blocks::between($pair->requester_id, $pair->target_user_id), 403);
    }
}
