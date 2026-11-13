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
    <nav aria-label="Ana menü">
        @foreach(['' => 'Ana Sayfa', 'nasil-calisir' => 'Nasıl Çalışır', 'ozellikler' => 'Özellikler', 'guvenlik' => 'Güvenlik'] as $path => $label)
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
            </div>
        </div>
        <div class="footer-social-col">
            <a href="https://instagram.com" class="social-icon" target="_blank" rel="noopener noreferrer" aria-label="Instagram">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="20" x="2" y="2" rx="5" ry="5"/><path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/><line x1="17.5" y1="6.5" x2="17.51" y2="6.5"/></svg>
            </a>
            <a href="https://x.com" class="social-icon" target="_blank" rel="noopener noreferrer" aria-label="X">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
            </a>
            <a href="https://tiktok.com" class="social-icon" target="_blank" rel="noopener noreferrer" aria-label="TikTok">
                <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor"><path d="M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-1.01-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.24 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z"/></svg>
            </a>
            <a href="https://youtube.com" class="social-icon" target="_blank" rel="noopener noreferrer" aria-label="YouTube">
                <svg width="19" height="19" viewBox="0 0 24 24" fill="currentColor"><path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/></svg>
            </a>
        </div>
    </div>
    <div class="footer-bottom-row">
        <small>© {{ now('Europe/Istanbul')->year }} {{ $settings['app_name'] }}. Tüm hakları saklıdır.</small>
    </div>
</div></footer>
</body>
</html>
