@extends('admin.layout')
@section('content')
<main class="login-panel">
    <a class="brand" href="/"><img src="{{ asset('web/logo-primary-light.png') }}" alt="SenMiydin?" width="180" height="60"></a>
    <span class="kicker">YÖNETİM PANELİ</span>
    <h1>Yönetici girişi</h1>
    <p>Topluluğu ve uygulama ayarlarını yönet.</p>
    @include('admin.feedback')
    <form action="{{ route('admin.login.store') }}" method="post" class="fields">
        @csrf
        <label>E-posta<input name="email" type="email" value="{{ old('email') }}" autocomplete="username" required autofocus></label>
        <label>Parola<input name="password" type="password" autocomplete="current-password" required></label>
        <button type="submit" class="button">Giriş yap</button>
    </form>
</main>
@endsection
