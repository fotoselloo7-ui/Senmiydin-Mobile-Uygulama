<!doctype html>
<html lang="tr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $slug === '' ? $settings['app_name'].' | Bazı karşılaşmalar yarım kalmasın' : $title.' | '.$settings['app_name'] }}</title>
    <meta name="description" content="{{ $description }}">
    <meta name="robots" content="{{ app()->environment('production') ? 'index, follow' : 'noindex, nofollow' }}">
    <link rel="canonical" href="{{ $canonical }}">
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
    <link rel="icon" type="image/png" sizes="32x32" href="{{ asset('web/favicon-32x32.png') }}">
    <link rel="icon" type="image/png" sizes="16x16" href="{{ asset('web/favicon-16x16.png') }}">
    <link rel="apple-touch-icon" sizes="180x180" href="{{ asset('web/apple-touch-icon.png') }}">
    <link rel="manifest" href="/site.webmanifest">
    <meta property="og:type" content="website">
    <meta property="og:locale" content="tr_TR">
    <meta property="og:site_name" content="{{ $settings['app_name'] }}">
    <meta property="og:title" content="{{ $title }}">
    <meta property="og:description" content="{{ $description }}">
    <meta property="og:url" content="{{ $canonical }}">
    <meta property="og:image" content="{{ config('website.url') }}/web/og.png">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="{{ $title }}">
    <meta name="twitter:description" content="{{ $description }}">
    <meta name="twitter:image" content="{{ config('website.url') }}/web/og.png">
    <script>document.documentElement.classList.add('js')</script>
    <link rel="stylesheet" href="{{ asset('web/site.css') }}">
    <script src="{{ asset('web/site.js') }}" defer></script>
    @if($slug === '')
        <script type="application/ld+json">{!! json_encode([
            '@context' => 'https://schema.org', '@type' => 'SoftwareApplication',
            'name' => $settings['app_name'], 'applicationCategory' => 'SocialNetworkingApplication',
            'operatingSystem' => 'Android, iOS', 'url' => $canonical, 'description' => $description,
            ...(($stores = array_values(array_filter([$settings['app_store_url'], $settings['play_store_url']]))) ? ['downloadUrl' => $stores] : []),
        ], JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE) !!}</script>
    @endif
</head>
<body>
<a class="skip" href="#icerik">İçeriğe geç</a>
<header class="site-header"><div class="wrap header-inner">
    <a href="/" class="brand"><img src="{{ asset('web/logo-primary-light.png') }}" alt="{{ $settings['app_name'] }}" width="156" height="52"></a>
    <button type="button" class="nav-toggle" aria-expanded="false" aria-controls="ana-menu" aria-label="Menüyü aç">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><line class="bar-a" x1="4" y1="7" x2="20" y2="7"/><line class="bar-b" x1="4" y1="12" x2="20" y2="12"/><line class="bar-c" x1="4" y1="17" x2="20" y2="17"/></svg>
    </button>
    <nav id="ana-menu" aria-label="Ana menü">
        @foreach(['' => 'Ana Sayfa', 'nasil-calisir' => 'Nasıl Çalışır', 'ozellikler' => 'Özellikler', 'guvenlik' => 'Güvenlik', 'iletisim' => 'İletişim'] as $path => $label)
            <a href="/{{ $path }}" @if($slug === $path) aria-current="page" @endif>{{ $label }}</a>
        @endforeach
    </nav>
    <a class="button header-cta" href="/#indir">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
        Uygulamayı Keşfet
    </a>
</div></header>
@if($settings['maintenance_mode'])
    <aside class="maintenance" role="status">{{ $settings['maintenance_message'] }}</aside>
@endif
@if(filled($settings['web_announcement'] ?? null))
    <aside class="maintenance" role="status">{{ $settings['web_announcement'] }}</aside>
@endif
<main id="icerik">@yield('content')</main>
<footer class="site-footer"><div class="wrap">
    <div class="footer-top-row">
        <div class="footer-brand-col">
            <a href="/" class="brand">
                <img src="{{ asset('web/logo-primary-light.png') }}" alt="{{ $settings['app_name'] }}" width="156" height="52">
            </a>
            <p>Şehrinde karşılaştığın insanları yeniden bul.</p>
        </div>
        <div class="footer-links-group">
            <div class="footer-col">
                <a href="/">Ana Sayfa</a>
                <a href="/nasil-calisir">Nasıl Çalışır</a>
            </div>
            <div class="footer-col">
                <a href="/ozellikler">Özellikler</a>
                <a href="/guvenlik">Güvenlik</a>
            </div>
            <div class="footer-col">
                <a href="/gizlilik">Gizlilik Politikası</a>
                <a href="/kullanim-kosullari">Kullanım Koşulları</a>
                <a href="/topluluk-kurallari">Topluluk Kuralları</a>
                <a href="/iletisim">İletişim</a>
                <a href="/hesap-silme">Hesap Silme</a>
            </div>
        </div>
    </div>
    <div class="footer-bottom-row">
        <small>© {{ now('Europe/Istanbul')->year }} {{ $settings['app_name'] }}. Tüm hakları saklıdır.</small>
    </div>
</div></footer>
</body>
</html>
