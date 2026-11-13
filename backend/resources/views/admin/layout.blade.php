<!doctype html>
<html lang="tr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <title>{{ $title ?? 'Yönetici girişi' }} · SenMiydin? Yönetim</title>
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
    <link rel="icon" type="image/png" sizes="32x32" href="{{ asset('web/favicon-32x32.png') }}">
    <link rel="icon" type="image/png" sizes="16x16" href="{{ asset('web/favicon-16x16.png') }}">
    <link rel="apple-touch-icon" sizes="180x180" href="{{ asset('web/apple-touch-icon.png') }}">
    <link rel="manifest" href="/site.webmanifest">
    <link rel="stylesheet" href="{{ asset('web/site.css') }}">
    <link rel="stylesheet" href="{{ asset('web/admin.css') }}">
</head>
<body class="{{ auth('admin')->check() ? 'admin-body' : 'login-body' }}">
@if(auth('admin')->check())
<aside class="sidebar">
    <a class="brand" href="{{ route('admin.dashboard') }}"><img src="{{ asset('web/logo-primary-light.png') }}" alt="SenMiydin?" width="144" height="48"></a>
    <span class="sidebar-label">YÖNETİM PANELİ</span>
    <nav aria-label="Yönetim">
        <a href="{{ route('admin.dashboard') }}" @if(request()->routeIs('admin.dashboard')) aria-current="page" @endif>Genel bakış</a>
        @foreach(\App\Http\Controllers\Admin\RecordsController::SECTIONS as $key => $label)
            @continue(!auth('admin')->user()->canManageSystem() && !in_array($key, ['users', 'posts', 'comments', 'encounters', 'reports', 'blocks'], true))
            <a href="{{ route('admin.index', $key) }}" @if(($section ?? null) === $key) aria-current="page" @endif>{{ $label }}</a>
        @endforeach
    </nav>
</aside>
<div class="admin-main">
    <header class="admin-top">
        <span>SenMiydin? <span aria-hidden="true">/</span> {{ $title }}</span>
        <div><span>{{ auth('admin')->user()->name }}</span>
            <form action="{{ route('admin.logout') }}" method="post">@csrf<button class="button outline">Çıkış</button></form>
        </div>
    </header>
    <main class="admin-content">
        @include('admin.feedback')
        @yield('content')
    </main>
</div>
@else
    @yield('content')
@endif
</body>
</html>
