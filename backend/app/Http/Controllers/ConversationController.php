<?php

namespace App\Http\Controllers;

use App\Http\ApiResponse;
use App\Http\Resources\PublicUserResource;
use App\Media\PrivateImage;
use App\Media\VoiceMessage;
use App\Models\Conversation;
use App\Models\EncounterRequest;
use App\Models\Gift;
use App\Models\Message;
use App\Models\User;
use App\Notifications\Inbox;
use App\Location\Geo;
use App\Safety\Blocks;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\Response;

class ConversationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate(['requests' => 'sometimes|boolean', 'q' => 'sometimes|string|max:80']);
        $id = $request->user()->id;
        $requests = $request->boolean('requests');
        $query = Conversation::available($id)->select('conversations.*')
            ->join('conversation_participants as member', 'member.conversation_id', '=', 'conversations.id')
            ->where('member.user_id', $id)->whereIn('status', $requests ? ['pending'] : ['active'])
            ->whereExists(fn ($query) => $query->selectRaw('1')->from('messages')
                ->whereColumn('messages.conversation_id', 'conversations.id')->whereColumn('messages.id', '>', 'member.hidden_through')->whereNull('messages.moderated_at')
                ->whereNull('messages.recalled_at')
                ->where(fn ($visible) => $visible->where(fn ($theirs) => $theirs->where('sender_id', '<>', $id)->whereNull('recipient_hidden_at'))
                    ->orWhere(fn ($mine) => $mine->where('sender_id', $id)->whereNull('deleted_at'))));
        if (! empty($data['q'])) {
            $pattern = '%'.str_replace(['!', '%', '_'], ['!!', '!%', '!_'], Str::lower(ltrim($data['q'], '@'))).'%';
            $peers = User::query()->where('id', '<>', $id)->where(fn ($match) =>
                $match->whereRaw("LOWER(name) LIKE ? ESCAPE '!'", [$pattern])
                    ->orWhereRaw("username LIKE ? ESCAPE '!'", [$pattern]))->select('id');
            $query->where(fn ($pair) => $pair->whereIn('first_user_id', clone $peers)->orWhereIn('second_user_id', $peers));
        }
        $page = $query->addSelect([
            'last_message_id' => $this->visibleMessages($id)->select('id')->whereColumn('conversation_id', 'conversations.id')->latest('id')->limit(1),
            'unread_total' => Message::query()->selectRaw('COUNT(*)')->whereColumn('conversation_id', 'conversations.id')
                ->where('sender_id', '<>', $id)->whereNull('moderated_at')->whereNull('recalled_at')->whereNull('recipient_hidden_at')->whereNull('read_at')->whereColumn('id', '>', 'member.hidden_through'),
        ])->orderByDesc('last_message_id')->orderByDesc('conversations.id')->simplePaginate(20);
        $peers = User::with('city')->whereKey(collect($page->items())->map(fn ($chat) => $chat->otherId($id))->all())->get()->keyBy('id');
        $messages = Message::with('gift')->whereKey(collect($page->items())->pluck('last_message_id')->filter()->all())->get()->keyBy('id');
        return ApiResponse::ok(['items' => collect($page->items())->map(fn ($chat) =>
            $this->summary($chat, $peers[$chat->otherId($id)], $id, $messages->get($chat->last_message_id), (int) $chat->unread_total)),
            'next_page' => $page->hasMorePages() ? $page->currentPage() + 1 : null]);
    }

    public function peer(Request $request, int $user): JsonResponse
    {
        $viewer = $request->user();
        $peer = $this->getPeer($viewer->id, $user);
        return ApiResponse::ok($this->summary($this->pair($viewer->id, $peer->id)->first(), $peer, $viewer->id,
            allowed: $this->permitsRequest($viewer, $peer)));
    }

    public function show(Request $request, int $conversation): JsonResponse
    {
        $id = $request->user()->id;
        $chat = Conversation::available($id)->findOrFail($conversation);
        $peer = $this->getPeer($id, $chat->otherId($id));
        return ApiResponse::ok($this->summary($chat, $peer, $id, allowed: $this->permitsRequest($request->user(), $peer)));
    }

    public function messages(Request $request, int $conversation): JsonResponse
    {
        $id = $request->user()->id;
        Conversation::available($id)->findOrFail($conversation);
        $data = $request->validate(['before' => 'sometimes|integer|min:1', 'after' => 'sometimes|integer|min:0|prohibits:before']);
        $query = $this->visibleMessages($id)->with('gift')->where('conversation_id', $conversation);
        if (isset($data['before'])) {
            $query->where('id', '<', $data['before']);
        }
        if (isset($data['after'])) {
            $query->where('id', '>', $data['after'])->oldest('id');
        } else {
            $query->latest('id');
        }
        $items = $query->limit(31)->get();
        return ApiResponse::ok(['items' => $items->take(30)->map(fn ($message) => $this->message($message, $id))->values(),
            'has_more' => $items->count() > 30]);
    }

    public function send(Request $request, int $user): JsonResponse
    {
        $viewer = $request->user();
        $peer = $this->getPeer($viewer->id, $user);
        $data = $request->validate([
            'body' => 'required_without_all:image,latitude,audio,gift|nullable|string|max:2000',
            'request_id' => 'required|uuid',
            'image' => 'sometimes|prohibits:latitude,audio,gift|'.PrivateImage::RULES,
            // A voice message: one AAC/M4A file. The server reads the duration from the file itself.
            'audio' => 'sometimes|prohibits:image,latitude,gift|'.VoiceMessage::rules(),
            // A gift: only the slug of an active catalog entry (the catalog lives on the server).
            'gift' => ['sometimes', 'prohibits:image,latitude,audio', 'string', Rule::exists('gifts', 'slug')->where('is_active', true)],
            // A private location message: one approximate point, never live tracking.
            'latitude' => 'nullable|required_with:longitude|numeric|between:-90,90',
            'longitude' => 'nullable|required_with:latitude|numeric|between:-180,180',
            'place_label' => 'sometimes|nullable|string|max:80',
        ]);
        $point = isset($data['latitude'], $data['longitude']) ? [
            Geo::grid((float) $data['latitude'], (float) config('location.message_grid')),
            Geo::grid((float) $data['longitude'], (float) config('location.message_grid')),
        ] : null;
        $disk = Storage::disk(config('mobile.post_media_disk'));
        $path = null;
        $audioPath = null;
        $voice = isset($data['audio']) ? VoiceMessage::inspect($data['audio']) : null;
        $gift = isset($data['gift']) ? Gift::active()->where('slug', $data['gift'])->firstOrFail() : null;
        try {
            [$chat, $message, $created] = DB::transaction(function () use ($viewer, $peer, $data, $disk, $point, $voice, $gift, &$path, &$audioPath) {
                Blocks::lockPair($viewer->id, $peer->id);
                $peer->refresh();
                abort_unless($peer->account_status === 'active' && ! Blocks::between($viewer->id, $peer->id), 403);
                $chat = $this->pair($viewer->id, $peer->id)->lockForUpdate()->first();
                $existing = Message::where('sender_id', $viewer->id)->where('request_id', $data['request_id'])->first();
                if ($existing) {
                    abort_unless($chat && $existing->conversation_id === $chat->id && ! $existing->deleted_at && ! $existing->moderated_at, 409);
                    return [$chat, $existing, false];
                }
                if (! $chat || $chat->canRequestAgain()) {
                    abort_unless($this->permitsRequest($viewer, $peer), 403, 'Bu kullanıcının mesaj isteği tercihleri bu isteğe izin vermiyor.');
                    abort_if(Conversation::where('requester_id', $viewer->id)->where('status', 'pending')->where('updated_at', '>=', now()->subHour())->count() >= 15, 429);
                    if ($chat) {
                        $chat->update(['requester_id' => $viewer->id, 'status' => 'pending', 'responded_at' => null]);
                    } else {
                        $chat = Conversation::create([
                            'first_user_id' => min($viewer->id, $peer->id), 'second_user_id' => max($viewer->id, $peer->id),
                            'requester_id' => $viewer->id, 'status' => 'pending',
                        ]);
                        DB::table('conversation_participants')->insert([
                            ['conversation_id' => $chat->id, 'user_id' => $viewer->id],
                            ['conversation_id' => $chat->id, 'user_id' => $peer->id],
                        ]);
                    }
                    $type = 'message_request';
                } elseif ($chat->status === 'active') {
                    $type = 'message';
                } else {
                    abort(409, 'Yeni mesaj göndermek için isteğin kabul edilmesi gerekir.');
                }
                if (isset($data['image'])) {
                    [$bytes] = PrivateImage::jpeg($data['image'], 'image');
                    $path = 'messages/'.Str::uuid().'.jpg';
                    abort_unless($bytes && $disk->put($path, $bytes, 'private'), 503);
                }
                if ($voice) {
                    // A random name on the private disk: nothing of the uploaded file name is ever used.
                    $audioPath = 'voice/'.Str::uuid().'.m4a';
                    abort_unless($disk->put($audioPath, $voice[0], 'private'), 503);
                }
                $message = Message::create([
                    'conversation_id' => $chat->id, 'sender_id' => $viewer->id, 'request_id' => $data['request_id'],
                    'body' => $data['body'] ?? '', 'type' => $voice ? 'voice' : ($gift ? 'gift' : ($path ? 'image' : ($point ? 'location' : 'text'))),
                    'image_path' => $path, 'audio_path' => $audioPath, 'audio_duration_ms' => $voice[1] ?? null, 'gift_id' => $gift?->id,
                    ...($point ? ['approx_latitude' => $point[0], 'approx_longitude' => $point[1], 'place_label' => $data['place_label'] ?? null] : []),
                ]);
                $chat->touch();
                Inbox::add($peer->id, $viewer->id, $type, $chat->id);
                return [$chat, $message, true];
            });
        } catch (\Throwable $error) {
            if ($path && ! Message::where('image_path', $path)->exists()) {
                $disk->delete($path);
            }
            if ($audioPath && ! Message::where('audio_path', $audioPath)->exists()) {
                $disk->delete($audioPath);
            }
            throw $error;
        }
        return ApiResponse::ok(['conversation' => $this->summary($chat, $peer, $viewer->id),
            'message' => $this->message($message, $viewer->id)], status: $created ? 201 : 200);
    }

    public function respond(Request $request, int $conversation, string $action): JsonResponse
    {
        $id = $request->user()->id;
        $chat = Conversation::available($id)->findOrFail($conversation);
        $peer = $this->getPeer($id, $chat->otherId($id));
        $status = $action === 'accept' ? 'active' : 'rejected';
        $chat = DB::transaction(function () use ($id, $peer, $conversation, $status) {
            Blocks::lockPair($id, $peer->id);
            $chat = Conversation::available($id)->lockForUpdate()->findOrFail($conversation);
            abort_if($chat->requester_id === $id, 403);
            if ($chat->status !== $status) {
                abort_unless($chat->status === 'pending', 409);
                $chat->update(['status' => $status, 'responded_at' => now()]);
                if ($status === 'active') {
                    Inbox::add($peer->id, $id, 'message', $chat->id);
                } else {
                    Message::where('conversation_id', $chat->id)->whereNull('read_at')->update(['read_at' => now()]);
                }
            }
            return $chat;
        });
        return ApiResponse::ok($this->summary($chat, $peer, $id));
    }

    public function read(Request $request, int $conversation): JsonResponse
    {
        $id = $request->user()->id;
        $data = $request->validate(['through' => 'required|integer|min:1']);
        Conversation::available($id)->findOrFail($conversation);
        abort_unless(Message::where('conversation_id', $conversation)->whereKey($data['through'])->exists(), 422);
        Message::where('conversation_id', $conversation)->where('id', '<=', $data['through'])
            ->where('sender_id', '<>', $id)->whereNull('moderated_at')->whereNull('read_at')->update(['read_at' => now()]);
        return ApiResponse::ok();
    }

    public function hide(Request $request, int $conversation): JsonResponse
    {
        $id = $request->user()->id;
        $chat = Conversation::available($id)->findOrFail($conversation);
        $latest = Message::where('conversation_id', $chat->id)->max('id') ?? 0;
        DB::table('conversation_participants')->where('conversation_id', $chat->id)->where('user_id', $id)
            ->where('hidden_through', '<', $latest)->update(['hidden_through' => $latest]);
        return ApiResponse::ok();
    }

    public function deleteMessage(Request $request, int $conversation, int $message): JsonResponse
    {
        $id = $request->user()->id;
        Conversation::available($id)->findOrFail($conversation);
        $item = Message::where('conversation_id', $conversation)->findOrFail($message);
        $scope = $request->validate(['scope' => 'sometimes|in:me,everyone'])['scope'] ?? 'me';
        if ($item->sender_id === $id) {
            // The sender may delete a message for themselves, or take it back for everyone (the other person no longer sees it).
            $item->update($scope === 'everyone'
                ? ['deleted_at' => $item->deleted_at ?? now(), 'recalled_at' => $item->recalled_at ?? now()]
                : ['deleted_at' => $item->deleted_at ?? now()]);
            return ApiResponse::ok();
        }
        // The person who received it can only remove it from their own view; it stays for its sender.
        abort_unless($scope === 'me', 403);
        if (! $item->recipient_hidden_at) {
            $item->update(['recipient_hidden_at' => now()]);
        }
        return ApiResponse::ok();
    }

    public function image(Request $request, int $message): Response
    {
        $id = $request->user()->id;
        $item = $this->visibleMessages($id)->whereNotNull('image_path')->findOrFail($message);
        Conversation::available($id)->findOrFail($item->conversation_id);
        $disk = Storage::disk(config('mobile.post_media_disk'));
        abort_unless($disk->exists($item->image_path), 404);
        return $disk->response($item->image_path, 'fotoğraf.jpg', [
            'Content-Type' => 'image/jpeg', 'Cache-Control' => 'private, no-store', 'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    /** The voice file of a message the viewer may see; same visibility rules as message photos. */
    public function audio(Request $request, int $message): Response
    {
        $id = $request->user()->id;
        $item = $this->visibleMessages($id)->whereNotNull('audio_path')->findOrFail($message);
        Conversation::available($id)->findOrFail($item->conversation_id);
        $disk = Storage::disk(config('mobile.post_media_disk'));
        abort_unless($disk->exists($item->audio_path), 404);

        return $disk->response($item->audio_path, 'ses.m4a', [
            'Content-Type' => 'audio/mp4', 'Cache-Control' => 'private, no-store', 'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    /** The active gift catalog, in the request language. */
    public function gifts(): JsonResponse
    {
        return ApiResponse::ok(['items' => Gift::active()->get()->map->toApi()->values()]);
    }

    public function unread(Request $request): JsonResponse
    {
        $user = $request->user();
        $id = $user->id;
        if ($user->show_activity && (! $user->last_seen_at || $user->last_seen_at->lt(now()->subMinutes(2)))) {
            $user->forceFill(['last_seen_at' => now()])->saveQuietly();
        }
        $messages = Message::query()->join('conversation_participants as member', 'member.conversation_id', '=', 'messages.conversation_id')
            ->where('member.user_id', $id)->whereColumn('messages.id', '>', 'member.hidden_through')
            ->whereIn('messages.conversation_id', Conversation::available($id)->whereIn('status', ['active', 'pending'])->select('id'))
            ->where('sender_id', '<>', $id)->whereNull('moderated_at')->whereNull('recalled_at')->whereNull('recipient_hidden_at')->whereNull('read_at')->count();
        // Incoming message requests still waiting for an answer (a stranger's first message lands in "İstekler").
        $requests = Conversation::available($id)->where('status', 'pending')->where('requester_id', '<>', $id)
            ->whereExists(fn ($query) => $query->selectRaw('1')->from('messages')
                ->whereColumn('messages.conversation_id', 'conversations.id')->where('messages.sender_id', '<>', $id)
                ->whereNull('messages.moderated_at')->whereNull('messages.recalled_at')->whereNull('messages.recipient_hidden_at')->whereNull('messages.read_at'))->count();

        return ApiResponse::ok(['messages' => $messages, 'requests' => $requests, 'notifications' => Inbox::query($id)->whereNull('read_at')->count()]);
    }

    private function visibleMessages(int $user): Builder
    {
        // What the viewer may see: not moderated, not taken back by its sender, not hidden by them. A message they sent
        // and deleted "for me" is gone for them only; one they received and hid is gone for them only.
        return Message::whereNull('moderated_at')->whereNull('recalled_at')->where(fn ($query) => $query
            ->where(fn ($theirs) => $theirs->where('sender_id', '<>', $user)->whereNull('recipient_hidden_at'))
            ->orWhere(fn ($mine) => $mine->where('sender_id', $user)->whereNull('deleted_at')));
    }

    private function pair(int $a, int $b): Builder
    {
        return Conversation::where('first_user_id', min($a, $b))->where('second_user_id', max($a, $b));
    }

    private function getPeer(int $viewer, int $id): User
    {
        abort_if($viewer === $id, 422);
        return Blocks::exclude(User::with('city')->where('account_status', 'active'), $viewer, 'users.id')->findOrFail($id);
    }

    private function permitsRequest(User $viewer, User $peer): bool
    {
        return match ($peer->message_privacy) {
            'following' => $peer->following()->where('users.id', $viewer->id)->exists(),
            'encounters' => EncounterRequest::where('status', 'accepted')->participant($peer->id)->participant($viewer->id)->exists(),
            default => true,
        };
    }

    private function summary(?Conversation $chat, User $peer, int $viewer, ?Message $last = null, int $unread = 0, bool $allowed = true): array
    {
        return ['id' => $chat?->id, 'peer' => new PublicUserResource($peer),
            'status' => $chat?->status ?? 'new', 'outgoing' => $chat?->requester_id === $viewer,
            'can_send' => $chat?->status === 'active' || ($allowed && ($chat === null || $chat->canRequestAgain())),
            'recently_active' => $peer->show_activity && $peer->last_seen_at?->gte(now()->subMinutes(15)),
            'unread' => $unread, 'last_message' => $last ? $this->message($last, $viewer) : null];
    }

    private function message(Message $message, int $viewer): array
    {
        return ['id' => $message->id, 'body' => $message->body, 'type' => $message->type,
            'mine' => $message->sender_id === $viewer, 'request_id' => $message->sender_id === $viewer ? $message->request_id : null,
            'image' => $message->image_path ? route('messages.image', ['message' => $message->id], false) : null,
            // Location messages expose only the snapped approximate point (never the point the sender's device reported).
            ...($message->type === 'voice' ? ['audio' => route('messages.audio', ['message' => $message->id], false),
                'duration_ms' => (int) $message->audio_duration_ms] : []),
            ...($message->type === 'gift' && $message->gift ? ['gift' => $message->gift->toApi()] : []),
            ...($message->type === 'location' ? ['location' => [
                'latitude' => (float) $message->approx_latitude, 'longitude' => (float) $message->approx_longitude,
                'place_label' => $message->place_label,
            ]] : []),
            'read_at' => $message->read_at?->toISOString(), 'created_at' => $message->created_at->toISOString()];
    }
}
