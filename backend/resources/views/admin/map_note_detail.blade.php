@extends('admin.layout')
@php
    use App\Http\Controllers\Admin\RecordsController as Records;
    use App\Http\Controllers\Admin\MapNotesController as Notes;
@endphp
@section('content')
<div class="admin-heading"><div><a href="{{ route('admin.map-notes.index') }}">← {{ $title }}</a><h1>Harita notu</h1></div><span class="chip">#{{ $note->id }}</span></div>
<div class="detail-grid"><section class="panel">
    <h2>Ayrıntılar</h2>
    <dl class="facts">
        <dt>Yazar (yönetici görünümü)</dt><dd><a href="{{ route('admin.detail', ['users', $note->user_id]) }}">{{ $note->author?->name }} · {{ '@'.$note->author?->username }}</a>{{ $note->is_anonymous ? ' · Kullanıcılara ANONİM görünür' : '' }}</dd>
        <dt>Şehir</dt><dd>{{ $note->city?->name }} · {{ $note->place_label }}</dd>
        <dt>Durum</dt><dd>{{ Notes::STATES[$state] }}</dd>
        <dt>Oluşturma</dt><dd>{{ Records::time($note->created_at) }}</dd>
        <dt>Yayından kalkış</dt><dd>{{ Records::time($note->expires_at) }}</dd>
        <dt>Konum</dt><dd>Yaklaşık bölge (kesin koordinat saklanmaz)</dd>
    </dl>
    <h3>Not</h3><blockquote class="preserve">{{ $note->body }}</blockquote>
    <h3>Yanıtlar ({{ $replies->count() }})</h3>
    @forelse($replies as $reply)
        <article class="panel">
            <p class="preserve">{{ $reply->body }}</p>
            <small>{{ Records::time($reply->created_at) }} · <a href="{{ route('admin.detail', ['users', $reply->user_id]) }}">{{ $reply->author?->name }} · {{ '@'.$reply->author?->username }}</a> · {{ $reply->is_anonymous ? 'Anonim' : 'İsimli' }} · {{ $reply->trashed() ? 'Kaldırıldı' : 'Aktif' }}</small>
            <form method="post" action="{{ route('admin.map-note-replies.moderate', $reply->id) }}" class="inline-form">@csrf
                @if(! $reply->trashed())<input type="hidden" name="action" value="remove"><button class="button outline">Yanıtı kaldır</button>
                @elseif($reply->moderated_at)<input type="hidden" name="action" value="restore"><button class="button outline">Geri aç</button>@endif
            </form>
        </article>
    @empty
        <p>Yanıt yok.</p>
    @endforelse
    @if($reports->isNotEmpty())<h3>İlgili şikâyetler</h3><ul>@foreach($reports as $entry)<li><a href="{{ route('admin.detail', ['reports',$entry->id]) }}">Şikâyet #{{ $entry->id }}</a> · {{ Records::TARGETS[$entry->target_type] ?? $entry->target_type }} · {{ Records::REPORT_STATES[$entry->status] ?? $entry->status }}</li>@endforeach</ul>@endif
    @if($history->isNotEmpty())<h3>Moderasyon geçmişi</h3><ul>@foreach($history as $entry)<li><strong>{{ \App\Administration\Audit::label($entry->action) }}</strong> · {{ $entry->admin_name ?? 'Sistem' }} · {{ Records::time($entry->created_at) }}</li>@endforeach</ul>@endif
</section>
<aside class="panel"><h2>İşlemler</h2>
    <form method="post" action="{{ route('admin.map-notes.moderate', $note->id) }}" class="fields">@csrf
        <label>İşlem<select name="action">
            @if(! $note->trashed())<option value="remove">Notu haritadan kaldır</option>@elseif($note->moderated_at)<option value="restore">Geri aç</option>@endif
        </select></label>
        <label>Moderasyon notu<textarea name="note" maxlength="1000" rows="4"></textarea></label><button class="button">Uygula</button>
    </form>
</aside></div>
@endsection
