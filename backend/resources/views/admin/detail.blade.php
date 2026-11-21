@extends('admin.layout')
@php
    use App\Http\Controllers\Admin\RecordsController as Records;
@endphp
@section('content')
<div class="admin-heading"><div><a href="{{ route('admin.index', $section) }}">← {{ $title }}</a><h1>
    {{ match($section) { 'users' => $record->name, 'posts' => $record->story_title ?: 'Paylaşım', 'comments' => 'Yorum', 'encounters' => 'Karşılaşma', 'reports' => 'Şikâyet' } }}
</h1></div><span class="chip">#{{ $record->id }}</span></div>

<div class="detail-grid"><section class="panel">
    <h2>Ayrıntılar</h2>
    @switch($section)
        @case('users')
            @if($record->avatar)<img class="avatar" src="{{ route('avatars.show', basename($record->avatar)) }}" alt="" width="64" height="64">@endif
            <dl class="facts">
                <dt>Kullanıcı adı</dt><dd>{{ '@'.$record->username }}</dd><dt>E-posta</dt><dd>{{ $record->email }}</dd>
                <dt>Şehir</dt><dd>{{ $record->city?->name ?? '—' }}</dd><dt>Durum</dt><dd>{{ Records::STATES[$record->account_status] ?? $record->account_status }}</dd>
                <dt>Kayıt</dt><dd>{{ Records::time($record->created_at) }}</dd>
                <dt>Son görülme</dt><dd>{{ Records::time($record->last_seen_at) }}</dd>
                <dt>Hobiler</dt><dd>{{ $record->interests->pluck('name')->join(', ') ?: '—' }}</dd>
                <dt>Paylaşım · takipçi · takip</dt><dd><a href="{{ route('admin.index', ['posts', 'user' => $record->id]) }}">{{ $record->posts_count }} paylaşım</a> · {{ $record->followers_count }} · {{ $record->following_count }}</dd>
                <dt>Karşılaşma · şikâyet</dt><dd>{{ $encounters }} · {{ $reports }}</dd>
                <dt>Engelleme (yaptığı · aldığı)</dt><dd><a href="{{ route('admin.index', ['blocks', 'user' => $record->id]) }}">{{ $blocks_given ?? 0 }} · {{ $blocks_received ?? 0 }}</a></dd>
            </dl><p class="preserve">{{ $record->bio ?: 'Biyografi yok.' }}</p>
            @if(!empty($recent_reports) && $recent_reports->isNotEmpty())
                <h3>Rapor geçmişi</h3>
                <ul>
                    @foreach($recent_reports as $entry)
                        <li><a href="{{ route('admin.detail', ['reports', $entry->id]) }}">Şikâyet #{{ $entry->id }}</a> · {{ Records::REASONS[$entry->reason] ?? $entry->reason }} · {{ Records::REPORT_STATES[$entry->status] ?? $entry->status }} ({{ Records::time($entry->created_at) }})</li>
                    @endforeach
                </ul>
            @endif
            @if(!empty($moderation_history) && $moderation_history->isNotEmpty())
                <h3>Moderasyon geçmişi</h3>
                <ul>
                    @foreach($moderation_history as $entry)
                        <li><strong>{{ \App\Administration\Audit::label($entry->action) }}</strong> · {{ $entry->admin_name ?? 'Sistem' }} · {{ Records::time($entry->created_at) }}</li>
                    @endforeach
                </ul>
            @endif
            @break
        @case('posts')
            <dl class="facts"><dt>Yazar</dt><dd><a href="{{ route('admin.detail', ['users',$record->user_id]) }}">{{ $record->author?->name }}</a>{{ $record->is_anonymous ? ' · Anonim paylaşım' : '' }}</dd>
                <dt>Şehir</dt><dd>{{ $record->city?->name }}</dd><dt>Tür</dt><dd>{{ Records::TYPES[$record->type] ?? $record->type }}</dd>
                <dt>Durum</dt><dd>{{ $record->trashed() ? 'Kaldırıldı' : 'Yayında' }}</dd>
                <dt>Beğeni · yorum · şikâyet</dt><dd>{{ $record->likes_count }} · {{ $record->comments_count }} · {{ $reports }}</dd>
                <dt>Konum</dt><dd>{{ $record->approx_latitude !== null ? 'Yaklaşık konum eklendi' : 'Konum eklenmedi' }}</dd>
            </dl>
            @if($record->occurred_at)<p>Olay zamanı: {{ Records::time($record->occurred_at) }}</p>@endif
            @if($travel = $record->travel)
                <h3>Yolculuk detayları</h3>
                <p>{{ ['bus'=>'Otobüs','train'=>'Tren','plane'=>'Uçak','ferry'=>'Feribot','other'=>'Diğer'][$travel->transport_type] ?? 'Yolculuk' }} · {{ $travel->operator_name }}</p>
                <p>{{ $travel->origin?->name }} → {{ $travel->destination?->name }} · {{ Records::time($travel->departure_at) }}</p>
                <p>{{ $travel->service_code }} · {{ $travel->vehicle_identifier }} · {{ $travel->is_public ? 'Gönderide görünür' : 'Yalnızca sahibi ve yetkili yönetim' }}</p>
            @endif
            <p class="preserve">{{ $record->body }}</p>
            @include('admin.media', ['post' => $record])
            @break
        @case('comments')
            <dl class="facts"><dt>Yazar</dt><dd>{{ $record->author?->name }}</dd><dt>Paylaşım</dt><dd><a href="{{ route('admin.detail', ['posts',$record->post_id]) }}">#{{ $record->post_id }}</a></dd><dt>Şikâyet</dt><dd>{{ $reports }}</dd></dl>
            <p class="preserve">{{ $record->body }}</p>
            @break
        @case('encounters')
            <dl class="facts">
                <dt>Gönderen</dt><dd><a href="{{ route('admin.detail', ['users',$record->requester_id]) }}">{{ $record->requester?->name }}</a></dd>
                <dt>Alıcı</dt><dd><a href="{{ route('admin.detail', ['users',$record->target_user_id]) }}">{{ $record->target?->name }}</a></dd>
                <dt>Durum</dt><dd>{{ Records::ENCOUNTER_STATES[$record->status] ?? $record->status }}{{ $record->trashed() ? ' · Kaldırıldı' : '' }}</dd>
                <dt>Oluşturuldu</dt><dd>{{ Records::time($record->created_at) }}</dd>
                <dt>Yanıtlandı</dt><dd>{{ Records::time($record->responded_at) }}</dd>
                <dt>Kaynak paylaşım</dt><dd>@if($source)<a href="{{ route('admin.detail', ['posts',$source->id]) }}">{{ \Illuminate\Support\Str::limit($source->body, 100) ?: '#'.$source->id }}</a>@else — @endif</dd>
                <dt>Ortak hikâye</dt><dd>{{ ['pending'=>'Yayın onayı bekliyor','published'=>'İki taraf onayladı','rejected'=>'Yayın reddedildi'][$record->encounter?->story?->story_status] ?? '—' }}</dd>
            </dl>
            @if($story = $record->encounter?->story)
                <h3><a href="{{ route('admin.detail', ['posts',$story->id]) }}">{{ $story->story_title }}</a></h3>
                <p class="preserve">{{ $story->body }}</p>@include('admin.media', ['post' => $story])
            @endif
            @if($reports->isNotEmpty())<h3>İlgili şikâyetler</h3><ul>@foreach($reports as $entry)<li><a href="{{ route('admin.detail', ['reports',$entry->id]) }}">Şikâyet #{{ $entry->id }}</a></li>@endforeach</ul>@endif
            @break
        @case('reports')
            <dl class="facts"><dt>Şikâyet eden</dt><dd>@if($reporter)<a href="{{ route('admin.detail', ['users',$reporter->id]) }}">{{ $reporter->name }}</a>@else — @endif</dd>
                <dt>Hedef</dt><dd>{{ Records::TARGETS[$record->target_type] ?? $record->target_type }} #{{ $record->target_id }}</dd>
                <dt>Neden</dt><dd>{{ Records::REASONS[$record->reason] ?? $record->reason }}</dd>
                <dt>Durum</dt><dd>{{ Records::REPORT_STATES[$record->status] ?? $record->status }}</dd>
                <dt>İçerik sahibi</dt><dd>@if($owner)<a href="{{ route('admin.detail', ['users',$owner->id]) }}">{{ $owner->name }}</a>@else — @endif</dd></dl>
            <p class="preserve">{{ $record->description }}</p>
            @if($target && in_array($record->target_type, ['post','encounter_story','comment','message','map_note','map_note_reply','memory'], true))
                <h3>Şikâyet edilen içerik</h3><blockquote class="preserve">{{ $target->body }}</blockquote>
                @if($record->target_type === 'message' && $target->image_path)
                    <img class="report-image" src="{{ route('admin.report.image', $record->id) }}" alt="Şikâyet edilen mesaj görseli" loading="lazy">
                @elseif($target instanceof \App\Models\Post)
                    <a href="{{ route('admin.detail', ['posts',$target->id]) }}">Paylaşımı incele →</a>
                @elseif($target instanceof \App\Models\PostComment)
                    <a href="{{ route('admin.detail', ['comments',$target->id]) }}">Yorumu incele →</a>
                @elseif($target instanceof \App\Models\MapNote)
                    <a href="{{ route('admin.map-notes.detail', $target->id) }}">Notu incele →</a>
                @elseif($target instanceof \App\Models\Memory)
                    <a href="{{ route('admin.memories.detail', $target->id) }}">Anıyı incele →</a>
                @elseif($target instanceof \App\Models\MapNoteReply)
                    <a href="{{ route('admin.map-notes.detail', $target->map_note_id) }}">Notun yanıt zincirini incele →</a>
                @endif
            @endif
            @if($history->isNotEmpty())<h3>Önceki kullanıcı şikâyetleri</h3><ul>@foreach($history as $entry)<li><a href="{{ route('admin.detail', ['reports',$entry->id]) }}">Şikâyet #{{ $entry->id }}</a> · {{ Records::REPORT_STATES[$entry->status] ?? $entry->status }}</li>@endforeach</ul>@endif
            @break
    @endswitch
