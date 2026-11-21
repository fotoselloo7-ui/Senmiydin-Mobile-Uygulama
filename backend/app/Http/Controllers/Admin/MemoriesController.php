<?php

namespace App\Http\Controllers\Admin;

use App\Administration\Audit;
use App\Models\Memory;
use App\Models\MemoryMedia;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Moderation of memories (Anılar). Admins see the real owner, the visibility, the photos and every report; they can
 * remove a memory from everyone (including its owner) and bring it back. Every action leaves an audit log entry.
 */
class MemoriesController
{
    public const STATES = ['active' => 'Aktif', 'hidden' => 'Sahibi gizledi', 'removed' => 'Kaldırıldı'];

    public const VISIBILITIES = ['private' => 'Sadece sahibi', 'followers' => 'Takipçileri', 'public' => 'Herkes', 'area' => 'Bölgedekiler'];

    public static function state(Memory $memory): string
    {
        return $memory->deleted_at !== null || $memory->moderated_at !== null ? 'removed' : ($memory->is_hidden ? 'hidden' : 'active');
    }

    public function index(Request $request)
    {
        $f = $request->validate(['q' => 'nullable|string|max:100', 'status' => 'nullable|in:active,hidden,removed',
            'visibility' => 'nullable|in:private,followers,public,area', 'reported' => 'nullable|boolean']);
        $q = isset($f['q']) ? '%'.str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $f['q']).'%' : null;
        $reports = DB::table('reports')->where('target_type', 'memory')->select('target_id');
        $rows = Memory::withTrashed()->with(['author', 'city'])->withCount('media')
            ->when($q, fn ($items) => $items->whereRaw("body LIKE ? ESCAPE '!'", [$q]))
            ->when(isset($f['visibility']), fn ($items) => $items->where('visibility', $f['visibility']))
            ->when(isset($f['reported']), fn ($items) => $f['reported'] ? $items->whereIn('memories.id', $reports) : $items->whereNotIn('memories.id', $reports))
            ->when(($f['status'] ?? null) === 'active', fn ($items) => $items->whereNull('deleted_at')->whereNull('moderated_at')->where('is_hidden', false))
            ->when(($f['status'] ?? null) === 'hidden', fn ($items) => $items->whereNull('deleted_at')->whereNull('moderated_at')->where('is_hidden', true))
            ->when(($f['status'] ?? null) === 'removed', fn ($items) => $items->where(fn ($x) => $x->whereNotNull('deleted_at')->orWhereNotNull('moderated_at')))
            ->orderByDesc('memories.id')->paginate(25)->withQueryString();
        $reportCounts = DB::table('reports')->where('target_type', 'memory')->whereIn('target_id', $rows->pluck('id'))
            ->selectRaw('target_id, COUNT(*) AS total')->groupBy('target_id')->pluck('total', 'target_id');

        return view('admin.memories', ['title' => 'Anılar', 'section' => 'memories', 'rows' => $rows, 'filters' => $f, 'reportCounts' => $reportCounts]);
    }

    public function detail(int $id)
    {
        $memory = Memory::withTrashed()->with(['author', 'city', 'place', 'media'])->findOrFail($id);
        $reports = DB::table('reports')->where('target_type', 'memory')->where('target_id', $id)->latest('id')->limit(30)->get();
        $history = DB::table('admin_audit_logs')->leftJoin('admins', 'admins.id', '=', 'admin_audit_logs.admin_id')
            ->where('target_type', 'memory')->where('target_id', $id)
            ->select('admin_audit_logs.*', 'admins.name as admin_name')->latest('admin_audit_logs.id')->limit(20)->get();

        return view('admin.memory_detail', ['title' => 'Anılar', 'section' => 'memories', 'memory' => $memory,
            'reports' => $reports, 'history' => $history, 'state' => self::state($memory)]);
    }

    public function moderate(Request $request, int $id)
    {
        $data = $request->validate(['action' => 'required|in:remove,restore', 'note' => 'nullable|string|max:1000']);
        DB::transaction(function () use ($request, $id, $data): void {
            $memory = Memory::withTrashed()->lockForUpdate()->findOrFail($id);
            if ($data['action'] === 'remove' && ! $memory->trashed()) {
                $memory->forceFill(['moderated_at' => now()])->save();
                $memory->delete();
            } elseif ($data['action'] === 'restore') {
                abort_unless($memory->moderated_at !== null, 409);
                $memory->restore();
                $memory->forceFill(['moderated_at' => null])->save();
            }
            Audit::record($request, 'memory.'.$data['action'], 'memory', $id, ['note' => $data['note'] ?? null]);
        });

        return back()->with('status', 'Moderasyon işlemi kaydedildi.');
    }

    /** A memory photo for review. Viewing it is audited (the owner may have kept it private). */
    public function media(Request $request, int $media)
    {
        $image = MemoryMedia::findOrFail($media);
        $disk = Storage::disk($image->disk);
        abort_unless($disk->exists($image->path), 404);
        Audit::record($request, 'memory.media_viewed', 'memory', $image->memory_id, ['media' => $image->id]);

        return $disk->response($image->path, 'ani.jpg', [
            'Content-Type' => 'image/jpeg', 'X-Content-Type-Options' => 'nosniff', 'Cache-Control' => 'private, no-store',
        ]);
    }
}
