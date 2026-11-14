<?php

namespace App\Http\Controllers;

use App\Http\ApiResponse;
use App\Http\Resources\PublicUserResource;
use App\Models\Conversation;
use App\Models\MapNote;
use App\Models\MapNoteReply;
use App\Models\EncounterRequest;
use App\Models\Message;
use App\Models\Post;
use App\Models\User;
use App\Safety\Blocks;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class SafetyController extends Controller
{
    public function blocks(Request $request): JsonResponse
    {
        $viewer = $request->user()->id;
        // Accounts of the other age band stay unreachable (and unnamed) even if they were blocked long ago.
        return ApiResponse::page(\App\Safety\AgeSafety::scope(User::with('city')->whereIn('users.id', DB::table('user_blocks')->where('blocker_id', $viewer)
            ->select('blocked_id')), $viewer)->orderBy('users.id')->simplePaginate(20), PublicUserResource::class);
    }

    public function block(Request $request, int $user): JsonResponse
    {
        $id = $request->user()->id;
        abort_if($id === $user, 422);
        User::findOrFail($user);
        abort_unless(\App\Safety\AgeSafety::sameBand($id, $user), 404);
        DB::transaction(function () use ($request, $id, $user): void {
            Blocks::lockPair($id, $user);
            $key = ['blocker_id' => $id, 'blocked_id' => $user];
            if ($request->isMethod('DELETE')) {
                DB::table('user_blocks')->where($key)->delete();
                return;
            }
            DB::table('user_blocks')->insertOrIgnore($key + ['created_at' => now()]);
            DB::table('user_follows')->where(['follower_id' => $id, 'followed_id' => $user])
                ->orWhere(['follower_id' => $user, 'followed_id' => $id])->delete();
            EncounterRequest::participant($id)->participant($user)->where('status', 'pending')
                ->update(['status' => 'cancelled', 'responded_at' => now()]);
            Conversation::forMember($id)->forMember($user)->where('status', 'pending')
                ->update(['status' => 'cancelled', 'responded_at' => now()]);
            DB::table('app_notifications')->where(['user_id' => $id, 'actor_id' => $user])
                ->orWhere(['user_id' => $user, 'actor_id' => $id])->delete();
        });
        return ApiResponse::ok();
    }

    public function report(Request $request): JsonResponse
    {
        $data = $request->validate([
            'target_type' => ['required', Rule::in(['user', 'post', 'comment', 'message', 'encounter_story', 'map_note', 'map_note_reply', 'system'])],
            'target_id' => 'required|integer|min:0',
            'reason' => ['required', Rule::in(['harassment', 'spam', 'fake', 'inappropriate', 'hate', 'privacy', 'other'])],
            'description' => 'required_if:reason,other|nullable|string|max:1000',
        ]);
        $viewer = $request->user();
        $target = (int) $data['target_id'];
        $type = $data['target_type'];
        $owner = match ($type) {
            'user' => User::where('account_status', 'active')->findOrFail($target)->id,
            'post', 'encounter_story' => Post::visibleTo($viewer)
                ->when($type === 'encounter_story', fn ($query) => $query->whereNotNull('encounter_id'))->findOrFail($target)->user_id,
            'comment' => DB::table('post_comments')->where('id', $target)
                ->whereIn('post_id', Post::visibleTo($viewer)->select('id'))->firstOrFail()->user_id,
            'message' => Message::whereIn('conversation_id', Conversation::forMember($viewer->id)->select('id'))->findOrFail($target)->sender_id,
            'map_note' => MapNote::visibleTo($viewer)->findOrFail($target)->user_id,
            'map_note_reply' => MapNoteReply::visibleTo($viewer)->whereIn('map_note_id', MapNote::visibleTo($viewer)->select('map_notes.id'))->findOrFail($target)->user_id,
            'system' => $target === 0 ? null : abort(422),
        };
        abort_if($owner === $viewer->id, 422);
        if ($type === 'post' && Post::whereKey($target)->whereNotNull('encounter_id')->exists()) {
            $type = 'encounter_story';
        }
        $inserted = DB::table('reports')->insertOrIgnore([
            ...$data, 'target_type' => $type, 'reporter_id' => $viewer->id, 'status' => 'pending', 'created_at' => now(),
        ]);
        return ApiResponse::ok(message: 'Şikâyetin alındı.', status: $inserted ? 201 : 200);
    }
}
