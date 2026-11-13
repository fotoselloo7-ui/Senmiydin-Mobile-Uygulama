@extends('website.layout')

@if($slug === '')
    @push('head')
        <link rel="preload" as="image" type="image/webp" href="{{ asset('web/hero-istanbul-tram.webp') }}" fetchpriority="high">
        <link rel="stylesheet" href="{{ asset('web/home.css') }}">
    @endpush
@endif

@section('content')
@if($slug === '')
    @include('website.home')
@endif

{{-- SUBPAGES SUPPORT (Nasıl Çalışır, Özellikler, Güvenlik, etc.) --}}
@if($slug === 'nasil-calisir')
<section class="wrap section">
    <div class="section-head">
        <span class="kicker">KARŞILAŞMADAN HİKÂYEYE</span>
        <h1>Nasıl çalışır?</h1>
        <p class="section-sub">Gerçek hayattaki bir anı paylaş, aynı yer ve zamandaki izleri keşfet ve karşılıklı onayla doğrula.</p>
    </div>
    <div class="steps-flow">
        @foreach(\App\Website\Pages::STEPS as [$heading, $body])
            <div class="step-card">
                <div class="step-left">
                    <div class="step-badge">{{ $loop->iteration }}</div>
                    <div class="step-icon icon-purple">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                    </div>
                </div>
                <div class="step-right">
                    <h3>{{ $heading }}</h3>
                    <p>{{ $body }}</p>
                </div>
            </div>
        @endforeach
    </div>
</section>
@endif

@if($slug === 'ozellikler')
<section class="surface"><div class="wrap section">
    <div class="section-head">
        <span class="kicker">KONUM TEMELLİ KEŞİF</span>
        <h1>Özellikler</h1>
        <p class="section-sub">Şehir akışı, yaklaşık mesafe keşfi, yolculuk paylaşımları ve doğrulanmış karşılaşma hikâyeleri tek deneyimde.</p>
    </div>
    <div class="feature-grid">
        @foreach(\App\Website\Pages::FEATURES as [$heading, $body])
            <article>
                <span class="feature-icon" aria-hidden="true">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
                </span>
                <div>
                    <h3>{{ $heading }}</h3>
                    <p>{{ $body }}</p>
                </div>
            </article>
        @endforeach
    </div>
</div></section>
@endif

@if($slug === 'guvenlik')
<section class="surface"><div class="wrap section safety-section">
    <div>
        <span class="kicker">GİZLİLİK VE GÜVENLİK</span>
        <h1>Güvenlik</h1>
        <p>Konum görünürlüğünü ve kimlerin mesaj isteği gönderebileceğini uygulama ayarlarından seçebilirsin.</p>
        <a class="button outline-purple" href="/gizlilik">Gizlilik politikasını incele</a>
    </div>
    <ul class="checks">
        <li>Canlı kişi takibi yoktur; diğer kullanıcılar yalnızca yaklaşık mesafeyi görür.</li>
        <li>Ortak hikâyeler iki ayrı yayın onayıyla paylaşılır.</li>
        <li>Engelleme ve şikâyet seçenekleri uygulamada bulunur.</li>
    </ul>
</div></section>
@endif

{{-- LEGAL PAGES CMS --}}
@if($legal)
<article class="wrap article"><div class="legal-sheet"><span class="kicker">YASAL BİLGİLENDİRME</span><h1>{{ $legal['title'] }}</h1>
    <div class="legal-copy">{!! nl2br(e($legal['body'])) !!}</div>
    @if(filled($settings['support_email']))<p class="legal-contact">Destek ve veri talepleri: <a href="mailto:{{ $settings['support_email'] }}">{{ $settings['support_email'] }}</a></p>@endif
</div></article>
@endif

{{-- CONTACT AND ACCOUNT DELETION FORM --}}
@if(in_array($slug, ['iletisim', 'hesap-silme'], true))
<div class="wrap article"><span class="kicker">DESTEK</span><h1>{{ $title }}</h1>
    @if($slug === 'hesap-silme')
        <p>Uygulamada Profil → Ayarlar → Hesabımı Sil ekranından şifreni doğrulayıp SİL yazarak hesabını kalıcı olarak kapatabilirsin. Uygulamaya erişemiyorsan aşağıdaki formdan talep iletebilirsin.</p>
        <p>Form bir talep kaydı oluşturur. E-posta adresini yazmak tek başına hesabı silmez. Destek ekibi hesabın sana ait olduğunu doğruladıktan sonra uygulanacak işlemi ve durumunu bildirir.</p>
        <h2>Talep hangi verileri kapsar?</h2>
        <p>Uygulama içinden silme sonrasında profil ve içeriklerin erişime kapanır. Kimlik bilgilerin anonimleştirilir; oturumların, cihazların, konum kayıtların ve geçmişin temizlenir. Paylaştığın metin ve görseller kaldırılır. İlişkiler için kişisel bilgi içermeyen kimlik kayıtları ve moderasyon işlem durumları kalır. Diğer kullanıcıların kendi içerikleri ve yedekler ayrı saklama politikasına tabidir. Yedeklerin ve destek kayıtlarının gerçek saklama süreleri veri sorumlusu tarafından açıklanmalıdır.</p>
    @else
        <p>{{ $description }}</p>
    @endif
    @if(filled($settings['support_email']))<p><a href="mailto:{{ $settings['support_email'] }}">{{ $settings['support_email'] }}</a></p>@endif
    @if(session('status'))<p class="success" role="status">{{ session('status') }}</p>@endif
    @if($errors->any())<div class="form-errors" role="alert"><ul>@foreach($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul></div>@endif
    <form method="post" action="/{{ $slug }}" class="web-form">
        @csrf
        <div class="form-pair"><label>Adın<input name="name" required maxlength="100" autocomplete="name" value="{{ old('name') }}"></label>
        <label>{{ $slug === 'hesap-silme' ? 'Hesabına kayıtlı e-posta' : 'E-posta' }}<input name="email" type="email" required maxlength="254" autocomplete="email" value="{{ old('email') }}"></label></div>
        @if($slug === 'iletisim')<label>Konu<input name="subject" required maxlength="120" value="{{ old('subject') }}"></label>@endif
        <label>{{ $slug === 'hesap-silme' ? 'Ek bilgi (isteğe bağlı)' : 'Mesaj' }}<textarea name="message" maxlength="3000" rows="5" @required($slug === 'iletisim')>{{ old('message') }}</textarea></label>
        <div class="trap" aria-hidden="true"><label>Web sitesi<input name="website" tabindex="-1" autocomplete="off"></label></div>
        <p class="muted">Form üzerinden parolanı veya kimlik belgeni gönderme. <a href="/gizlilik">Gizlilik Politikası</a></p>
        <button class="button" type="submit">{{ $slug === 'hesap-silme' ? 'Silme talebini ilet' : 'Mesaj gönder' }}</button>
    </form>
</div>
@endif
@endsection
