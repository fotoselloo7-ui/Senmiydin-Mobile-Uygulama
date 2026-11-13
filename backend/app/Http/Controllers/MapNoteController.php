<?php

namespace App\Http\Controllers;

use App\Http\ApiResponse;
use App\Http\Resources\MapNoteReplyResource;
use App\Http\Resources\MyMapNoteResource;
use App\Http\Resources\MapNoteResource;
use App\Location\CityResolver;
use App\Location\Geo;
use App\Location\LocationData;
use App\MapNotes\NearbyNotifier;
use App\Models\MapNote;
use App\Models\MapNoteReply;
use App\Models\User;
use App\Notifications\Inbox;
use App\Safety\ContentGuard;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Map notes ("digital letters"): public, approximate-location notes that stay on the map for 7 days.
 * Independent from posts, encounters and location matches.
 */
class MapNoteController extends Controller
{
    private const GROUP = '/^-?\d{1,3}\.\d{5}_-?\d{1,3}\.\d{5}$/';

    /** One marker per approximate grid point (never per raw coordinate). */
    public function map(Request $request): JsonResponse
    {
        $data = $request->validate([
            'city_id' => ['sometimes', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
            'radius' => ['sometimes', 'integer', Rule::in([5000, 10000, 25000])],
            'use_location' => ['sometimes', 'boolean'],
        ]);
        $viewer = $request->user();
        $origin = ($data['use_location'] ?? true) ? LocationData::active($viewer) : null;
        $city = LocationData::city($viewer, $origin, $data['city_id'] ?? null);
        if (isset($data['radius']) && ! $origin) {
            return ApiResponse::ok(['items' => [], 'location_required' => true]);
        }

        $notes = MapNote::visibleTo($viewer)->where('map_notes.city_id', $city);
        if (isset($data['radius'])) {
            [$distance, $bindings] = Geo::expression($origin, 'map_notes.approx_latitude', 'map_notes.approx_longitude');
            Geo::bound($notes, $origin, $data['radius'], 'map_notes.approx_latitude', 'map_notes.approx_longitude');
            $notes->whereRaw("($distance) <= ?", [...$bindings, $data['radius']]);
        }
        $items = $notes->toBase()->select('map_notes.approx_latitude', 'map_notes.approx_longitude')
            ->selectRaw('COUNT(*) AS note_count, MAX(map_notes.created_at) AS newest_at')
            ->groupBy('map_notes.approx_latitude', 'map_notes.approx_longitude')
            ->orderByDesc('newest_at')->limit((int) config('map_notes.max_markers'))->get()
            ->map(fn ($row) => [
                'group' => MapNote::groupKey((float) $row->approx_latitude, (float) $row->approx_longitude),
                'latitude' => (float) $row->approx_latitude,
                'longitude' => (float) $row->approx_longitude,
                'count' => (int) $row->note_count,
                'newest_at' => \Illuminate\Support\Carbon::parse($row->newest_at, 'UTC')->toISOString(),
                'distance_meters' => $origin ? Geo::publicDistance(Geo::distance(
                    (float) $origin->latitude, (float) $origin->longitude,
                    (float) $row->approx_latitude, (float) $row->approx_longitude)) : null,
            ]);

        return ApiResponse::ok(['items' => $items, 'location_required' => false]);
    }

    /** All active notes left at one approximate point, newest first. */
    public function group(Request $request, string $group): JsonResponse
    {
        abort_unless(preg_match(self::GROUP, $group) === 1, 404);
        [$latitude, $longitude] = array_map('floatval', explode('_', $group));
        $viewer = $request->user();
        $query = fn () => MapNote::visibleTo($viewer)
            ->whereBetween('map_notes.approx_latitude', [$latitude - 0.000004, $latitude + 0.000004])
            ->whereBetween('map_notes.approx_longitude', [$longitude - 0.000004, $longitude + 0.000004]);
        $page = $query()->with(['author', 'city'])->withCount(['replies' => fn ($replies) => $replies->visibleTo($viewer)])
            ->orderByDesc('map_notes.created_at')->orderByDesc('map_notes.id')
            ->simplePaginate((int) config('map_notes.page_size'));
        $total = $query()->count();

        return ApiResponse::ok([
            'group' => $group, 'count' => $total,
            'place_label' => $page->items()[0]->place_label ?? null,
            'items' => MapNoteResource::collection($page->items()),
            'next_page' => $page->hasMorePages() ? $page->currentPage() + 1 : null,
        ]);
    }

    public function show(Request $request, int $note): JsonResponse
    {
        $viewer = $request->user();
        $entry = MapNote::visibleTo($viewer)->with(['author', 'city'])
            ->withCount(['replies' => fn ($replies) => $replies->visibleTo($viewer)])->findOrFail($note);
        $replies = $this->replyPage($viewer, $entry);

        return ApiResponse::ok([
            'note' => new MapNoteResource($entry),
            'replies' => [
                'items' => MapNoteReplyResource::collection($replies->items()),
                'next_page' => $replies->hasMorePages() ? $replies->currentPage() + 1 : null,
            ],
        ]);
    }

    public function replies(Request $request, int $note): JsonResponse
    {
        $viewer = $request->user();
        $entry = MapNote::visibleTo($viewer)->findOrFail($note);
        $page = $this->replyPage($viewer, $entry);

        return ApiResponse::ok([
            'items' => MapNoteReplyResource::collection($page->items()),
            'next_page' => $page->hasMorePages() ? $page->currentPage() + 1 : null,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $max = (int) config('map_notes.max_body');
        $data = $request->validate([
            'body' => ['required', 'string', "max:$max"],
            'is_anonymous' => ['sometimes', 'boolean'],
            'city_id' => ['required', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'request_id' => ['sometimes', 'uuid'],
        ], ['body.required' => 'Notunu yaz.', 'body.max' => "Notun en fazla $max karakter olabilir."]);
        $body = trim($data['body']);
        if ($body === '') {
            throw ValidationException::withMessages(['body' => 'Notunu yaz.']);
        }
        $resolved = app(CityResolver::class)->resolve((float) $data['latitude'], (float) $data['longitude']);
        if ($resolved && (int) $resolved !== (int) $data['city_id']) {
            throw ValidationException::withMessages(['latitude' => 'Seçtiğin nokta bu şehirde görünmüyor. Haritada şehrinin içinde bir yer seç.']);
        }

        $viewer = $request->user();
        [$note, $created] = DB::transaction(function () use ($viewer, $data, $body) {
            User::whereKey($viewer->id)->lockForUpdate()->firstOrFail();
            if (isset($data['request_id'])) {
                $existing = MapNote::withTrashed()->where('user_id', $viewer->id)->where('request_id', $data['request_id'])->first();
                if ($existing) {
                    return [$existing, false];
                }
            }
            app(ContentGuard::class)->check($viewer->id, $body, 'map_notes');
            $grid = (float) config('map_notes.location_grid');
            $city = DB::table('cities')->where('id', $data['city_id'])->value('name');
            $note = MapNote::create([
                'user_id' => $viewer->id, 'city_id' => $data['city_id'], 'body' => $body,
                'is_anonymous' => (bool) ($data['is_anonymous'] ?? false),
                // The raw selection is snapped server-side and is never stored or returned.
                'approx_latitude' => Geo::grid((float) $data['latitude'], $grid),
                'approx_longitude' => Geo::grid((float) $data['longitude'], $grid),
                'place_label' => $city.' · Yaklaşık bölge', 'content_hash' => ContentGuard::fingerprint($body),
                'request_id' => $data['request_id'] ?? null,
                'occurred_at' => now(),
                'expires_at' => now()->addDays((int) config('map_notes.ttl_days')),
            ]);
            // Exactly one create-time fan-out; later map opens, location updates or replies never notify again.
            app(NearbyNotifier::class)->notify($note);

            return [$note, true];
        });
        $note->load(['author', 'city'])->loadCount(['replies' => fn ($replies) => $replies->visibleTo($viewer)]);

        return ApiResponse::ok(new MapNoteResource($note), 'Notun haritaya bırakıldı.', $created ? 201 : 200);
    }

    /**
     * "Kalıcı Sil": the owner's letter, its replies and every personal access to it are removed. Rows that carry a report are
     * only soft-deleted so moderation can still review them until the retention window ends; everything else is erased now.
     */
    public function destroy(Request $request, int $note): JsonResponse
    {
        $entry = MapNote::findOrFail($note);
        abort_unless($entry->user_id === $request->user()->id, 403);
        DB::transaction(function () use ($entry): void {
            $reported = DB::table('reports')->where('target_type', 'map_note')->where('target_id', $entry->id)->exists()
                || DB::table('reports')->where('target_type', 'map_note_reply')
                    ->whereIn('target_id', DB::table('map_note_replies')->where('map_note_id', $entry->id)->select('id'))->exists();
            $reported ? $entry->delete() : $entry->forceDelete();
        });

        return ApiResponse::ok(message: 'Mektup kalıcı olarak silindi.');
    }

    /** "Haritadan Kaldır": public visibility ends now; the letter stays in the owner's private archive. */
    public function archive(Request $request, int $note): JsonResponse
    {
        $entry = $this->ownLetter($request, $note);
        if ($entry->archived_at === null) {
            $entry->forceFill(['archived_at' => now()])->save();
        }

        return ApiResponse::ok($this->mineResource($request, $entry->id), 'Mektup haritadan kaldırıldı. Mektuplarım → Arşiv’de duruyor.');
    }

    /**
     * "Tekrar Paylaş": a NEW public publication of the same letter. It gets a fresh 7-day lifecycle (created_at / expires_at),
     * keeps the letter's real date (occurred_at) and the same approximate point, and starts with an empty public thread.
     * Replies to the earlier publication stay in the owner's archive only. No "near you" fan-out is sent again.
     */
    public function repost(Request $request, int $note): JsonResponse
    {
        $data = $request->validate(['request_id' => ['sometimes', 'uuid']]);
        $viewer = $request->user();
        [$fresh, $created] = DB::transaction(function () use ($viewer, $note, $data) {
            User::whereKey($viewer->id)->lockForUpdate()->firstOrFail();
            if (isset($data['request_id'])) {
                $existing = MapNote::withTrashed()->where('user_id', $viewer->id)->where('request_id', $data['request_id'])->first();
                if ($existing) {
                    return [$existing, false];
                }
            }
            $original = MapNote::where('user_id', $viewer->id)->whereNull('moderated_at')->lockForUpdate()->findOrFail($note);
            if ($original->state() === 'active') {
                throw ValidationException::withMessages(['note' => 'Bu mektup zaten haritada.']);
            }
            if ($original->reposts()->live()->exists()) {
                throw ValidationException::withMessages(['note' => 'Bu mektup zaten yeniden paylaşıldı ve haritada.']);
            }
            if (! DB::table('cities')->where('id', $original->city_id)->where('is_active', true)->exists()) {
                throw ValidationException::withMessages(['note' => 'Bu şehirde şu an mektup bırakılamıyor.']);
            }
            app(ContentGuard::class)->check($viewer->id, $original->body, 'map_notes');
            $fresh = MapNote::create([
                'user_id' => $viewer->id, 'city_id' => $original->city_id, 'body' => $original->body,
                'is_anonymous' => $original->is_anonymous,
                'approx_latitude' => $original->approx_latitude, 'approx_longitude' => $original->approx_longitude,
                'place_label' => $original->place_label, 'content_hash' => $original->content_hash,
                'request_id' => $data['request_id'] ?? null,
                'occurred_at' => $original->occurred_at ?? $original->created_at,
                'reposted_from_id' => $original->id,
                'expires_at' => now()->addDays((int) config('map_notes.ttl_days')),
            ]);

            return [$fresh, true];
        });
        $fresh->load(['author', 'city'])->loadCount(['replies' => fn ($replies) => $replies->visibleTo($viewer)]);

        return ApiResponse::ok(new MapNoteResource($fresh), 'Mektubun yeniden haritada.', $created ? 201 : 200);
    }

    /** Mektuplarım list: active = still public (7 days), archive = expired or taken off the map. Private to the owner. */
    public function mine(Request $request): JsonResponse
    {
        $data = $request->validate(['scope' => ['sometimes', Rule::in(['active', 'archive'])]]);
        $viewer = $request->user();
        $notes = MapNote::where('map_notes.user_id', $viewer->id)->whereNull('map_notes.moderated_at')
            ->with(['city', 'author'])
            ->withCount(['replies' => fn ($replies) => $replies->visibleTo($viewer)])
            ->addSelect(['map_notes.*', 'has_live_repost' => $this->liveRepostSubquery()]);
        if (($data['scope'] ?? 'active') === 'active') {
            $notes->whereNull('map_notes.archived_at')->where('map_notes.expires_at', '>', now())
                ->orderByDesc('map_notes.created_at')->orderByDesc('map_notes.id');
        } else {
            $notes->where(fn ($x) => $x->whereNotNull('map_notes.archived_at')->orWhere('map_notes.expires_at', '<=', now()))
                ->orderByRaw('COALESCE(map_notes.archived_at, map_notes.expires_at) DESC')->orderByDesc('map_notes.id');
        }

        return ApiResponse::page($notes->simplePaginate((int) config('map_notes.page_size')), MyMapNoteResource::class);
    }

    /** One of the owner's letters with its full historical thread (also after it left the public map). */
    public function showMine(Request $request, int $note): JsonResponse
    {
        $viewer = $request->user();
        $entry = $this->ownLetter($request, $note);
        $replies = MapNoteReply::visibleTo($viewer)->where('map_note_id', $entry->id)->with('author')
            ->orderBy('map_note_replies.created_at')->orderBy('map_note_replies.id')
            ->simplePaginate((int) config('map_notes.reply_page_size'))
            ->through(fn (MapNoteReply $reply) => $reply->setRelation('note', $entry));

        return ApiResponse::ok([
            'note' => $this->mineResource($request, $entry->id),
            'replies' => [
                'items' => MapNoteReplyResource::collection($replies->items()),
                'next_page' => $replies->hasMorePages() ? $replies->currentPage() + 1 : null,
            ],
        ]);
    }

    /**
     * The viewer really opened this letter. Idempotent, private to the viewer: nobody (not even the author) can see who read what.
     * Map viewport movement never counts as reading.
     */
    public function read(Request $request, int $note): JsonResponse
    {
        $viewer = $request->user();
        $entry = MapNote::visibleTo($viewer)->findOrFail($note);
        if ($entry->user_id !== $viewer->id) {
            DB::table('map_note_reads')->insertOrIgnore(['user_id' => $viewer->id, 'map_note_id' => $entry->id, 'read_at' => now()]);
        }

        return ApiResponse::ok($this->unreadSummary($viewer));
    }

    /** Count of active letters left near the viewer (recent location) that the viewer has not opened yet. */
    public function unread(Request $request): JsonResponse
    {
        return ApiResponse::ok($this->unreadSummary($request->user()));
    }

    private function unreadSummary(User $viewer): array
    {
        $enabled = (bool) app(\App\Administration\Settings::class)->get('nearby_notes_enabled');
        $origin = LocationData::active($viewer);
        if (! $origin) {
            return ['count' => 0, 'location_required' => true, 'enabled' => $enabled];
        }
        $radius = (int) config('map_notes.nearby_notification_meters');
        $notes = MapNote::visibleTo($viewer)->where('map_notes.city_id', LocationData::city($viewer, $origin, null))
            ->where('map_notes.user_id', '<>', $viewer->id)
            ->whereNotExists(fn ($reads) => $reads->selectRaw('1')->from('map_note_reads as r')
                ->whereColumn('r.map_note_id', 'map_notes.id')->where('r.user_id', $viewer->id));
        [$distance, $bindings] = Geo::expression($origin, 'map_notes.approx_latitude', 'map_notes.approx_longitude');
        Geo::bound($notes, $origin, $radius, 'map_notes.approx_latitude', 'map_notes.approx_longitude');
        $notes->whereRaw("($distance) <= ?", [...$bindings, $radius]);

        return ['count' => (int) $notes->count(), 'location_required' => false, 'enabled' => $enabled, 'radius_meters' => $radius];
    }

    private function ownLetter(Request $request, int $note): MapNote
    {
        return MapNote::where('user_id', $request->user()->id)->whereNull('moderated_at')->findOrFail($note);
    }

    private function mineResource(Request $request, int $id): MyMapNoteResource
    {
        $viewer = $request->user();

        return new MyMapNoteResource(MapNote::with(['city', 'author'])->addSelect(['map_notes.*', 'has_live_repost' => $this->liveRepostSubquery()])
            ->withCount(['replies' => fn ($replies) => $replies->visibleTo($viewer)])->findOrFail($id));
    }

    /** 1 when a later publication of this letter is public right now (aliased: the relation points back at the same table). */
    private function liveRepostSubquery(): \Illuminate\Database\Query\Builder
    {
        return DB::table('map_notes as later')->selectRaw('1')->whereColumn('later.reposted_from_id', 'map_notes.id')
            ->whereNull('later.deleted_at')->whereNull('later.moderated_at')->whereNull('later.archived_at')
            ->where('later.expires_at', '>', now())->limit(1);
    }

    public function reply(Request $request, int $note): JsonResponse
    {
        $max = (int) config('map_notes.max_reply');
        $data = $request->validate([
            'body' => ['required', 'string', "max:$max"],
            'is_anonymous' => ['sometimes', 'boolean'],
            'request_id' => ['sometimes', 'uuid'],
        ], ['body.required' => 'Bir yanıt yaz.', 'body.max' => "Yanıtın en fazla $max karakter olabilir."]);
        $body = trim($data['body']);
        if ($body === '') {
            throw ValidationException::withMessages(['body' => 'Bir yanıt yaz.']);
        }
        $viewer = $request->user();
        $reply = DB::transaction(function () use ($viewer, $note, $data, $body) {
            $entry = MapNote::withTrashed()->lockForUpdate()->find($note);
            // Unknown, removed, blocked and hidden notes are indistinguishable (404); only a plainly expired one explains itself.
            abort_if(! $entry, 404);
            abort_unless(MapNote::visibleTo($viewer)->whereKey($note)->exists() || $this->expiredButOtherwiseVisible($entry, $viewer), 404);
            if ($entry->expires_at->isPast()) {
                throw ValidationException::withMessages(['body' => 'Bu not artık yanıt kabul etmiyor.']);
            }
            User::whereKey($viewer->id)->lockForUpdate()->firstOrFail();
            if (isset($data['request_id'])) {
                $existing = MapNoteReply::withTrashed()->where('user_id', $viewer->id)->where('request_id', $data['request_id'])->first();
                if ($existing) {
                    return $existing->setRelation('note', $entry)->setRelation('author', $viewer);
                }
            }
            app(ContentGuard::class)->check($viewer->id, $body, 'map_note_replies');
            $reply = MapNoteReply::create([
                'map_note_id' => $entry->id, 'user_id' => $viewer->id, 'body' => $body,
                // The owner of an anonymous note can never unmask themselves in its thread.
                'is_anonymous' => (bool) ($data['is_anonymous'] ?? false) || ($entry->is_anonymous && $entry->user_id === $viewer->id),
                'content_hash' => ContentGuard::fingerprint($body), 'request_id' => $data['request_id'] ?? null,
            ]);
            // The actor stays internal (block handling); the notification resource never exposes it.
            Inbox::add($entry->user_id, $viewer->id, 'map_note_reply', $entry->id);

            return $reply->setRelation('note', $entry)->setRelation('author', $viewer);
        });

        return ApiResponse::ok(new MapNoteReplyResource($reply), 'Yanıtın eklendi.', 201);
    }

    public function destroyReply(Request $request, int $reply): JsonResponse
    {
        $entry = MapNoteReply::findOrFail($reply);
        abort_unless($entry->user_id === $request->user()->id, 403);
        $entry->delete();

        return ApiResponse::ok(message: 'Yanıtın kaldırıldı.');
    }

    private function replyPage(User $viewer, MapNote $note)
    {
        return MapNoteReply::visibleTo($viewer)->where('map_note_id', $note->id)->with(['author'])
            ->orderBy('map_note_replies.created_at')->orderBy('map_note_replies.id')
            ->simplePaginate((int) config('map_notes.reply_page_size'))
            ->through(fn (MapNoteReply $reply) => $reply->setRelation('note', $note));
    }

    private function expiredButOtherwiseVisible(MapNote $note, User $viewer): bool
    {
        return $note->deleted_at === null && $note->moderated_at === null && $note->archived_at === null && $note->expires_at->isPast()
            && User::whereKey($note->user_id)->where('account_status', 'active')->exists()
            && ! \App\Safety\Blocks::between($viewer->id, $note->user_id);
    }
}
