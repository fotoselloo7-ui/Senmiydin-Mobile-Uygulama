<!doctype html>
<html lang="{{ $locale }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title }}</title>
    <meta name="description" content="{{ $description }}">
    <meta name="robots" content="noindex, nofollow">
    <link rel="canonical" href="{{ $canonical }}">
    <link rel="icon" type="image/png" sizes="32x32" href="{{ asset('web/favicon-32x32.png') }}">
    <meta property="og:type" content="article">
    <meta property="og:site_name" content="{{ $settings['app_name'] ?? 'SenMiydin?' }}">
    <meta property="og:title" content="{{ $title }}">
    <meta property="og:description" content="{{ $description }}">
    <meta property="og:url" content="{{ $canonical }}">
    <meta property="og:image" content="{{ config('website.url') }}/web/og.png">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="{{ $title }}">
    <meta name="twitter:description" content="{{ $description }}">
    <meta name="twitter:image" content="{{ config('website.url') }}/web/og.png">
    <style>
        :root{color-scheme:light;--ink:#12213f;--muted:#5b6785;--blue:#0a66d6;--lilac:#7c20d4;--line:#e3e8f0}
        *{box-sizing:border-box}body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;color:var(--ink);background:linear-gradient(180deg,#f3f0ff,#eef5ff 60%,#fff);min-height:100vh}
        .wrap{max-width:560px;margin:0 auto;padding:24px 18px 48px}.brand{display:flex;justify-content:center;margin:8px 0 22px}.brand img{height:48px;width:auto}
        .card{background:#fff;border:1px solid var(--line);border-radius:24px;padding:22px;box-shadow:0 10px 30px rgba(60,40,120,.08)}
        .kind{font-size:13px;font-weight:700;color:var(--lilac);text-transform:uppercase;letter-spacing:.06em}.who{font-weight:800;font-size:18px;margin:8px 0 2px}
        .handle,.meta{color:var(--muted);font-size:14px}.badge{display:inline-block;margin-top:8px;padding:3px 10px;border-radius:999px;background:#fdf2f8;color:#be185d;font-size:12px;font-weight:800;border:1px solid #fbcfe8}
        .body{white-space:pre-wrap;font-size:18px;line-height:1.55;margin:16px 0;overflow-wrap:anywhere}
        .cta{display:block;text-align:center;background:var(--blue);color:#fff;text-decoration:none;font-weight:800;border-radius:16px;padding:14px 18px;margin-top:20px}
        .stores{display:flex;gap:10px;justify-content:center;margin-top:12px;flex-wrap:wrap}.stores a{color:var(--blue);font-weight:700;text-decoration:none;border:1px solid var(--line);border-radius:12px;padding:9px 14px;background:#fff}
        .note{text-align:center;color:var(--muted);font-size:13px;margin-top:14px}
    </style>
</head>
<body>
<div class="wrap">
    <div class="brand"><img src="{{ asset('web/logo-primary-light.png') }}" alt="{{ $settings['app_name'] ?? 'SenMiydin?' }}"></div>
    <article class="card">
        <div class="kind">{{ $content['kind'] }}</div>
        <div class="who">{{ $content['who'] }}</div>
        @foreach($content['handles'] as $handle)<div class="handle">{{ $handle }}</div>@endforeach
        @if($content['badge'])<span class="badge">{{ $content['badge'] }}</span>@endif
        <p class="body">{{ $content['excerpt'] }}</p>
        <div class="meta">{{ $content['place'] }} · {{ $content['date']->locale($locale)->translatedFormat('j F Y') }}</div>
        <a class="cta" href="{{ $deepLink }}">{{ $t['open'] }}</a>
        @php($play = $settings['play_store_url'] ?? '')
        @php($apple = $settings['app_store_url'] ?? '')
        @if($play || $apple)
            <div class="stores">
                @if($play)<a href="{{ $play }}" rel="noopener">{{ $t['play'] }}</a>@endif
                @if($apple)<a href="{{ $apple }}" rel="noopener">{{ $t['app_store'] }}</a>@endif
            </div>
        @endif
    </article>
    <p class="note">{{ $t['tagline'] }}</p>
</div>
</body>
</html>
