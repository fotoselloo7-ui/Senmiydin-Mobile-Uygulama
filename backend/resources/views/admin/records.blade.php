@extends('admin.layout')
@php
    use App\Http\Controllers\Admin\RecordsController as Records;
    $searchable = in_array($section, ['users','posts','featured','comments','cities','interests','blocks'], true);
    $dated = in_array($section, ['users','posts','featured','reports'], true);
    $statuses = match($section) { 'users' => Records::STATES, 'reports' => Records::REPORT_STATES, 'encounters' => Records::ENCOUNTER_STATES, default => [] };
@endphp
@section('content')
<div class="admin-heading"><div><span class="kicker">YÖNETİM</span><h1>{{ $title }}</h1></div>@if($rows)<span class="chip">{{ number_format($rows->total(), 0, ',', '.') }} kayıt</span>@endif</div>
@if($searchable || $dated || $statuses)
<form method="get" class="panel filters">
    @if($searchable)<label>Ara<input name="q" type="search" value="{{ $filters['q'] ?? '' }}" maxlength="100"></label>@endif
    @if($statuses)<label>Durum<select name="status"><option value="">Tümü</option>@foreach($statuses as $key => $label)<option value="{{ $key }}" @selected(($filters['status'] ?? '') === $key)>{{ $label }}</option>@endforeach</select></label>@endif
    @if(in_array($section, ['users','posts','featured'], true))
        <label>Şehir<select name="city"><option value="">Tümü</option>@foreach($cities as $city)<option value="{{ $city->id }}" @selected(($filters['city'] ?? 0) == $city->id)>{{ $city->name }}</option>@endforeach</select></label>
    @endif
    @if(in_array($section, ['posts','featured'], true))<label>Yazar kimliği<input name="user" type="number" min="1" value="{{ $filters['user'] ?? '' }}"></label>@endif
    @if(in_array($section, ['posts','reports','featured'], true))
        <label>Tür<select name="type"><option value="">Tümü</option>@foreach($section === 'reports' ? Records::TARGETS : Records::TYPES as $key => $label)<option value="{{ $key }}" @selected(($filters['type'] ?? '') === $key)>{{ $label }}</option>@endforeach</select></label>
    @endif
    @if($section === 'reports')
        <label>Neden<select name="reason"><option value="">Tümü</option>@foreach(Records::REASONS as $key => $label)<option value="{{ $key }}" @selected(($filters['reason'] ?? '') === $key)>{{ $label }}</option>@endforeach</select></label>
    @endif
    @php($flags = match($section) {
        'users'=>['nearby'=>'Yakın kişi görünürlüğü','anonymous'=>'Anonim paylaşım yapan'],
        'posts','featured'=>['anonymous'=>'Anonim','photo'=>'Fotoğraflı','reported'=>'Raporlanmış'],
        'comments'=>['reported'=>'Raporlanmış'], default=>[]
    })
    @foreach($flags as $key => $label)
        <label>{{ $label }}<select name="{{ $key }}"><option value="">Tümü</option><option value="1" @selected(isset($filters[$key]) && $filters[$key] == 1)>Evet</option><option value="0" @selected(isset($filters[$key]) && $filters[$key] == 0)>Hayır</option></select></label>
    @endforeach
    @if($dated)<label>Başlangıç<input type="date" name="from" value="{{ $filters['from'] ?? '' }}"></label><label>Bitiş<input type="date" name="to" value="{{ $filters['to'] ?? '' }}"></label>@endif
    <button class="button">Filtrele</button><a href="{{ route('admin.index', $section) }}">Temizle</a>
</form>
@endif

@if($section === 'settings')
    <form class="panel fields" method="post" action="{{ route('admin.settings.update') }}">
        @csrf
        <div class="field-grid">@foreach(\App\Administration\Settings::LABELS as $key => $label)
            @if(in_array($key, \App\Administration\Settings::SWITCHES, true))
                <label class="toggle"><input type="hidden" name="{{ $key }}" value="0"><input type="checkbox" name="{{ $key }}" value="1" @checked(old($key, $settings[$key]))>{{ $label }}</label>
            @elseif(in_array($key, ['moderation_banned_words','moderation_blocked_domains'], true))
                <label>{{ $label }}<textarea name="{{ $key }}" rows="4" maxlength="4000">{{ old($key, $settings[$key]) }}</textarea></label>
            @else
                <label>{{ $label }}<input name="{{ $key }}" value="{{ old($key, $settings[$key]) }}" @if(in_array($key, ['minimum_age','feed_ad_interval','max_post_photos','location_history_days','moderation_max_mentions','moderation_max_links','moderation_post_repeats','moderation_comment_repeats','moderation_repeat_seconds'], true)) type="number" min="1" @endif></label>
            @endif
        @endforeach</div>
        <button class="button">Ayarları kaydet</button>
    </form>
