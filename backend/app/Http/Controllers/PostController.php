<?php

namespace App\Http\Controllers;

use App\Media\PrivateImage;
use App\Notifications\Inbox;
use App\Safety\Blocks;

use App\Encounters\EncounterEligibility;
use App\Http\ApiResponse;
use App\Http\Resources\PostCommentResource;
use App\Http\Resources\PostResource;
use App\Location\Geo;
use App\Location\LocationData;
use App\Models\Encounter;
use App\Models\EncounterRequest;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\PostMedia;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

class PostController extends Controller
{
    public function feed(Request $request): JsonResponse
    {
        $data = $request->validate([
            'city_id' => ['sometimes', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
            'sort' => ['sometimes', Rule::in(['new', 'nearby', 'popular'])],
            'radius' => ['sometimes', 'integer', Rule::in([5000, 10000, 25000])],
            'use_location' => ['sometimes', 'boolean'],
            'content' => ['sometimes', Rule::in(['photo', 'text', 'tagged', ...Post::TYPES])],
            'media' => ['sometimes', Rule::in(['all', 'photo', 'text'])],
            'following' => ['sometimes', 'boolean'],
            'photo_first' => ['sometimes', 'boolean'],
            'encounter_first' => ['sometimes', 'boolean'],
            'interests' => ['sometimes', 'array', 'list', 'max:30'],
            'interests.*' => ['string', 'max:100'],
        ]);
        $viewer = $request->user();
        $origin = ($data['use_location'] ?? true) ? LocationData::active($viewer) : null;
        $posts = Post::visibleTo($viewer)->forViewer($viewer)
            ->where('city_id', LocationData::city($viewer, $origin, $data['city_id'] ?? null))
            ->where('visibility', 'city');
        if ($origin) {
            [$distance, $bindings] = Geo::expression($origin, 'posts.approx_latitude', 'posts.approx_longitude');
            $posts->selectRaw("($distance) AS distance_meters", $bindings);
            if (isset($data['radius'])) {
                Geo::bound($posts, $origin, $data['radius'], 'posts.approx_latitude', 'posts.approx_longitude');
                $posts->whereRaw("($distance) <= ?", [...$bindings, $data['radius']]);
            }
            if (($data['sort'] ?? '') === 'nearby') {
                $posts->orderByRaw('CASE WHEN posts.approx_latitude IS NULL THEN 1 ELSE 0 END')
                    ->orderBy('distance_meters');
            }
        } elseif (isset($data['radius'])) {
            $posts->whereRaw('1 = 0');
        }
        if ($data['following'] ?? false) {
            // "Takip": only people the viewer follows. Anonymous posts never appear here: with a short follow list they would
            // reveal their author. They stay in the city-wide Akış / Yakın / Popüler feeds, where they remain anonymous.
            $posts->where('posts.is_anonymous', false)->whereIn('posts.user_id',
                DB::table('user_follows')->where('follower_id', $viewer->id)->select('followed_id'));
        }
        $content = $data['content'] ?? null;
        match ($content) {
            'photo' => $posts->has('media'),
            'text' => $posts->doesntHave('media'),
            'tagged' => $posts->where(fn (Builder $tagged) => $tagged->has('confirmedEncounter')->orWhereHas('jointEncounter')),
            null => null,
            default => $posts->where('type', $content),
        };
        match ($data['media'] ?? 'all') {
            'photo' => $posts->has('media'),
            'text' => $posts->doesntHave('media'),
            default => null,
        };
        if (! empty($data['interests'])) {
            $posts->where('is_anonymous', false)->whereHas('author.interests',
                fn (Builder $query) => $query->whereIn('interests.name', $data['interests']));
        }
        if ($data['encounter_first'] ?? false) {
            $posts->orderByRaw("CASE WHEN type = 'encounter' THEN 0 ELSE 1 END");
        }
        if ($data['photo_first'] ?? false) {
            $posts->withExists('media')->orderByDesc('media_exists');
        }
        if (($data['sort'] ?? null) === 'popular') {
            $posts->selectRaw('CASE WHEN posts.created_at >= ? THEN 6 WHEN posts.created_at >= ? THEN 2 ELSE 0 END AS recency_score',
                [now()->subDay(), now()->subDays(7)])
                ->orderByRaw('(likes_count + 2 * comments_count + recency_score) DESC');
        }

        if (!isset($data['sort']) || $data['sort'] === 'new') {
            $rules = config('location.matching');
            $strong = (int)$rules['strong_score']; $medium = (int)$rules['medium_score'];
            $boost = (int)$rules['boost_hours'];
            $hours = "CASE WHEN viewer_match_score >= $strong THEN $boost WHEN viewer_match_score >= $medium THEN ".(int)($boost / 2)." WHEN viewer_match_score > 0 THEN 1 ELSE 0 END";
            $posts->orderByRaw(DB::getDriverName() === 'sqlite'
                ? "datetime(posts.created_at, '+' || ($hours) || ' hours') DESC"
                : "DATE_ADD(posts.created_at, INTERVAL ($hours) HOUR) DESC");
        }
        return ApiResponse::page($posts->latest()->orderByDesc('id')->simplePaginate(20), PostResource::class);
    }

    public function show(Request $request, int $post): JsonResponse
    {
        return ApiResponse::ok(new PostResource(
            Post::visibleTo($request->user())->forViewer($request->user())->findOrFail($post)
        ));
    }

    public function store(Request $request, EncounterEligibility $eligibility): JsonResponse
    {
        $settings = app(\App\Administration\Settings::class);
        $photoLimit = $settings->get('max_post_photos');
        $data = $request->validate([
            'body' => ['nullable', 'required_without:media', 'string', 'max:1000'],
            'type' => ['required', Rule::in(Post::TYPES)],
            'city_id' => ['required', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
            'visibility' => ['required', Rule::in(['city', 'private'])],
            'is_anonymous' => ['required', 'boolean'],
            'comments_enabled' => ['sometimes', 'boolean'],
            'request_id' => ['required', 'uuid'],
            'attach_location' => ['sometimes', 'boolean'],
            'location_source' => ['sometimes', Rule::in(['current', 'history', 'map'])],
            'history_id' => ['required_if:location_source,history', 'integer', 'min:1'],
            'place_latitude' => ['required_if:location_source,map', 'numeric', 'between:-90,90'],
            'place_longitude' => ['required_if:location_source,map', 'numeric', 'between:-180,180'],
            'occurred_at' => ['sometimes', 'nullable', 'date', 'before_or_equal:now', 'after_or_equal:'.LocationData::cutoff()->toISOString()],
            'travel' => ['sometimes', 'array:transport_type,origin_city_id,destination_city_id,departure_at,operator_name,service_code,vehicle_identifier,is_public', Rule::prohibitedIf($request->input('type') !== 'travel')],
            'travel.transport_type' => ['required_with:travel', Rule::in(['bus', 'train', 'plane', 'ferry', 'other'])],
            'travel.origin_city_id' => ['required_with:travel', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
            'travel.destination_city_id' => ['required_with:travel', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
            'travel.departure_at' => ['nullable', 'date', 'after_or_equal:'.LocationData::cutoff()->toISOString(), 'before_or_equal:'.now()->addYear()->toISOString()],
            'travel.operator_name' => ['nullable', 'string', 'max:80'],
            'travel.service_code' => ['nullable', 'string', 'max:40'],
            'travel.vehicle_identifier' => ['nullable', 'string', 'max:40'],
            'travel.is_public' => ['sometimes', 'boolean'],
            'encounter_target_id' => ['sometimes', 'integer', 'min:1'],
            'encounter_id' => ['sometimes', 'integer', 'min:1', 'prohibits:encounter_target_id'],
            'story_title' => ['required_with:encounter_id', Rule::prohibitedIf(! $request->filled('encounter_id')), 'string', 'max:100'],
            'media' => ['sometimes', 'array', 'list', 'min:1', 'max:'.$photoLimit],
            'media.*' => PrivateImage::RULES,
        ], [
            'body.required_without' => 'Metin yaz veya bir fotoğraf ekle.',
            'media.max' => 'En fazla '.$photoLimit.' fotoğraf ekleyebilirsin.',
            'media.*.*' => 'Her fotoğraf JPEG, PNG veya WebP biçiminde, en fazla 5 MB ve 2048 piksel olmalı.',
        ]);
        if (!empty($data['occurred_at'])) $data['occurred_at'] = \Illuminate\Support\Carbon::parse($data['occurred_at'])->utc();
        if (!empty($data['travel']['departure_at'])) $data['travel']['departure_at'] = \Illuminate\Support\Carbon::parse($data['travel']['departure_at'])->utc();
        $viewer = $request->user();
        if ($data['is_anonymous'] && ! $settings->get('anonymous_posts_enabled')) {
            throw ValidationException::withMessages(['is_anonymous' => 'Anonim paylaşım şu anda kapalı.']);
        }
        $diskName = config('mobile.post_media_disk');
        $disk = Storage::disk($diskName);
        $written = [];
        try {
            [$post, $created] = DB::transaction(function () use ($viewer, $data, $diskName, $disk, $eligibility, &$written) {
                $jointRequest = isset($data['encounter_id']) ? Encounter::find($data['encounter_id'])?->invitation : null;
                $partner = $jointRequest?->requester_id === $viewer->id ? $jointRequest?->target_user_id : $jointRequest?->requester_id;
                $pair = $data['encounter_target_id'] ?? $partner;
                Blocks::lockPair($viewer->id, $pair ? (int) $pair : $viewer->id);
                $existing = Post::withTrashed()->where('user_id', $viewer->id)
                    ->where('request_id', $data['request_id'])->first();
                if ($existing) {
                    abort_if($existing->trashed(), 404);

                    return [$existing, false];
                }

                app(\App\Safety\ContentGuard::class)->check($viewer->id, $data['body'] ?? '', 'posts');
                $place = app(\App\Location\PostPlace::class)->resolve($viewer->fresh(), $data);
                $travel = $data['travel'] ?? null;
                if ($travel) {
                    app(\App\Safety\ContentGuard::class)->check($viewer->id, implode(' ', array_filter([
                        $travel['operator_name'] ?? null, $travel['service_code'] ?? null, $travel['vehicle_identifier'] ?? null,
                    ])), 'posts');
                }
                $files = $data['media'] ?? [];
                $target = isset($data['encounter_target_id']) ? (int) $data['encounter_target_id'] : null;
                $joint = null;
                if ($target !== null) {
                    if ($data['type'] !== 'encounter' || $data['is_anonymous'] || $data['visibility'] !== 'city') {
                        throw ValidationException::withMessages(['encounter_target_id' => 'Etiketleme için şehir görünürlüğü açık bir karşılaşma paylaşımı oluştur.']);
                    }
                    $eligibility->validateTarget($viewer, $target);
                    abort_if(EncounterRequest::where('requester_id', $viewer->id)
                        ->where('created_at', '>=', now()->subMinutes(10))->count() >= 10, 429);
                }
                if (isset($data['encounter_id'])) {
                    $joint = Encounter::with('invitation')->whereHas('invitation')->lockForUpdate()->findOrFail($data['encounter_id']);
                    Gate::authorize('propose', $joint);
                    abort_if($partner && Blocks::between($viewer->id, $partner), 403);
                    abort_if(Post::withTrashed()->where('encounter_id', $joint->id)->exists(), 409);
                    abort_unless($data['type'] === 'encounter' && ! $data['is_anonymous'] && filled($data['body'] ?? null), 422);
                    $data['visibility'] = 'private';
                    $data['comments_enabled'] = true;
                    $data['city_id'] = $joint->invitation->source()->withTrashed()->value('city_id') ?? $viewer->city_id;
                }
                $storyTitle = $data['story_title'] ?? null;
                unset($data['media'], $data['attach_location'], $data['encounter_id'], $data['encounter_target_id'], $data['story_title'],
                    $data['location_source'], $data['history_id'], $data['place_latitude'], $data['place_longitude'], $data['travel']);
                $post = new Post([...$data, 'user_id' => $viewer->id, 'body' => $data['body'] ?? '']);
                if ($joint) {
                    $post->forceFill(['encounter_id' => $joint->id, 'story_title' => $storyTitle,
                        'story_status' => Post::STORY_PENDING, 'story_revision' => 1]);
                }
                if ($place && !$joint) $post->forceFill($place);
                $post->forceFill(['content_hash' => \App\Safety\ContentGuard::fingerprint($data['body'] ?? '')]);
                $post->save();
                if ($travel && !$joint) $post->travel()->create($travel + ['is_public' => false]);
                if ($target !== null) {
                    $invitation = EncounterRequest::create(['requester_id' => $viewer->id, 'target_user_id' => $target,
                        'source_post_id' => $post->id, 'status' => EncounterRequest::PENDING]);
                    Inbox::add($target, $viewer->id, 'encounter_request', $invitation->id);
                } elseif ($joint && $partner) {
                    Inbox::add($partner, $viewer->id, 'encounter_story_approval', $joint->request_id);
                }
                foreach ($files as $order => $file) {
                    [$bytes, $width, $height] = PrivateImage::jpeg($file, 'media');
                    $path = 'posts/'.Str::uuid().'.jpg';
                    $written[] = $path;
                    abort_unless($disk->put($path, $bytes, 'private'), 500);
                    $post->media()->create([
                        'file_path' => $path, 'disk' => $diskName, 'sort_order' => $order,
                        'width' => $width, 'height' => $height, 'mime_type' => 'image/jpeg',
                    ]);
                }

                return [$post, true];
            });
        } catch (\Throwable $error) {
            if ($written !== []) {
                $disk->delete($written);
            }
            throw $error;
        }

        if ($created && ($post->approx_latitude !== null || $post->type === 'travel')) {
            \App\Jobs\MatchLocationPost::dispatch($post->id)->afterCommit();
        }

        return ApiResponse::ok(new PostResource(
            Post::forViewer($viewer)->findOrFail($post->id)
        ), 'Paylaşımın kaydedildi.', $created ? 201 : 200);
    }

    public function update(Request $request, int $post): JsonResponse
    {
        $viewer = $request->user();
        DB::transaction(function () use ($request, $viewer, $post): void {
            $entry = Post::visibleTo($viewer)->lockForUpdate()->findOrFail($post);
            Gate::authorize('update', $entry);
            $data = $request->validate([
                'body' => [$entry->media()->exists() ? 'present' : 'required', 'nullable', 'string', 'max:1000'],
            ]);
            app(\App\Safety\ContentGuard::class)->check($viewer->id, $data['body'] ?? '', 'posts', $entry->id);
            $entry->forceFill(['body' => $data['body'] ?? '', 'content_hash' => \App\Safety\ContentGuard::fingerprint($data['body'] ?? '')])->save();
        });

        return $this->show($request, $post);
    }

    public function destroy(Request $request, int $post): JsonResponse
    {
        DB::transaction(function () use ($request, $post): void {
            $entry = Post::visibleTo($request->user())->lockForUpdate()->findOrFail($post);
            Gate::authorize('delete', $entry);
            $entry->delete();
            EncounterRequest::where('source_post_id', $entry->id)->where('status', EncounterRequest::PENDING)
                ->update(['status' => EncounterRequest::CANCELLED, 'responded_at' => now()]);
            DB::table('location_matches')->where('post_id', $entry->id)->delete();
        });

        return ApiResponse::ok(message: 'Paylaşım silindi.');
    }

    public function media(Request $request, int $media): Response
    {
        $image = PostMedia::whereHas('post', fn (Builder $post) => $post->visibleTo($request->user()))->findOrFail($media);
        $disk = Storage::disk($image->disk);
        abort_unless($disk->exists($image->file_path), 404);

        return $disk->response($image->file_path, 'paylasim.jpg', [
            'Content-Type' => $image->mime_type, 'X-Content-Type-Options' => 'nosniff',
            'Cache-Control' => 'private, no-store',
        ]);
    }

    public function like(Request $request, int $post): JsonResponse
    {
        return $this->reaction($request, $post, 'post_likes');
    }

    public function save(Request $request, int $post): JsonResponse
    {
        return $this->reaction($request, $post, 'post_saves');
    }

    private function reaction(Request $request, int $post, string $table): JsonResponse
    {
        $viewer = $request->user();
        DB::transaction(function () use ($request, $post, $table, $viewer): void {
            $entry = Post::visibleTo($viewer)->lockForUpdate()->findOrFail($post);
            abort_if($entry->encounter_id && $entry->story_status !== Post::STORY_PUBLISHED, 403);
            $keys = ['user_id' => $viewer->id, 'post_id' => $post];
            if ($request->isMethod('DELETE')) {
                DB::table($table)->where($keys)->delete();
                if ($table === 'post_saves') {
                    // Un-saving also leaves every private collection.
                    DB::table('saved_collection_posts')->where('post_id', $post)
                        ->whereIn('collection_id', DB::table('saved_collections')->where('user_id', $viewer->id)->select('id'))->delete();
                }
            } elseif (DB::table($table)->insertOrIgnore([...$keys, 'created_at' => now()]) && $table === 'post_likes') {
                Inbox::add($entry->user_id, $viewer->id, 'like', $entry->id);
            }
        });

        return $this->show($request, $post);
    }

    public function saved(Request $request): JsonResponse
    {
        $viewer = $request->user();
        $posts = Post::visibleTo($viewer)->forViewer($viewer)
            ->join('post_saves as viewer_saves', fn ($join) => $join->on('posts.id', '=', 'viewer_saves.post_id')
                ->where('viewer_saves.user_id', $viewer->id))
            ->orderByDesc('viewer_saves.created_at')->orderByDesc('posts.id');

        return ApiResponse::page($posts->simplePaginate(20), PostResource::class);
    }

    private const REPLY_PREVIEW = 3;

    public function comments(Request $request, int $post): JsonResponse
    {
        $viewer = $request->user();
        $entry = Post::visibleTo($viewer)->findOrFail($post);
        $visible = fn () => Blocks::exclude($entry->comments()->getQuery(), $viewer->id, 'post_comments.user_id');
        $comments = $visible()->whereNull('post_comments.parent_id')->with('author')->latest('id')->simplePaginate(20);
        $ids = collect($comments->items())->pluck('id');
        $totals = $visible()->whereIn('post_comments.parent_id', $ids)->selectRaw('post_comments.parent_id, COUNT(*) AS total')
            ->groupBy('post_comments.parent_id')->pluck('total', 'parent_id');
        $previews = $visible()->whereIn('post_comments.parent_id', $ids)->with('author')->orderBy('post_comments.id')->get()
            ->groupBy('parent_id');
        foreach ($comments as $comment) {
            $comment->setRelation('post', $entry);
            $comment->setAttribute('reply_total', (int) ($totals[$comment->id] ?? 0));
            $comment->setRelation('replies', ($previews[$comment->id] ?? collect())->take(self::REPLY_PREVIEW)->values());
        }
        $this->likeStats($viewer, collect($comments->items())->merge(collect($comments->items())->flatMap(fn ($comment) => $comment->replies)));

        return ApiResponse::page($comments, PostCommentResource::class);
    }

    /** All replies of one top-level comment, oldest first (a conversation reads top to bottom). */
    public function replies(Request $request, int $post, int $comment): JsonResponse
    {
        $viewer = $request->user();
        $entry = Post::visibleTo($viewer)->findOrFail($post);
        $parent = Blocks::exclude($entry->comments()->getQuery(), $viewer->id, 'post_comments.user_id')
            ->whereNull('post_comments.parent_id')->findOrFail($comment);
        $replies = Blocks::exclude($entry->comments()->getQuery(), $viewer->id, 'post_comments.user_id')
            ->where('post_comments.parent_id', $parent->id)->with('author')->orderBy('post_comments.id')->simplePaginate(20);
        foreach ($replies as $reply) {
            $reply->setRelation('post', $entry);
        }
        $this->likeStats($viewer, collect($replies->items()));

        return ApiResponse::page($replies, PostCommentResource::class);
    }

    public function comment(Request $request, int $post): JsonResponse
    {
        $data = $request->validate([
            'body' => ['required', 'string', 'max:500'],
            'parent_id' => ['sometimes', 'nullable', 'integer'],
        ], ['body.required' => 'Bir yorum yaz.']);
        $comment = DB::transaction(function () use ($request, $post, $data) {
            $viewer = $request->user();
            $entry = Post::visibleTo($viewer)->lockForUpdate()->findOrFail($post);
            abort_unless($entry->comments_enabled &&
                (! $entry->encounter_id || $entry->story_status === Post::STORY_PUBLISHED), 403);
            $parent = null;
            if (! empty($data['parent_id'])) {
                // Same post, still public, not blocked either way. A reply can only target a TOP-LEVEL comment.
                $parent = Blocks::exclude($entry->comments()->getQuery(), $viewer->id, 'post_comments.user_id')
                    ->lockForUpdate()->find($data['parent_id']);
                abort_unless($parent, 404);
                if ($parent->parent_id !== null) {
                    throw ValidationException::withMessages(['parent_id' => 'Yanıta yanıt verilemez; ana yoruma yanıt ver.']);
                }
            }
            User::whereKey($viewer->id)->lockForUpdate()->firstOrFail();
            app(\App\Safety\ContentGuard::class)->check($viewer->id, $data['body'], 'post_comments');
            $comment = $entry->comments()->create(['body' => $data['body'], 'user_id' => $viewer->id, 'parent_id' => $parent?->id]);
            $comment->forceFill(['content_hash' => \App\Safety\ContentGuard::fingerprint($data['body'])])->save();

            if ($parent) {
                // One meaningful notification: the owner of the comment that was answered (also when that is the post owner).
                // The post owner does not additionally get a generic "comment" for every reply in a thread.
                Inbox::add($parent->user_id, $viewer->id, 'comment_reply', $comment->id);
            } else {
                Inbox::add($entry->user_id, $viewer->id, 'comment', $entry->id);
            }
            return $comment->setRelation('post', $entry)->setRelation('author', $viewer);
        });

        return ApiResponse::ok(new PostCommentResource($comment), 'Yorum eklendi.', 201);
    }

    /**
     * Like / unlike a top-level comment or a reply. Idempotent both ways. Hidden, blocked, removed or orphaned comments answer 404.
     * The author is notified once per liker and comment (like → unlike → like never repeats it); nobody notifies themselves.
     */
    public function likeComment(Request $request, int $post, int $comment): JsonResponse
    {
        $viewer = $request->user();
        $item = DB::transaction(function () use ($request, $viewer, $post, $comment) {
            $entry = Post::visibleTo($viewer)->lockForUpdate()->findOrFail($post);
            abort_if($entry->encounter_id && $entry->story_status !== Post::STORY_PUBLISHED, 403);
            $item = Blocks::exclude($entry->comments()->getQuery(), $viewer->id, 'post_comments.user_id')->with('author')->findOrFail($comment);
            $keys = ['user_id' => $viewer->id, 'comment_id' => $item->id];
            if ($request->isMethod('DELETE')) {
                DB::table('comment_likes')->where($keys)->delete();
            } elseif (DB::table('comment_likes')->insertOrIgnore([...$keys, 'created_at' => now()])
                && $item->user_id !== $viewer->id
                && ! DB::table('app_notifications')->where(['user_id' => $item->user_id, 'actor_id' => $viewer->id, 'type' => 'comment_like', 'entity_id' => $item->id])->exists()) {
                Inbox::add($item->user_id, $viewer->id, 'comment_like', $item->id);
            }
            $item->setRelation('post', $entry);

            return $item;
        });
        $this->likeStats($viewer, collect([$item]));

        return ApiResponse::ok(new PostCommentResource($item));
    }

    /** Attaches likes_total / liked_by_me to a flat list of comments in two queries (blocked and inactive likers are not counted). */
    private function likeStats(User $viewer, $comments): void
    {
        $ids = $comments->pluck('id')->unique()->values();
        if ($ids->isEmpty()) {
            return;
        }
        $likes = Blocks::exclude(DB::table('comment_likes')->join('users', 'users.id', '=', 'comment_likes.user_id')
            ->where('users.account_status', 'active')->whereIn('comment_likes.comment_id', $ids), $viewer->id, 'comment_likes.user_id')
            ->selectRaw('comment_likes.comment_id AS comment_id, COUNT(*) AS total')->groupBy('comment_likes.comment_id')->pluck('total', 'comment_id');
        $mine = DB::table('comment_likes')->where('user_id', $viewer->id)->whereIn('comment_id', $ids)->pluck('comment_id')->flip();
        foreach ($comments as $comment) {
            $comment->setAttribute('likes_total', (int) ($likes[$comment->id] ?? 0));
            $comment->setAttribute('liked_by_me', $mine->has($comment->id));
        }
    }

    public function deleteComment(Request $request, int $post, int $comment): JsonResponse
    {
        DB::transaction(function () use ($request, $post, $comment): void {
            $entry = Post::visibleTo($request->user())->lockForUpdate()->findOrFail($post);
            // Comments the viewer may not see (other age band, blocked) cannot be probed or moderated either.
            $item = Blocks::exclude($entry->comments()->getQuery(), $request->user()->id, 'post_comments.user_id')->findOrFail($comment);
            Gate::authorize('delete', $item);
            // Likes of a removed comment (and of the replies that disappear with it) no longer count anywhere.
            DB::table('comment_likes')->whereIn('comment_id', PostComment::where('id', $item->id)->orWhere('parent_id', $item->id)->select('id'))->delete();
            $item->delete();
        });

        return ApiResponse::ok(message: 'Yorum silindi.');
    }
}
