<?php

namespace App\Http\Controllers\Admin;

use App\Administration\Audit;
use App\Models\EncounterRequest;
use App\Models\Message;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ModerationController
{
    public function user(Request $request, int $id)
    {
        $data = $request->validate(['action' => 'required|in:suspend,ban,restore,revoke', 'note' => 'nullable|string|max:1000']);
        DB::transaction(function () use ($request, $id, $data): void {
            $this->changeAccount($request, $id, $data['action'], $data['note'] ?? null);
        });
        return back()->with('status', 'Kullanıcı işlemi kaydedildi.');
    }

    private function changeAccount(Request $request, int $id, string $action, ?string $note): void
    {
        $user = User::lockForUpdate()->findOrFail($id);
        abort_unless(in_array($user->account_status, array_keys(RecordsController::STATES), true), 409);
        abort_if($user->erased_at !== null || $user->account_status === 'deleted', 409);
        $before = $user->account_status;
        $status = match ($action) {
            'suspend' => 'suspended', 'ban' => 'banned', 'restore' => 'active', default => $before,
        };
        if ($status !== $before) {
            $user->forceFill(['account_status' => $status])->save();
        }
        if (in_array($action, ['suspend', 'ban', 'revoke'], true)) {
            $user->tokens()->delete();
            DB::table('user_devices')->where('user_id', $id)->update(['is_active' => false]);
            DB::table('user_locations')->where('user_id', $id)->delete();
        }
        Audit::record($request, 'user.'.$action, 'user', $id, ['before' => $before, 'after' => $status, 'note' => $note]);
    }

    public function content(Request $request, string $section, int $id)
    {
        $data = $request->validate(['action' => 'required|in:remove,restore,note', 'note' => 'required_if:action,note|nullable|string|max:1000']);
        DB::transaction(function () use ($request, $section, $id, $data): void {
            $record = match ($section) {
                'posts' => Post::withTrashed()->lockForUpdate()->findOrFail($id),
                'comments' => PostComment::withTrashed()->lockForUpdate()->findOrFail($id),
                'encounters' => EncounterRequest::withTrashed()->lockForUpdate()->findOrFail($id),
            };
            $type = match ($section) {'posts' => 'post', 'comments' => 'comment', 'encounters' => 'encounter'};
            $this->changeContent($request, $record, $type, $data['action'], $data['note'] ?? null);
        });
        return back()->with('status', 'Moderasyon işlemi kaydedildi.');
    }

    private function changeContent(Request $request, Post|PostComment|EncounterRequest|Message|\App\Models\MapNote|\App\Models\MapNoteReply $record, string $type, string $action, ?string $note): void
    {
        if ($record instanceof Message) {
            abort_unless($action === 'remove', 422);
            $record->forceFill(['moderated_at' => now()])->save();
        } elseif ($record instanceof EncounterRequest) {
            abort_if($action === 'restore' && $record->status === 'pending', 409);
            if ($action === 'remove') {
                if ($record->status === 'pending') {
                    $record->update(['status' => 'cancelled', 'responded_at' => now()]);
                }
                $record->delete();
            } elseif ($action === 'restore') {
                $record->restore();
            }
        } elseif ($action === 'remove' && ! $record->trashed()) {
            $record->forceFill(['moderated_at' => now()])->save();
            $record->delete();
            if ($record instanceof PostComment) {
                // A moderated comment (and the replies that go with it) keeps no public like counters.
                DB::table('comment_likes')->whereIn('comment_id', PostComment::withTrashed()->where('id', $record->id)->orWhere('parent_id', $record->id)->select('id'))->delete();
            }
            if ($record instanceof Post) {
                EncounterRequest::where('source_post_id', $record->id)->where('status', 'pending')
                    ->update(['status' => 'cancelled', 'responded_at' => now()]);
                DB::table('location_matches')->where('post_id', $record->id)->delete();
            }
        } elseif ($action === 'restore') {
            abort_unless($record->moderated_at !== null, 409);
            $record->restore();
            $record->forceFill(['moderated_at' => null])->save();
        }
        Audit::record($request, $type.'.'.$action, $type, $record->id, ['note' => $note]);
    }

    public function report(Request $request, int $id, RecordsController $records)
    {
        $data = $request->validate([
            'status' => ['required', Rule::in(array_keys(RecordsController::REPORT_STATES))],
            'action' => 'nullable|in:remove,suspend,ban', 'note' => 'nullable|string|max:1000',
        ]);
        DB::transaction(function () use ($request, $id, $records, $data): void {
            $report = DB::table('reports')->lockForUpdate()->find($id) ?? abort(404);
            $action = $data['action'] ?? null;
            $note = $data['note'] ?? null;
            if ($action) {
                $target = $records->reportedTarget($report) ?? abort(404);
                if ($action === 'remove') {
                    abort_if($target instanceof User, 422);
                    $target = $target instanceof Message
                        ? Message::lockForUpdate()->findOrFail($target->id)
                        : $target::withTrashed()->lockForUpdate()->findOrFail($target->id);
                    $this->changeContent($request, $target, $report->target_type, 'remove', $note);
                } else {
                    $owner = $target instanceof User ? $target->id : ($target->user_id ?? $target->sender_id ?? null);
                    abort_unless($owner, 422);
                    $this->changeAccount($request, $owner, $action, $note);
                }
            }
            DB::table('reports')->where('id', $id)->update(['status' => $data['status'], 'reviewed_at' => now()]);
            Audit::record($request, 'report.'.$data['status'], 'report', $id, ['before' => $report->status, 'note' => $note]);
        });
        return back()->with('status', 'Şikâyet güncellendi.');
    }

    public function featured(Request $request, int $id)
    {
        $data = $request->validate(['rank' => 'present|nullable|integer|min:1|max:9999']);
        DB::transaction(function () use ($request, $data, $id): void {
            $post = Post::where('story_status', Post::STORY_PUBLISHED)->where('visibility', 'city')
                ->whereHas('jointEncounter.invitation', fn ($pair) => $pair->activePair()->where('status', 'accepted'))
                ->lockForUpdate()->findOrFail($id);
            $post->forceFill(['featured_rank' => $data['rank']])->save();
            Audit::record($request, 'featured.update', 'post', $id, ['rank' => $data['rank']]);
        });
        return back()->with('status', 'Öne çıkan sırası güncellendi.');
    }
}