@elseif($section === 'legal')
    @foreach($legal as $slug => $entry)
        <form class="panel fields" method="post" action="{{ route('admin.legal.update', $slug) }}">
            @csrf<h2>{{ $entry['title'] }}</h2><p>Biçimlendirme için paragraflar arasında boş satır bırak.</p>
            <label>Başlık<input name="title" required maxlength="120" value="{{ $entry['title'] }}"></label>
            <label>İçerik<textarea name="body" rows="8" required maxlength="20000">{{ $entry['body'] }}</textarea></label>
            <button class="button">Yayınla</button>
        </form>
    @endforeach
@elseif($section === 'types')
    <section class="panel"><h2>Mobil paylaşım türleri</h2><ul>@foreach(Records::TYPES as $type)<li>{{ $type }}</li>@endforeach</ul></section>
@elseif($section === 'modules')
    <form class="panel fields" method="post" action="{{ route('admin.settings.update') }}">
        @csrf
        <h2>Mobil ana sayfa ve keşif modülleri</h2>
        <p>Ana sayfa modül sırası sabittir: Üst Başlık → Akış / Yakın / Popüler / Şehir → Yakınında Yeni Paylaşımlar / Duyuru → Yakınındaki İnsanlar → Öne Çıkan Karşılaşmalar → Hızlı Paylaşım → Normal Akış → Alt Navigasyon. Buradan modül görünürlüklerini yönetebilirsin.</p>
        <div class="field-grid">
            @foreach(['announcements_enabled', 'nearby_enabled', 'nearby_notes_enabled', 'featured_enabled', 'encounters_enabled'] as $key)
                <label class="toggle"><input type="hidden" name="{{ $key }}" value="0"><input type="checkbox" name="{{ $key }}" value="1" @checked(old($key, $settings[$key]))>{{ \App\Administration\Settings::LABELS[$key] }}</label>
            @endforeach
        </div>
        <button class="button">Modül ayarlarını kaydet</button>
    </form>
    <section class="panel">
        <h2>İlgili modül yönetimleri</h2>
        <p><a href="{{ route('admin.index', 'featured') }}">Öne çıkan karşılaşma sıralamasını düzenle →</a> · <a href="{{ route('admin.index', 'announcements') }}">Uygulama içi duyuruları yönet →</a></p>
    </section>
