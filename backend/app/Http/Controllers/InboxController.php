<?php

namespace App\Http\Controllers;

use App\Http\ApiResponse;
use App\Http\Resources\PublicUserResource;
use App\Models\User;
use App\Notifications\Inbox;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;

class InboxController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $page = Inbox::query($request->user()->id)->when($request->boolean('unread'), fn ($query) => $query->whereNull('read_at'))
            ->latest('id')->simplePaginate(20);
        $actors = User::with('city')->whereKey(collect($page->items())->pluck('actor_id')->filter()->all())
            ->where('account_status', 'active')->get()->keyBy('id');
        $announcements = DB::table('announcements')->whereIn('id', collect($page->items())->pluck('announcement_id')->filter()->all())
            ->get(['id', 'title', 'body'])->keyBy('id');
        $available = \App\Notifications\Targets::available($request->user(), $page->items());
        return ApiResponse::ok(['items' => collect($page->items())->map(fn ($item) =>
            $this->resource($item, $actors->get($item->actor_id), $announcements->get($item->announcement_id), $available[$item->id])),
            'next_page' => $page->hasMorePages() ? $page->currentPage() + 1 : null]);
    }

    public function show(Request $request, int $notification): JsonResponse
    {
        $item = Inbox::query($request->user()->id, includePushOnly: true)->where('id', $notification)->firstOrFail();
        return ApiResponse::ok($this->resource($item, User::with('city')->where('account_status', 'active')->find($item->actor_id),
            $item->announcement_id ? DB::table('announcements')->find($item->announcement_id) : null,
            \App\Notifications\Targets::available($request->user(), [$item])[$item->id]));
    }

    private function resource(object $item, ?User $actor, ?object $announcement, bool $available): array
    {
        [$route, $message] = Inbox::TYPES[$item->type];
        if (!$available) $announcement = null;
        return ['id' => $item->id, 'type' => $item->type, 'route' => $route, 'entity_id' => $item->entity_id, 'available' => $available,
            // Location-derived and map-note notifications never carry another account's identity (replies may be anonymous).
            'actor' => $actor && ! in_array($item->type, ['nearby_activity', 'map_note_nearby', 'map_note_reply'], true) ? new PublicUserResource($actor) : null,
            'text' => $announcement?->title ?? $message,
            ...(isset(Inbox::SUBTITLES[$item->type]) ? ['subtitle' => Inbox::SUBTITLES[$item->type]] : []),
            ...($announcement ? ['announcement_body' => $announcement->body] : []),
            'read' => $item->read_at !== null, 'created_at' => Carbon::parse($item->created_at)->toISOString()];
    }

    public function read(Request $request, ?int $notification = null): JsonResponse
    {
        $query = Inbox::query($request->user()->id, includePushOnly: $notification !== null);
        if ($notification !== null) {
            $query->where('id', $notification)->firstOrFail();
        }
        $query->whereNull('read_at')->update(['read_at' => now()]);
        return ApiResponse::ok();
    }

    public function disableDevice(Request $request, string $device): JsonResponse
    {
        DB::table('user_devices')->where('user_id', $request->user()->id)
            ->where('device_identifier', $device)->update(['is_active' => false]);
        return ApiResponse::ok();
    }

    public function device(Request $request): JsonResponse
    {
        $data = $request->validate([
            'device_identifier' => 'required|uuid', 'platform' => 'required|in:android,ios',
            'push_token' => 'required|string|min:12|max:4096', 'app_version' => 'nullable|string|max:32',
        ]);
        $token = $request->user()->currentAccessToken();
        $hash = hash('sha256', $data['push_token']);
        DB::transaction(function () use ($request, $token, $data, $hash): void {
            $devices = DB::table('user_devices');
            (clone $devices)->where('token_hash', $hash)->where('device_identifier', '<>', $data['device_identifier'])->delete();
            $devices->upsert([[
                ...$data, 'push_token' => Crypt::encryptString($data['push_token']), 'token_hash' => $hash,
                'user_id' => $request->user()->id, 'personal_access_token_id' => $token->id,
                'last_seen_at' => now(), 'is_active' => true,
            ]], ['device_identifier'], ['platform', 'push_token', 'token_hash', 'app_version', 'user_id',
                'personal_access_token_id', 'last_seen_at', 'is_active']);
        }, 3);
        return ApiResponse::ok();
    }
}
