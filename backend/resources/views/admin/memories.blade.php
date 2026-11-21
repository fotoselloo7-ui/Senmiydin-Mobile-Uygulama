@extends('admin.layout')
@php
    use App\Http\Controllers\Admin\RecordsController as Records;
    use App\Http\Controllers\Admin\MemoriesController as Memories;
@endphp
@section('content')
<div class="admin-heading"><div><span class="kicker">YÖNETİM</span><h1>{{ $title }}</h1></div><span class="chip">{{ number_format($rows->total(), 0, ',', '.') }} kayıt</span></div>
<form method="get" class="panel filters">
    <label>Ara<input name="q" type="search" value="{{ $filters['q'] ?? '' }}" maxlength="100"></label>
    <label>Durum<select name="status"><option value="">Tümü</option>@foreach(Memories::STATES as $key => $label)<option value="{{ $key }}" @selected(($filters['status'] ?? '') === $key)>{{ $label }}</option>@endforeach</select></label>
    <label>Görünürlük<select name="visibility"><option value="">Tümü</option>@foreach(Memories::VISIBILITIES as $key => $label)<option value="{{ $key }}" @selected(($filters['visibility'] ?? '') === $key)>{{ $label }}</option>@endforeach</select></label>
    <label>Raporlanmış<select name="reported"><option value="">Tümü</option><option value="1" @selected(isset($filters['reported']) && $filters['reported'] == 1)>Evet</option><option value="0" @selected(isset($filters['reported']) && $filters['reported'] == 0)>Hayır</option></select></label>
    <button class="button">Filtrele</button><a href="{{ route('admin.memories.index') }}">Temizle</a>
</form>
<section class="panel table-panel"><div class="table-wrap"><table>
    <thead><tr><th scope="col">Anı</th><th scope="col">Sahibi</th><th scope="col">Olay tarihi</th><th scope="col">Durum</th></tr></thead>
    <tbody>
    @forelse($rows as $row)
        <tr>
            <td><a href="{{ route('admin.memories.detail', $row->id) }}">#{{ $row->id }} · {{ \Illuminate\Support\Str::limit($row->body, 90) ?: 'Fotoğraflı anı' }}</a><small>{{ $row->place_label ?? $row->city?->name }} · {{ $row->media_count }} fotoğraf</small></td>
            <td>{{ $row->author?->name }}<small>{{ $row->author ? '@'.$row->author->username : '' }} · {{ Memories::VISIBILITIES[$row->visibility] ?? $row->visibility }}</small></td>
            <td>{{ Records::time($row->occurred_at, false) }}<small>Oluşturma: {{ Records::time($row->created_at) }}</small></td>
            <td><span class="chip">{{ Memories::STATES[Memories::state($row)] }}</span>@if(($reportCounts[$row->id] ?? 0) > 0)<small>{{ $reportCounts[$row->id] }} şikâyet</small>@endif</td>
        </tr>
    @empty
        <tr><td colspan="4">Kayıt bulunamadı.</td></tr>
    @endforelse
    </tbody>
</table></div>@include('admin.pagination')</section>
@endsection
