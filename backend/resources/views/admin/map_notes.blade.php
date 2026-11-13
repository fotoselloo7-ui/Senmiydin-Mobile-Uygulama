@extends('admin.layout')
@php
    use App\Http\Controllers\Admin\RecordsController as Records;
    use App\Http\Controllers\Admin\MapNotesController as Notes;
@endphp
@section('content')
<div class="admin-heading"><div><span class="kicker">YÖNETİM</span><h1>{{ $title }}</h1></div><span class="chip">{{ number_format($rows->total(), 0, ',', '.') }} kayıt</span></div>
<form method="get" class="panel filters">
    <label>Ara<input name="q" type="search" value="{{ $filters['q'] ?? '' }}" maxlength="100"></label>
    <label>Durum<select name="status"><option value="">Tümü</option>@foreach(Notes::STATES as $key => $label)<option value="{{ $key }}" @selected(($filters['status'] ?? '') === $key)>{{ $label }}</option>@endforeach</select></label>
    <label>Anonim<select name="anonymous"><option value="">Tümü</option><option value="1" @selected(isset($filters['anonymous']) && $filters['anonymous'] == 1)>Evet</option><option value="0" @selected(isset($filters['anonymous']) && $filters['anonymous'] == 0)>Hayır</option></select></label>
    <label>Raporlanmış<select name="reported"><option value="">Tümü</option><option value="1" @selected(isset($filters['reported']) && $filters['reported'] == 1)>Evet</option><option value="0" @selected(isset($filters['reported']) && $filters['reported'] == 0)>Hayır</option></select></label>
    <button class="button">Filtrele</button><a href="{{ route('admin.map-notes.index') }}">Temizle</a>
</form>
<section class="panel table-panel"><div class="table-wrap"><table>
    <thead><tr><th scope="col">Not</th><th scope="col">Yazar</th><th scope="col">Zaman</th><th scope="col">Durum</th></tr></thead>
    <tbody>
    @forelse($rows as $row)
        <tr>
            <td><a href="{{ route('admin.map-notes.detail', $row->id) }}">#{{ $row->id }} · {{ \Illuminate\Support\Str::limit($row->body, 90) }}</a><small>{{ $row->city?->name }} · {{ $row->reply_count }} yanıt</small></td>
            <td>{{ $row->author?->name }}<small>{{ $row->author ? '@'.$row->author->username : '' }} · {{ $row->is_anonymous ? 'Anonim' : 'İsimli' }}</small></td>
            <td>{{ Records::time($row->created_at) }}<small>Bitiş: {{ Records::time($row->expires_at) }}</small></td>
            <td><span class="chip">{{ Notes::STATES[Notes::state($row)] }}</span>@if(($reportCounts[$row->id] ?? 0) > 0)<small>{{ $reportCounts[$row->id] }} şikâyet</small>@endif</td>
        </tr>
    @empty
        <tr><td colspan="4">Kayıt bulunamadı.</td></tr>
    @endforelse
    </tbody>
</table></div>@include('admin.pagination')</section>
@endsection