</section>
<aside class="panel"><h2>İşlemler</h2>
@if($section === 'users' && $record->account_status === 'deleted')
    <p>Bu hesap silinmiş ve anonimleştirilmiştir. Yeniden etkinleştirilemez.</p>
@elseif($section === 'users')
    <form method="post" action="{{ route('admin.user.action', $record->id) }}" class="fields">@csrf
        <label>İşlem<select name="action"><option value="suspend">Askıya al</option><option value="ban">Yasakla</option><option value="restore">Hesabı etkinleştir</option><option value="revoke">Oturumları kapat</option></select></label>
        <label>Not<textarea name="note" maxlength="1000" rows="4"></textarea></label><button class="button">Uygula</button>
    </form>
@elseif($section === 'reports')
    <form method="post" action="{{ route('admin.report.action', $record->id) }}" class="fields">@csrf
        <label>Durum<select name="status">@foreach(Records::REPORT_STATES as $key => $label)<option value="{{ $key }}" @selected($key === $record->status)>{{ $label }}</option>@endforeach</select></label>
        @if($target)<label>Ek işlem<select name="action"><option value="">Yalnızca durumu güncelle</option>
            @unless($target instanceof \App\Models\User)<option value="remove">İçeriği kaldır</option>@endunless
            @if($owner)<option value="suspend">Hesabı askıya al</option><option value="ban">Hesabı yasakla</option>@endif
        </select></label>@endif
        <label>Moderasyon notu<textarea name="note" maxlength="1000" rows="4"></textarea></label><button class="button">Kaydet</button>
    </form>
@else
    <form method="post" action="{{ route('admin.content.action', [$section,$record->id]) }}" class="fields">@csrf
        <label>İşlem<select name="action"><option value="note">Not ekle</option>
            @if(!$record->trashed())<option value="remove">İçeriği kaldır</option>
            @elseif($section === 'encounters' || $record->moderated_at)<option value="restore">Geri aç</option>@endif
        </select></label>
        <label>Moderasyon notu<textarea name="note" maxlength="1000" rows="4"></textarea></label><button class="button">Uygula</button>
    </form>
@endif
@if(!empty($notes))
    <h3 class="spaced">Son moderasyon notları</h3>
    @foreach($notes as $note)<p class="preserve">{{ $note }}</p>@endforeach
@endif
</aside></div>
@endsection
