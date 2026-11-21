@extends('admin.layout')
@php
    use App\Http\Controllers\Admin\RecordsController as Records;
    use App\Http\Controllers\Admin\MemoriesController as Memories;
@endphp
@section('content')
<div class="admin-heading"><div><a href="{{ route('admin.memories.index') }}">← {{ $title }}</a><h1>Anı</h1></div><span class="chip">#{{ $memory->id }}</span></div>
<div class="detail-grid"><section class="panel">
    <h2>Ayrıntılar</h2>
    <dl class="facts">
        <dt>Sahibi (yönetici görünümü)</dt><dd><a href="{{ route('admin.detail', ['users', $memory->user_id]) }}">{{ $memory->author?->name }} · {{ '@'.$memory->author?->username }}</a></dd>
        <dt>Görünürlük</dt><dd>{{ Memories::VISIBILITIES[$memory->visibility] ?? $memory->visibility }}{{ $memory->is_hidden ? ' · sahibi gizledi' : '' }}</dd>
        <dt>Durum</dt><dd>{{ Memories::STATES[$state] }}</dd>
        <dt>Olay tarihi</dt><dd>{{ Records::time($memory->occurred_at, false) }}</dd>
        <dt>Yaklaşık yer</dt><dd>{{ $memory->place_label ?? $memory->city?->name ?? '—' }} (kesin koordinat saklanmaz)</dd>
        <dt>Kaynak</dt><dd>{{ ['map_note' => 'Harita notundan', 'post' => 'Gönderiden'][$memory->source_type] ?? 'Doğrudan eklendi' }}</dd>
        <dt>Oluşturma</dt><dd>{{ Records::time($memory->created_at) }}</dd>
    </dl>
    <h3>Metin</h3><blockquote class="preserve">{{ $memory->body }}</blockquote>
    @if($memory->media->isNotEmpty())
        <h3>Fotoğraflar ({{ $memory->media->count() }})</h3>
        <div class="media-grid">
            @foreach($memory->media as $media)
                <a href="{{ route('admin.memories.media', $media->id) }}"><img src="{{ route('admin.memories.media', $media->id) }}" alt="Anı fotoğrafı {{ $loop->iteration }}" loading="lazy"></a>
            @endforeach
        </div>
    @endif
    @if($reports->isNotEmpty())<h3>İlgili şikâyetler</h3><ul>@foreach($reports as $entry)<li><a href="{{ route('admin.detail', ['reports',$entry->id]) }}">Şikâyet #{{ $entry->id }}</a> · {{ Records::REASONS[$entry->reason] ?? $entry->reason }} · {{ Records::REPORT_STATES[$entry->status] ?? $entry->status }}</li>@endforeach</ul>@endif
    @if($history->isNotEmpty())<h3>Moderasyon geçmişi</h3><ul>@foreach($history as $entry)<li><strong>{{ \App\Administration\Audit::label($entry->action) }}</strong> · {{ $entry->admin_name ?? 'Sistem' }} · {{ Records::time($entry->created_at) }}</li>@endforeach</ul>@endif
</section>
<aside class="panel"><h2>İşlemler</h2>
    <form method="post" action="{{ route('admin.memories.moderate', $memory->id) }}" class="fields">@csrf
        <label>İşlem<select name="action">
            @if(! $memory->trashed())<option value="remove">Anıyı herkesten kaldır</option>@elseif($memory->moderated_at)<option value="restore">Geri aç</option>@endif
        </select></label>
        <label>Moderasyon notu<textarea name="note" maxlength="1000" rows="4"></textarea></label><button class="button">Uygula</button>
    </form>
</aside></div>
@endsection
