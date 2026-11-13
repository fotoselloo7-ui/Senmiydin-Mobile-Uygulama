@extends('admin.layout')
@section('content')
<div class="admin-heading"><div><span class="kicker">YÖNETİM</span><h1>Genel bakış</h1><p>Topluluk ve moderasyon göstergeleri.</p></div><span class="chip">{{ now('Europe/Istanbul')->format('d.m.Y') }}</span></div>
<div class="metrics">
    @foreach($stats as $label => $value)<article class="panel metric"><span>{{ $label }}</span><strong>{{ number_format($value, 0, ',', '.') }}</strong></article>@endforeach
</div>
@if(auth('admin')->user()->canManageSystem())
<section class="panel"><div class="split"><h2>Son yönetim işlemleri</h2><a href="{{ route('admin.index', 'audit') }}">İşlem günlüğü →</a></div>
    <div class="table-wrap"><table><thead><tr><th>İşlem</th><th>Yönetici</th><th>Zaman</th></tr></thead><tbody>
    @forelse($recent as $row)<tr><td>{{ \App\Administration\Audit::label($row->action) }}</td><td>{{ $row->name ?? '—' }}</td><td>{{ \App\Http\Controllers\Admin\RecordsController::time($row->created_at) }}</td></tr>
    @empty<tr><td colspan="3">Henüz yönetim işlemi yok.</td></tr>@endforelse
    </tbody></table></div>
</section>
@endif
@endsection
