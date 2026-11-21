<?php

namespace App\Http\Controllers\Admin;

use App\Administration\Settings;
use App\Models\City;
use App\Models\EncounterRequest;
use App\Models\Interest;
use App\Models\Message;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\PostMedia;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class RecordsController
{
    public const SECTIONS = [
        'users' => 'Kullanıcılar', 'posts' => 'Paylaşımlar', 'comments' => 'Yorumlar',
        'encounters' => 'Karşılaşmalar', 'map-notes' => 'Harita Notları', 'memories' => 'Anılar', 'featured' => 'Öne çıkanlar', 'reports' => 'Şikâyetler',
        'blocks' => 'Engellemeler', 'interests' => 'Hobiler', 'cities' => 'Şehirler', 'types' => 'İçerik türleri',
        'modules' => 'Ana sayfa modülleri', 'announcements' => 'Duyurular', 'settings' => 'Ayarlar',
        'legal' => 'Web içerikleri', 'requests' => 'Destek talepleri', 'roles' => 'Yöneticiler ve roller',
        'audit' => 'İşlem günlüğü',
    ];

    public const TYPES = ['moment' => 'Anı', 'encounter' => 'Karşılaşma', 'confession' => 'İtiraf', 'thought' => 'Düşünce', 'travel' => 'Yolculuk'];
    public const STATES = ['active' => 'Aktif', 'suspended' => 'Askıda', 'banned' => 'Yasaklı', 'deleted' => 'Silindi'];
    public const REPORT_STATES = ['pending' => 'Bekliyor', 'reviewing' => 'İnceleniyor', 'resolved' => 'Çözüldü', 'rejected' => 'Reddedildi'];
    public const ENCOUNTER_STATES = ['pending' => 'Bekliyor', 'accepted' => 'Onaylandı', 'rejected' => 'Reddedildi', 'cancelled' => 'İptal edildi'];
    public const TARGETS = ['user' => 'Kullanıcı', 'post' => 'Paylaşım', 'comment' => 'Yorum', 'message' => 'Mesaj', 'encounter_story' => 'Ortak hikâye', 'map_note' => 'Harita notu', 'map_note_reply' => 'Harita notu yanıtı', 'memory' => 'Anı', 'system' => 'Uygulama'];
    public const REASONS = ['harassment' => 'Taciz', 'spam' => 'Spam', 'fake' => 'Sahte hesap', 'inappropriate' => 'Uygunsuz içerik', 'hate' => 'Nefret veya tehdit', 'privacy' => 'Gizlilik ihlali', 'other' => 'Diğer'];

    public static function time(\DateTimeInterface|string|null $value, bool $withTime = true): string
    {
        return $value === null ? '—' : \Illuminate\Support\Carbon::parse($value, 'UTC')
            ->setTimezone('Europe/Istanbul')->format($withTime ? 'd.m.Y H:i' : 'd.m.Y');
    }

    public function dashboard()
    {
        $today = now('Europe/Istanbul')->startOfDay()->utc();
        $stats = [
            'Toplam kullanıcı' => User::count(),
            'Aktif hesap' => User::where('account_status', 'active')->count(),
            'Bugün kayıt olan' => User::where('created_at', '>=', $today)->count(),
            'Yayındaki paylaşım' => Post::count(),
            'Bugünkü paylaşım' => Post::where('created_at', '>=', $today)->count(),
            'Toplam yorum' => PostComment::count(),
            'Doğrulanmış karşılaşma' => EncounterRequest::whereHas('encounter')->count(),
            'Bekleyen karşılaşma' => EncounterRequest::where('status', 'pending')->count(),
            'Toplam mesaj' => Message::count(),
            'Aktif sohbet' => DB::table('conversations')->where('status', 'active')->count(),
            'Bekleyen şikâyet' => DB::table('reports')->whereIn('status', ['pending', 'reviewing'])->count(),
            'Aktif harita notu' => \App\Models\MapNote::live()->count(),
            'Anonim paylaşım' => Post::where('is_anonymous', true)->count(),
            'Konum paylaşan hesap' => DB::table('user_locations')->where('visibility', true)
                ->where('recorded_at', '>=', now()->subMinutes(config('location.active_minutes')))->count(),
            'Yakın kişi görünürlüğü açık' => User::where('nearby_visible', true)->count(),
        ];

        return view('admin.dashboard', [
            'title' => 'Genel bakış', 'stats' => $stats,
            'recent' => DB::table('admin_audit_logs')->leftJoin('admins', 'admins.id', '=', 'admin_audit_logs.admin_id')
                ->select('admin_audit_logs.*', 'admins.name')->latest('id')->limit(6)->get(),
        ]);
    }

    public function index(Request $request, string $section, Settings $settings)
    {
        abort_unless(isset(self::SECTIONS[$section]), 404);
        if (in_array($section, ['settings', 'legal', 'announcements', 'audit', 'requests', 'cities', 'interests', 'types', 'featured', 'modules', 'roles'], true)) {
            abort_unless($request->user('admin')->canManageSystem(), 403);
        }
        $filters = $request->validate([
            'q' => 'nullable|string|max:100', 'status' => 'nullable|string|max:20',
            'city' => 'nullable|integer|min:1', 'user' => 'nullable|integer|min:1',
            'type' => 'nullable|string|max:24', 'reason' => 'nullable|string|max:24',
            'from' => 'nullable|date_format:Y-m-d', 'to' => 'nullable|date_format:Y-m-d',
            'nearby' => 'nullable|boolean', 'anonymous' => 'nullable|boolean',
            'reported' => 'nullable|boolean', 'photo' => 'nullable|boolean',
        ]);
        $f = collect($filters)->reject(fn ($value) => $value === null)->all();
        $q = isset($f['q']) ? '%'.str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $f['q']).'%' : null;
        $rows = match ($section) {
            'users' => User::with('city')->when($q, fn ($items) => $items->where(fn ($text) => $text
                ->whereRaw("name LIKE ? ESCAPE '!'", [$q])->orWhereRaw("username LIKE ? ESCAPE '!'", [$q])
                ->orWhereRaw("email LIKE ? ESCAPE '!'", [$q])))
                ->when(isset($f['nearby']), fn ($items) => $items->where('nearby_visible', $f['nearby']))
                ->when(isset($f['status']), fn ($items) => $items->where('account_status', $f['status']))
                ->when(isset($f['anonymous']), fn ($items) => $items->has('posts', $f['anonymous'] ? '>=' : '=', $f['anonymous'] ? 1 : 0,
                    'and', fn ($posts) => $posts->where('is_anonymous', true)))
                ->orderByRaw("CASE WHEN account_status = 'deleted' THEN 1 ELSE 0 END"),
            'posts', 'featured' => Post::withTrashed()->with(['author', 'city'])->withCount('media')
                ->when($q, fn ($items) => $items->whereRaw("body LIKE ? ESCAPE '!'", [$q]))
                ->when(isset($f['anonymous']), fn ($items) => $items->where('is_anonymous', $f['anonymous']))
                ->when(isset($f['photo']), fn ($items) => $f['photo'] ? $items->has('media') : $items->doesntHave('media'))
                ->when(isset($f['reported']), fn ($items) => $this->filterReports($items, ['post', 'encounter_story'], $f['reported']))
                ->when($section === 'featured', fn ($items) => $items->where('story_status', Post::STORY_PUBLISHED)->whereNull('deleted_at')
                    ->where('visibility', 'city')->whereHas('jointEncounter.invitation', fn ($pair) => $pair->activePair()->where('status', 'accepted'))),
            'comments' => PostComment::withTrashed()->with('author')
                ->when($q, fn ($items) => $items->whereRaw("body LIKE ? ESCAPE '!'", [$q]))
                ->when(isset($f['reported']), fn ($items) => $this->filterReports($items, ['comment'], $f['reported'])),
            'encounters' => EncounterRequest::withTrashed()->with(['requester', 'target', 'encounter.story'])
                ->when(isset($f['status']), fn ($items) => $items->where('status', $f['status'])),
            'reports' => DB::table('reports')->when(isset($f['status']), fn ($items) => $items->where('status', $f['status']))
                ->when(isset($f['type']), fn ($items) => $items->where('target_type', $f['type']))
                ->when(isset($f['reason']), fn ($items) => $items->where('reason', $f['reason'])),
            'blocks' => DB::table('user_blocks')
                ->leftJoin('users as blocker', 'blocker.id', '=', 'user_blocks.blocker_id')
                ->leftJoin('users as blocked', 'blocked.id', '=', 'user_blocks.blocked_id')
                ->when($q, fn ($items) => $items->where(fn ($text) => $text
                    ->whereRaw("blocker.name LIKE ? ESCAPE '!'", [$q])
                    ->orWhereRaw("blocker.username LIKE ? ESCAPE '!'", [$q])
                    ->orWhereRaw("blocked.name LIKE ? ESCAPE '!'", [$q])
                    ->orWhereRaw("blocked.username LIKE ? ESCAPE '!'", [$q])))
                ->when(isset($f['user']), fn ($items) => $items->where(fn ($pair) => $pair
                    ->where('user_blocks.blocker_id', $f['user'])->orWhere('user_blocks.blocked_id', $f['user'])))
                ->select(
                    'user_blocks.*',
                    'blocker.name as blocker_name',
                    'blocker.username as blocker_username',
                    'blocked.name as blocked_name',
                    'blocked.username as blocked_username',
                )
                ->orderByDesc('user_blocks.created_at')
                ->orderByDesc('user_blocks.blocker_id'),
            'interests' => Interest::query()->when($q, fn ($items) => $items->whereRaw("name LIKE ? ESCAPE '!'", [$q]))->orderBy('sort_order'),
            'cities' => City::query()->when($q, fn ($items) => $items->whereRaw("name LIKE ? ESCAPE '!'", [$q]))->orderBy('name'),
            'audit' => DB::table('admin_audit_logs')->leftJoin('admins', 'admins.id', '=', 'admin_audit_logs.admin_id')
                ->select('admin_audit_logs.*', 'admins.name')->orderByDesc('admin_audit_logs.id'),
            'announcements' => DB::table('announcements')->orderByDesc('publish_at'),
            'requests' => DB::table('web_requests')->orderByDesc('id'),
            'roles' => \App\Models\Admin::query()->orderBy('role')->orderBy('id'),
            default => null,
        };
        if (in_array($section, ['users', 'posts', 'featured', 'reports'], true)) {
            $rows->when(isset($f['from']), fn ($items) => $items->where('created_at', '>=',
                \Illuminate\Support\Carbon::parse($f['from'], 'Europe/Istanbul')->utc()))
                ->when(isset($f['to']), fn ($items) => $items->where('created_at', '<',
                    \Illuminate\Support\Carbon::parse($f['to'], 'Europe/Istanbul')->addDay()->utc()));
        }
        if (in_array($section, ['users', 'posts', 'featured'], true)) {
            $rows->when(isset($f['city']), fn ($items) => $items->where('city_id', $f['city']));
        }
        if (in_array($section, ['posts', 'featured'], true)) {
            $rows->when(isset($f['user']), fn ($items) => $items->where('user_id', $f['user']))
                ->when(isset($f['type']), fn ($items) => $items->where('type', $f['type']));
        }
        if ($section === 'featured') {
            $rows->orderByRaw('CASE WHEN featured_rank IS NULL THEN 1 ELSE 0 END')->orderBy('featured_rank');
        }
        if ($rows && ! in_array($section, ['audit', 'blocks', 'roles'], true)) {
            $rows->orderByDesc('id');
        }
        return view('admin.records', [
            'title' => self::SECTIONS[$section], 'section' => $section, 'filters' => $f,
            'rows' => $rows?->paginate(25)->withQueryString(), 'settings' => $settings->all(),
            'cities' => in_array($section, ['users', 'posts', 'featured', 'announcements'], true) ? City::orderBy('name')->get(['id', 'name']) : collect(),
            'legal' => $section === 'legal' ? app(\App\Website\Pages::class)->legal() : [],
        ]);
    }

    public function detail(Request $request, string $section, int $id)
    {
        $extra = [];
        $record = match ($section) {
            'users' => User::with(['city', 'interests'])->withCount(['posts', 'followers', 'following'])->findOrFail($id),
            'posts' => Post::withTrashed()->with(['author', 'city', 'media', 'travel.origin', 'travel.destination'])->withCount(['likes', 'comments'])->findOrFail($id),
            'comments' => PostComment::withTrashed()->with('author')->findOrFail($id),
            'encounters' => EncounterRequest::withTrashed()->with(['requester', 'target', 'encounter', 'encounter.story' => fn ($story) => $story->withTrashed()->with('media')])->findOrFail($id),
            'reports' => DB::table('reports')->find($id) ?? abort(404),
            default => abort(404),
        };
        if ($section === 'users') {
            $extra['encounters'] = EncounterRequest::participant($id)->whereHas('encounter')->count();
            $extra['reports'] = DB::table('reports')->where('target_type', 'user')->where('target_id', $id)->count();
            $extra['blocks_given'] = DB::table('user_blocks')->where('blocker_id', $id)->count();
            $extra['blocks_received'] = DB::table('user_blocks')->where('blocked_id', $id)->count();
            $extra['recent_reports'] = DB::table('reports')->where('target_type', 'user')->where('target_id', $id)
                ->latest('id')->limit(10)->get();
            $extra['moderation_history'] = DB::table('admin_audit_logs')
                ->leftJoin('admins', 'admins.id', '=', 'admin_audit_logs.admin_id')
                ->where('target_type', 'user')->where('target_id', $id)
                ->select('admin_audit_logs.*', 'admins.name as admin_name')
                ->latest('admin_audit_logs.id')->limit(15)->get();
        } elseif ($section === 'posts' || $section === 'comments') {
            $extra['reports'] = DB::table('reports')->whereIn('target_type', $section === 'posts' ? ['post', 'encounter_story'] : ['comment'])
                ->where('target_id', $id)->count();
        } elseif ($section === 'encounters') {
            $extra['source'] = Post::withTrashed()->find($record->source_post_id);
            $extra['reports'] = DB::table('reports')->where(fn ($items) => $items
                ->where('target_type', 'post')->where('target_id', $record->source_post_id))
                ->orWhere(fn ($items) => $items->where('target_type', 'encounter_story')->where('target_id', $record->encounter?->story?->id))
                ->latest('id')->limit(20)->get();
        } elseif ($section === 'reports') {
            $extra['reporter'] = User::find($record->reporter_id);
            $extra['target'] = $this->reportedTarget($record);
            if ($extra['target'] instanceof Message) {
                \App\Administration\Audit::record($request, 'report.message_viewed', 'report', $id);
            }
            $owner = $extra['target'] instanceof User ? $extra['target']->id : ($extra['target']->user_id ?? $extra['target']->sender_id ?? null);
            $extra['owner'] = $owner ? User::find($owner) : null;
            $extra['history'] = $owner ? DB::table('reports')->where('target_type', 'user')->where('target_id', $owner)
                ->where('id', '<>', $id)->latest('id')->limit(10)->get() : collect();
        }
        $targetType = ['users'=>'user', 'posts'=>'post', 'comments'=>'comment', 'encounters'=>'encounter', 'reports'=>'report'][$section];
        $extra['notes'] = DB::table('admin_audit_logs')->where('target_type', $targetType)->where('target_id', $id)
            ->whereNotNull('metadata')->latest('id')->limit(15)->pluck('metadata')
            ->map(fn ($metadata) => json_decode($metadata, true)['note'] ?? null)->filter();
        return view('admin.detail', ['title' => self::SECTIONS[$section], 'section' => $section, 'record' => $record] + $extra);
    }

    public function media(int $media)
    {
        $image = PostMedia::findOrFail($media);
        return $this->image($image->disk, $image->file_path);
    }

    public function reportImage(Request $request, int $report)
    {
        $row = DB::table('reports')->where('target_type', 'message')->find($report) ?? abort(404);
        $message = Message::whereNotNull('image_path')->findOrFail($row->target_id);
        \App\Administration\Audit::record($request, 'report.media_viewed', 'report', $report);
        return $this->image(config('mobile.post_media_disk'), $message->image_path);
    }

    public function reportedTarget(object $report): User|Post|PostComment|Message|\App\Models\MapNote|\App\Models\MapNoteReply|\App\Models\Memory|null
    {
        return match ($report->target_type) {
            'user' => User::find($report->target_id),
            'post', 'encounter_story' => Post::withTrashed()->find($report->target_id),
            'comment' => PostComment::withTrashed()->find($report->target_id),
            'message' => Message::find($report->target_id),
            'map_note' => \App\Models\MapNote::withTrashed()->find($report->target_id),
            'map_note_reply' => \App\Models\MapNoteReply::withTrashed()->find($report->target_id),
            'memory' => \App\Models\Memory::withTrashed()->find($report->target_id),
            default => null,
        };
    }

    private function image(string $disk, string $path)
    {
        $storage = Storage::disk($disk);
        abort_unless($storage->exists($path), 404);
        return $storage->response($path, 'gorsel.jpg', [
            'Content-Type' => 'image/jpeg', 'X-Content-Type-Options' => 'nosniff', 'Cache-Control' => 'private, no-store',
        ]);
    }

    private function filterReports(Builder $items, array $types, bool $reported): Builder
    {
        $ids = DB::table('reports')->whereIn('target_type', $types)->select('target_id');
        return $reported ? $items->whereIn('id', $ids) : $items->whereNotIn('id', $ids);
    }
}
