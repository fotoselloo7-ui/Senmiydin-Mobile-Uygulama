<?php

namespace App\Http\Controllers\Admin;

use App\Administration\Audit;
use App\Models\MapNote;
use App\Models\MapNoteReply;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Moderation of map notes and replies. Admins see the real owner of anonymous content; normal users never do.
 */
class MapNotesController
{
    public const STATES = ['active' => 'Aktif', 'expired' => 'Süresi doldu', 'removed' => 'Kaldırıldı'];

    public static function state(MapNote $note): string
    {
        return $note->deleted_at !== null || $note->moderated_at !== null ? 'removed'
            : ($note->expires_at->isPast() ? 'expired' : 'active');
    }

    public function index(Request $request)
    {
        $f = $request->validate(['q' => 'nullable|string|max:100', 'status' => 'nullable|in:active,expired,removed',
            'anonymous' => 'nullable|boolean', 'reported' => 'nullable|boolean']);
        $q = isset($f['q']) ? '%'.str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $f['q']).'%' : null;
        $reports = DB::table('reports')->where('target_type', 'map_note')->select('target_id');
        $rows = MapNote::withTrashed()->with(['author', 'city'])
            ->withCount(['replies as reply_count' => fn ($replies) => $replies->whereNull('deleted_at')])
            ->when($q, fn ($items) => $items->whereRaw("body LIKE ? ESCAPE '!'", [$q]))
            ->when(isset($f['anonymous']), fn ($items) => $items->where('is_anonymous', $f['anonymous']))
            ->when(isset($f['reported']), fn ($items) => $f['reported'] ? $items->whereIn('map_notes.id', $reports) : $items->whereNotIn('map_notes.id', $reports))
            ->when(($f['status'] ?? null) === 'active', fn ($items) => $items->whereNull('deleted_at')->whereNull('moderated_at')->where('expires_at', '>', now()))
            ->when(($f['status'] ?? null) === 'expired', fn ($items) => $items->whereNull('deleted_at')->whereNull('moderated_at')->where('expires_at', '<=', now()))
            ->when(($f['status'] ?? null) === 'removed', fn ($items) => $items->where(fn ($x) => $x->whereNotNull('deleted_at')->orWhereNotNull('moderated_at')))
            ->orderByDesc('id')->paginate(25)->withQueryString();
        $reportCounts = DB::table('reports')->where('target_type', 'map_note')->whereIn('target_id', $rows->pluck('id'))
            ->selectRaw('target_id, COUNT(*) AS total')->groupBy('target_id')->pluck('total', 'target_id');

        return view('admin.map_notes', ['title' => 'Harita Notları', 'section' => 'map-notes', 'rows' => $rows,
            'filters' => $f, 'reportCounts' => $reportCounts]);
    }

    public function detail(Request $request, int $id)
    {
        $note = MapNote::withTrashed()->with(['author', 'city'])->findOrFail($id);
        $replies = MapNoteReply::withTrashed()->with('author')->where('map_note_id', $id)->orderBy('created_at')->orderBy('id')->limit(200)->get();
        $reports = DB::table('reports')->where(fn ($x) => $x->where('target_type', 'map_note')->where('target_id', $id)
            ->orWhere(fn ($r) => $r->where('target_type', 'map_note_reply')->whereIn('target_id', $replies->pluck('id'))))
            ->latest('id')->limit(30)->get();
        $history = DB::table('admin_audit_logs')->leftJoin('admins', 'admins.id', '=', 'admin_audit_logs.admin_id')
            ->whereIn('target_type', ['map_note', 'map_note_reply'])
            ->where(fn ($x) => $x->where(fn ($n) => $n->where('target_type', 'map_note')->where('target_id', $id))
                ->orWhere(fn ($r) => $r->where('target_type', 'map_note_reply')->whereIn('target_id', $replies->pluck('id'))))
            ->select('admin_audit_logs.*', 'admins.name as admin_name')->latest('admin_audit_logs.id')->limit(20)->get();

        return view('admin.map_note_detail', ['title' => 'Harita Notları', 'section' => 'map-notes', 'note' => $note,
            'replies' => $replies, 'reports' => $reports, 'history' => $history, 'state' => self::state($note)]);
    }

    public function moderate(Request $request, int $id)
    {
        $data = $request->validate(['action' => 'required|in:remove,restore', 'note' => 'nullable|string|max:1000']);
        DB::transaction(function () use ($request, $id, $data): void {
            $note = MapNote::withTrashed()->lockForUpdate()->findOrFail($id);
            if ($data['action'] === 'remove' && ! $note->trashed()) {
                $note->forceFill(['moderated_at' => now()])->save();
                $note->delete();
            } elseif ($data['action'] === 'restore') {
                abort_unless($note->moderated_at !== null, 409);
                $note->restore();
                $note->forceFill(['moderated_at' => null])->save();
            }
            Audit::record($request, 'map_note.'.$data['action'], 'map_note', $id, ['note' => $data['note'] ?? null]);
        });

        return back()->with('status', 'Moderasyon işlemi kaydedildi.');
    }

    public function moderateReply(Request $request, int $id)
    {
        $data = $request->validate(['action' => 'required|in:remove,restore', 'note' => 'nullable|string|max:1000']);
        DB::transaction(function () use ($request, $id, $data): void {
            $reply = MapNoteReply::withTrashed()->lockForUpdate()->findOrFail($id);
            if ($data['action'] === 'remove' && ! $reply->trashed()) {
                $reply->forceFill(['moderated_at' => now()])->save();
                $reply->delete();
            } elseif ($data['action'] === 'restore') {
                abort_unless($reply->moderated_at !== null, 409);
                $reply->restore();
                $reply->forceFill(['moderated_at' => null])->save();
            }
            Audit::record($request, 'map_note_reply.'.$data['action'], 'map_note_reply', $id, ['note' => $data['note'] ?? null]);
        });

        return back()->with('status', 'Moderasyon işlemi kaydedildi.');
    }
}
