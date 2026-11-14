<!doctype html>
@php($c ??= \App\Website\Site::chrome($locale ?? 'tr'))
@php($locale ??= 'tr')
<html lang="{{ $c['lang'] }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $slug === '' ? $settings['app_name'].$c['title_home'] : $title.' | '.$settings['app_name'] }}</title>
    <meta name="description" content="{{ $description }}">
    <meta name="robots" content="{{ app()->environment('production') ? 'index, follow' : 'noindex, nofollow' }}">
    <link rel="canonical" href="{{ $canonical }}">
    @isset($alternate)
        <link rel="alternate" hreflang="tr" href="{{ $alternate['tr'] }}">
        <link rel="alternate" hreflang="en" href="{{ $alternate['en'] }}">
        <link rel="alternate" hreflang="x-default" href="{{ $alternate['tr'] }}">
    @endisset
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
    <link rel="icon" type="image/png" sizes="32x32" href="{{ asset('web/favicon-32x32.png') }}">
    <link rel="icon" type="image/png" sizes="16x16" href="{{ asset('web/favicon-16x16.png') }}">
    <link rel="apple-touch-icon" sizes="180x180" href="{{ asset('web/apple-touch-icon.png') }}">
    <link rel="manifest" href="/site.webmanifest">
    <meta property="og:type" content="website">
    <meta property="og:locale" content="{{ $c['og_locale'] }}">
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
    @stack('head')
    @if($slug === '')
        <script type="application/ld+json">{!! json_encode([
            '@context' => 'https://schema.org', '@type' => 'SoftwareApplication',
            'name' => $settings['app_name'], 'applicationCategory' => 'SocialNetworkingApplication',
            'operatingSystem' => 'Android, iOS', 'url' => $canonical, 'description' => $description,
            'featureList' => ['Şehir bazlı sosyal akış', 'Karşılıklı onaylı karşılaşmalar', 'Harita Notları: 7 gün kalan dijital mektuplar', 'Yolculuk paylaşımları', 'İzinli birebir mesajlaşma', 'Yaklaşık konum ve gizlilik kontrolleri'],
            ...(($stores = array_values(array_filter([$settings['app_store_url'], $settings['play_store_url']]))) ? ['downloadUrl' => $stores] : []),
        ], JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE) !!}</script>
    @endif
</head>
<body>
<a class="skip" href="#icerik">{{ $c['skip'] }}</a>
<header class="site-header"><div class="wrap header-inner">
    <a href="{{ $locale === 'en' ? '/en' : '/' }}" class="brand"><img src="{{ asset('web/logo-primary-light.png') }}" alt="{{ $settings['app_name'] }}" width="156" height="52"></a>
    <button type="button" class="nav-toggle" aria-expanded="false" aria-controls="ana-menu" aria-label="{{ $c['menu_open'] }}">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><line class="bar-a" x1="4" y1="7" x2="20" y2="7"/><line class="bar-b" x1="4" y1="12" x2="20" y2="12"/><line class="bar-c" x1="4" y1="17" x2="20" y2="17"/></svg>
    </button>
    <nav id="ana-menu" aria-label="{{ $c['main_nav'] }}">
        @php($home = $locale === 'en' ? '/en' : '/')
        @foreach($c['nav'] as [$target, $label, $page])
            <a href="{{ str_starts_with($target, '#') ? $home.$target : ($locale === 'en' ? '/en/'.$target : '/'.$target) }}" @if($page && $slug === $page) aria-current="page" @endif>{{ $label }}</a>
        @endforeach
        <a href="{{ $home }}#indir" class="nav-cta-mobile">{{ $c['cta'] }}</a>
        @isset($alternate)
            <a class="lang-switch lang-switch-mobile" href="{{ $locale === 'en' ? $alternate['tr'] : $alternate['en'] }}" hreflang="{{ $locale === 'en' ? 'tr' : 'en' }}" lang="{{ $locale === 'en' ? 'tr' : 'en' }}">{{ $c['switch_label'] }}</a>
        @endisset
    </nav>
    @isset($alternate)
        <a class="lang-switch" href="{{ $locale === 'en' ? $alternate['tr'] : $alternate['en'] }}" hreflang="{{ $locale === 'en' ? 'tr' : 'en' }}" lang="{{ $locale === 'en' ? 'tr' : 'en' }}" aria-label="{{ $c['switch_aria'] }}"><span @if($locale === 'tr') aria-current="true" @endif>TR</span><span aria-hidden="true">/</span><span @if($locale === 'en') aria-current="true" @endif>EN</span></a>
    @endisset
    <a class="button header-cta" href="{{ $home }}#indir">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
        {{ $c['cta'] }}
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
            <p>{{ $c['footer_tagline'] }}</p>
        </div>
        <div class="footer-links-group">
            <div class="footer-col">
                <a href="{{ $home }}">{{ $c['footer_home'] }}</a>
                <a href="{{ \App\Website\Site::path('nasil-calisir', $locale) }}">{{ $c['footer_how'] }}</a>
                <a href="{{ $home }}#harita-notlari">{{ $c['footer_notes'] }}</a>
            </div>
            <div class="footer-col">
                <a href="{{ \App\Website\Site::path('ozellikler', $locale) }}">{{ $c['footer_features'] }}</a>
                <a href="{{ \App\Website\Site::path('guvenlik', $locale) }}">{{ $c['footer_safety'] }}</a>
            </div>
            <div class="footer-col">
                @foreach($c['footer_legal'] as [$legalSlug, $legalLabel])
                    <a href="{{ \App\Website\Site::path($legalSlug, $locale) }}">{{ $legalLabel }}</a>
                @endforeach
            </div>
        </div>
    </div>
    <div class="footer-bottom-row">
        <small>© {{ now('Europe/Istanbul')->year }} {{ $settings['app_name'] }}. {{ $c['rights'] }}</small>
    </div>
</div></footer>
</body>
</html>