@else
    @if($section === 'interests')
        <section class="panel"><h2>Hobi ekle</h2>@include('admin.interest', ['entry' => null])</section>
    @elseif($section === 'roles')
        <section class="panel">
            <h2>Rol yetkileri</h2>
            <ul>
                <li><strong>Süper yönetici (super_admin):</strong> Tüm moderasyon işlemleri, sistem ve mağaza ayarları, ana sayfa modülleri, duyurular, şehir ve hobi katalogları, web içerikleri ve işlem günlüğü.</li>
                <li><strong>Moderatör (moderator):</strong> Kullanıcı inceleme ve hesap durumu yönetimi, paylaşım/yorum/karşılaşma moderasyonu, şikâyet inceleme ve engellemeler.</li>
            </ul>
        </section>
    @elseif($section === 'announcements')
        <form class="panel fields" method="post" action="{{ route('admin.announcements.create') }}">
            @csrf<h2>Duyuru oluştur</h2>
            <div class="field-grid">
                <label>Türkçe başlık<input name="title" required maxlength="120" value="{{ old('title') }}"></label>
                <label>English title (optional)<input name="title_en" maxlength="120" value="{{ old('title_en') }}"></label>
            </div>
            <div class="field-grid">
                <label>Türkçe metin<textarea name="body" required maxlength="2000" rows="4">{{ old('body') }}</textarea></label>
                <label>English body (optional, falls back to Turkish)<textarea name="body_en" maxlength="2000" rows="4">{{ old('body_en') }}</textarea></label>
            </div>
            <fieldset class="target-picker">
                <legend>Hedef</legend>
                <label class="toggle"><input type="radio" name="target_type" value="all" @checked(old('target_type', 'all') === 'all')> Tüm kullanıcılar</label>
                <label class="toggle"><input type="radio" name="target_type" value="city" @checked(old('target_type') === 'city')> Şehir</label>
                <label class="toggle"><input type="radio" name="target_type" value="location" @checked(old('target_type') === 'location')> Yaklaşık konum</label>
            </fieldset>
            <div class="field-grid"><label>Şehir (şehir hedefi için; konum hedefinde isteğe bağlı kısıt)<select name="city_id"><option value="">Seçilmedi</option>@foreach($cities as $city)<option value="{{ $city->id }}" @selected(old('city_id') == $city->id)>{{ $city->name }}</option>@endforeach</select></label>
            <label>Konum yarıçapı<select name="target_radius_m"><option value="500" @selected(old('target_radius_m') == 500)>500 m</option><option value="1000" @selected(old('target_radius_m', 1000) == 1000)>1 km</option><option value="5000" @selected(old('target_radius_m') == 5000)>5 km</option></select></label></div>
            <div id="target-map-box" class="panel" hidden>
                <p>Haritaya dokunarak yaklaşık hedef noktayı seç. Yalnızca bu bölgede yakın zamanda bulunan hesaplara gönderilir; kimsenin konumu burada listelenmez.</p>
                <div id="target-map" role="application" aria-label="Duyuru hedef noktası" style="height:320px;border-radius:12px"></div>
                <div class="field-grid"><label>Enlem<input id="target_latitude" name="target_latitude" inputmode="decimal" value="{{ old('target_latitude') }}"></label>
                <label>Boylam<input id="target_longitude" name="target_longitude" inputmode="decimal" value="{{ old('target_longitude') }}"></label></div>
            </div>
            <div class="field-grid">
            <label>Yayın zamanı (Türkiye)<input type="datetime-local" name="publish_at" value="{{ old('publish_at') }}"></label>
            <label>Bitiş zamanı (opsiyonel)<input type="datetime-local" name="expires_at" value="{{ old('expires_at') }}"></label></div>
            <label class="toggle"><input type="hidden" name="show_in_app" value="0"><input type="checkbox" name="show_in_app" value="1" checked> Uygulama içinde göster</label>
            <label class="toggle"><input type="hidden" name="send_push" value="0"><input type="checkbox" name="send_push" value="1"> Cihaz bildirimi gönder</label>
            <label class="toggle"><input type="hidden" name="is_active" value="0"><input type="checkbox" name="is_active" value="1" checked> Aktif olarak yayınla</label>
            <button class="button">Duyuruyu kaydet</button>
        </form>
        <link rel="stylesheet" href="{{ asset('web/vendor/leaflet/leaflet.css') }}">
        <script src="{{ asset('web/vendor/leaflet/leaflet.js') }}"></script>
        <script>
        (function () {
            var radios = document.querySelectorAll('input[name=target_type]');
            var box = document.getElementById('target-map-box');
            var lat = document.getElementById('target_latitude'), lng = document.getElementById('target_longitude');
            var map = null, marker = null, circle = null;
            var radius = document.querySelector('select[name=target_radius_m]');
            function draw() {
                if (!map || !lat.value || !lng.value) return;
                var point = [parseFloat(lat.value), parseFloat(lng.value)];
                if (isNaN(point[0]) || isNaN(point[1])) return;
                if (!marker) marker = L.marker(point).addTo(map); else marker.setLatLng(point);
                if (!circle) circle = L.circle(point, {radius: parseInt(radius.value, 10)}).addTo(map); else circle.setLatLng(point).setRadius(parseInt(radius.value, 10));
            }
            function show() {
                var on = document.querySelector('input[name=target_type]:checked').value === 'location';
                box.hidden = !on;
                if (on && !map) {
                    map = L.map('target-map').setView([lat.value ? parseFloat(lat.value) : 36.544, lng.value ? parseFloat(lng.value) : 32.0], lat.value ? 13 : 10);
                    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {maxZoom: 18, attribution: '© OpenStreetMap contributors'}).addTo(map);
                    map.on('click', function (e) { lat.value = e.latlng.lat.toFixed(5); lng.value = e.latlng.lng.toFixed(5); draw(); });
                    draw();
                }
                if (map) setTimeout(function () { map.invalidateSize(); }, 50);
            }
            radios.forEach(function (r) { r.addEventListener('change', show); });
            radius.addEventListener('change', draw); lat.addEventListener('change', draw); lng.addEventListener('change', draw);
            show();
        })();
        </script>
    @endif
    <section class="panel table-panel"><div class="table-wrap"><table>
        <thead><tr><th scope="col">Kayıt</th><th scope="col">Bilgi</th><th scope="col">Durum / İşlem</th></tr></thead>
        <tbody>
        @forelse($rows as $row)
            <tr>
            @switch($section)
                @case('users')
                    <td><a href="{{ route('admin.detail', [$section,$row->id]) }}">{{ $row->name }}</a><small>{{ '@'.$row->username }}</small></td><td>{{ $row->email }}<small>{{ $row->city?->name }} · {{ Records::time($row->created_at, false) }}</small></td><td><span class="chip">{{ Records::STATES[$row->account_status] ?? $row->account_status }}</span></td>
                    @break
                @case('posts')
                @case('featured')
                    <td><a href="{{ route('admin.detail', ['posts',$row->id]) }}">{{ $row->story_title ?: (\Illuminate\Support\Str::limit($row->body, 85) ?: 'Fotoğraflı paylaşım') }}</a><small>{{ Records::TYPES[$row->type] ?? $row->type }} · {{ $row->media_count }} fotoğraf</small></td>
                    <td>{{ $row->author?->name }}<small>{{ $row->city?->name }} · {{ $row->is_anonymous ? 'Anonim' : 'İsimli' }}</small></td>
                    <td>@if($section === 'featured')<form method="post" action="{{ route('admin.featured.update', $row->id) }}" class="inline-form">@csrf<label>Sıra<input type="number" min="1" max="9999" name="rank" value="{{ $row->featured_rank }}" placeholder="Otomatik"></label><button class="button outline">Kaydet</button></form>
                    @else<span class="chip">{{ $row->trashed() ? 'Kaldırıldı' : 'Aktif' }}</span>@endif</td>
                    @break
                @case('comments')
                    <td><a href="{{ route('admin.detail', [$section,$row->id]) }}">{{ \Illuminate\Support\Str::limit($row->body, 110) }}</a></td><td>{{ $row->author?->name }}</td><td><span class="chip">{{ $row->trashed() ? 'Kaldırıldı' : 'Aktif' }}</span></td>
                    @break
                @case('encounters')
                    <td><a href="{{ route('admin.detail', [$section,$row->id]) }}">{{ $row->requester?->name }} ve {{ $row->target?->name }}</a></td><td>{{ $row->encounter?->story?->story_title ?? 'Ortak hikâye yok' }}</td><td><span class="chip">{{ $row->trashed() ? 'Kaldırıldı' : (Records::ENCOUNTER_STATES[$row->status] ?? $row->status) }}</span></td>
                    @break
                @case('reports')
                    <td><a href="{{ route('admin.detail', [$section,$row->id]) }}">Şikâyet #{{ $row->id }}</a><small>{{ Records::TARGETS[$row->target_type] ?? $row->target_type }}</small></td><td>{{ Records::REASONS[$row->reason] ?? $row->reason }}<small>{{ Records::time($row->created_at) }}</small></td><td><span class="chip">{{ Records::REPORT_STATES[$row->status] ?? $row->status }}</span></td>
                    @break
                @case('blocks')
                    <td><a href="{{ route('admin.detail', ['users', $row->blocker_id]) }}">{{ $row->blocker_name ?? 'Kullanıcı #'.$row->blocker_id }}</a><small>{{ $row->blocker_username ? '@'.$row->blocker_username : '' }} (Engelleyen)</small></td>
                    <td><a href="{{ route('admin.detail', ['users', $row->blocked_id]) }}">{{ $row->blocked_name ?? 'Kullanıcı #'.$row->blocked_id }}</a><small>{{ $row->blocked_username ? '@'.$row->blocked_username : '' }} (Engellenen)</small></td>
                    <td><span class="chip">{{ Records::time($row->created_at) }}</span></td>
                    @break
                @case('roles')
                    <td>{{ $row->name }}<small>{{ $row->email }}</small></td>
                    <td>{{ $row->role === 'super_admin' ? 'Süper yönetici' : 'Moderatör' }}<small>Kayıt: {{ Records::time($row->created_at, false) }}</small></td>
                    <td><span class="chip">{{ $row->is_active ? 'Aktif' : 'Pasif' }}</span></td>
                    @break
                @case('interests')
                    <td>{{ $row->name }}<small>{{ $row->slug }}</small></td><td>{{ $row->sort_order }} · {{ $row->is_active ? 'Aktif' : 'Pasif' }}</td><td><details><summary>Düzenle</summary>@include('admin.interest', ['entry' => $row])</details></td>
                    @break
                @case('cities')
                    <td>{{ $row->name }}</td><td>{{ $row->slug }}</td><td><form method="post" action="{{ route('admin.cities.update', $row->id) }}">@csrf<input type="hidden" name="is_active" value="{{ $row->is_active ? 0 : 1 }}"><button class="button outline">{{ $row->is_active ? 'Pasifleştir' : 'Etkinleştir' }}</button></form></td>
                    @break
                @case('audit')
                    <td>{{ \App\Administration\Audit::label($row->action) }}<small>{{ $row->target_type }} {{ $row->target_id }}</small></td><td>{{ $row->name ?? '—' }}<small>{{ $row->ip_address }}</small></td><td>{{ Records::time($row->created_at) }}@if($row->metadata)<details><summary>Ayrıntılar</summary><pre>{{ json_encode(json_decode($row->metadata), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) }}</pre></details>@endif</td>
                    @break
                @case('announcements')
                    @php($expired = $row->expires_at && \Illuminate\Support\Carbon::parse($row->expires_at)->isPast())
                    <td>{{ $row->title }}<small>{{ \Illuminate\Support\Str::limit($row->body, 120) }}</small>@if($row->title_en)<small>EN: {{ $row->title_en }}</small>@endif</td>
                    <td>@if(($row->target_type ?? 'all') === 'location')Yaklaşık konum · {{ $row->target_radius_m >= 1000 ? ($row->target_radius_m / 1000).' km' : $row->target_radius_m.' m' }}{{ $row->city_id ? ' · '.$cities->firstWhere('id', $row->city_id)?->name : '' }}@else{{ $cities->firstWhere('id', $row->city_id)?->name ?? 'Tüm kullanıcılar' }}@endif<small>Hedeflenen: {{ $row->targeted_count }} · Bildirim oluşturulan: {{ $row->delivered_count }}</small><small>Yayın: {{ Records::time($row->publish_at) }}{{ $row->expires_at ? ' · Bitiş: '.Records::time($row->expires_at) : '' }}</small></td>
                    <td>
                        <span class="chip">{{ !$row->is_active ? 'Pasif' : ($expired ? 'Süresi doldu' : ($row->published_at ? 'Yayınlandı' : 'Planlandı')) }}</span>
                        <form method="post" action="{{ route('admin.announcements.update', $row->id) }}" class="inline-form">@csrf
                            <input type="hidden" name="is_active" value="{{ $row->is_active ? 0 : 1 }}">
                            <button class="button outline">{{ $row->is_active ? 'Pasifleştir' : 'Etkinleştir' }}</button>
                        </form>
                    </td>
                    @break
                @case('requests')
                    <td>{{ $row->name }}<small>{{ $row->email }}</small></td><td><details><summary>{{ $row->type === 'deletion' ? 'Hesap silme talebi' : $row->subject }}</summary><p class="preserve">{{ $row->message }}</p><small>{{ Records::time($row->created_at) }}</small></details></td><td>
                        @if($row->handled_at)<span class="chip">İncelendi</span>@else<form method="post" action="{{ route('admin.requests.handle', $row->id) }}">@csrf<button class="button outline">İncelendi olarak işaretle</button></form>@endif
                    </td>
                    @break
            @endswitch
            </tr>
        @empty<tr><td colspan="3">Bu görünümde kayıt yok.</td></tr>@endforelse
        </tbody>
    </table></div>@include('admin.pagination')</section>
@endif
@endsection
