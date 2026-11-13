@extends('website.layout')

@section('content')
@if($slug === '')
@php
$pin = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>';
$slides = [
    ['tram', 'İstanbul · İstiklal', 'Kırmızı tramvay durağındaki o an', '“Elinde kahve, kulaklığı boynunda olan; tramvaya birlikte baktığımız sen miydin?”', 'web/hero-istanbul-tram.jpg', 'İstiklal Caddesi’nde kırmızı tramvayın önünde konuşan iki kişi'],
    ['ferry', 'İstanbul · Kadıköy', 'Akşam vapurunda gün batımı', '“Martılara simit atarken göz göze geldiğimiz sen miydin?”', 'web/polaroid-kiz-kulesi.jpg', 'Gün batımında Kız Kulesi ve Boğaz'],
    ['cafe', 'İstanbul · Moda', 'Köşe masadaki kahve', '“Kitabını kapatıp bana gülümseyen, ikinci kahveyi sipariş eden sen miydin?”', 'web/coffee.jpg', 'Bir kafede demlenen filtre kahve'],
    ['note', 'Ankara · Kütüphane', 'Masama bıraktığın not', '“Masama bıraktığın nota teşekkür etmek istedim. Kim olduğunu hâlâ merak ediyorum.”', null, null],
    ['trip', 'Ankara → Eskişehir · Tren', 'Cam kenarında bir yolculuk', '“Seferin ortasında kitabını bana uzatan sen miydin?”', 'web/journey.jpg', 'Raylar boyunca ilerleyen bir tren'],
];
@endphp

{{-- 1. HERO --}}
<section class="hero">
    <div class="wrap hero-grid">
        <div class="hero-copy">
            <div class="hero-eyebrow">
                <svg class="eyebrow-pin-svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                <span>Gerçek hayattaki karşılaşmalar için şehir bazlı sosyal keşif</span>
            </div>
            <h1>Kaçırdığın<br>karşılaşmalar artık<br>sadece <span class="highlight-blue">bir ihtimal değil.</span></h1>
            <p class="hero-lead">SenMiydin; şehirde yolunun kesiştiği anları, anıları, düşünceleri, itirafları ve yolculukları paylaşabildiğin bir uygulamadır. Bir karşılaşma, ancak karşı taraf kabul ettiğinde doğrulanır.<span class="sr-only"> Bazı karşılaşmalar yarım kalmasın.</span></p>

            <div class="hero-cta-group">
                @include('website.stores')
            </div>

            <div class="hero-trust-row">
                <span class="trust-item">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#0877E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
                    Karşılıklı onay
                </span>
                <span class="trust-item">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#0877E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                    Kesin konum paylaşılmaz
                </span>
                <span class="trust-item">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                    Şehrine özel akış
                </span>
            </div>
            <a class="sr-only" href="#nasil-calisir">Nasıl çalıştığını keşfet</a>
        </div>

        <div class="story-slider" data-slider role="region" aria-roledescription="carousel" aria-label="Örnek karşılaşma hikâyeleri">
            <div class="story-glow" aria-hidden="true"></div>
            <div class="story-stage">
                @foreach($slides as $i => [$key, $loc, $title, $text, $img, $alt])
                    <figure class="story-slide story-{{ $key }} @if($i === 0) is-active @endif" role="group" aria-roledescription="slide" aria-label="{{ $i + 1 }} / {{ count($slides) }}" @if($i !== 0) aria-hidden="true" @endif>
                        @if($img)
                            <img src="{{ asset($img) }}" alt="{{ $alt }}" @if($i !== 0) loading="lazy" @endif width="1200" height="760">
                        @else
                            <div class="story-note-art" aria-hidden="true">
                                <span class="note-paper">
                                    <i></i>
                                    <b>Teşekkürler!</b>
                                    <em>Bu notu bana bırakan kişiyi arıyorum.</em>
                                </span>
                            </div>
                        @endif
                        <figcaption class="story-caption">
                            <span class="story-meta">
                                <span class="story-loc">{!! $pin !!} {{ $loc }}</span>
                                <span class="story-badge">Temsili paylaşım</span>
                            </span>
                            <strong>{{ $title }}</strong>
                            <p>{{ $text }}</p>
                        </figcaption>
                    </figure>
                @endforeach
            </div>
            <div class="story-controls">
                <div class="story-dots">
                    @foreach($slides as $i => [$key, $loc, $title])
                        <button type="button" class="story-dot @if($i === 0) is-active @endif" data-index="{{ $i }}" aria-label="{{ $i + 1 }}. hikâye: {{ $title }}" @if($i === 0) aria-current="true" @endif></button>
                    @endforeach
                </div>
                <button type="button" class="story-pause" data-pause aria-label="Otomatik geçişi duraklat" aria-pressed="false">
                    <svg class="icon-pause" width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/></svg>
                    <svg class="icon-play" width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>
                </button>
            </div>
        </div>
    </div>
</section>

{{-- 2. SENMİYDİN NEDİR? --}}
<section class="wrap section section-about" id="nedir">
    <div class="section-head-split">
        <div class="split-left">
            <span class="kicker">SENMİYDİN NEDİR?</span>
            <h2>Günlük karşılaşmaları<br>hikâyeye dönüştürür.</h2>
            <p class="section-sub">SenMiydin bir flört uygulaması değildir. Şehrindeki anıları, düşünceleri ve itirafları keşfedebilir, yolculukta ya da sokakta yarım kalan bir karşılaşmayı karşı tarafın onayıyla tamamlayabilirsin.</p>
        </div>
        <div class="split-right-cards">
            <div class="about-card card-purple">
                <div class="about-card-icon">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                </div>
                <h3>Gerçek<br>Karşılaşmalar</h3>
            </div>
            <div class="about-card card-blue">
                <div class="about-card-icon">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#0877E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                </div>
                <h3>Şehir Bazlı<br>Keşif</h3>
            </div>
            <div class="about-card card-purple">
                <div class="about-card-icon">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
                </div>
                <h3>Anılar, Düşünceler<br>ve İtiraflar</h3>
            </div>
        </div>
    </div>
</section>

{{-- 3. NASIL ÇALIŞIR? --}}
<section class="wrap section section-steps" id="nasil-calisir">
    <div class="section-head">
        <span class="kicker">NASIL ÇALIŞIR?</span>
        <h2>Üç adımda bir karşılaşmayı hikâyeye çevir.</h2>
    </div>
    <div class="steps-flow">
        <div class="step-card">
            <div class="step-left">
                <div class="step-badge">1</div>
                <div class="step-icon">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                </div>
            </div>
            <div class="step-right">
                <h3>Şehrini seç</h3>
                <p>Yaşadığın şehir profilinde kalır; keşfettiğin şehri istediğin zaman ayrıca seçebilirsin.</p>
            </div>
        </div>
        <div class="step-arrow-connector" aria-hidden="true">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#98A2B3" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
        </div>
        <div class="step-card">
            <div class="step-left">
                <div class="step-badge">2</div>
                <div class="step-icon">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                </div>
            </div>
            <div class="step-right">
                <h3>Bir an paylaş</h3>
                <p>Anı, karşılaşma, itiraf, düşünce veya yolculuk. İstersen fotoğraf ekle, istersen anonim kal.</p>
            </div>
        </div>
        <div class="step-arrow-connector" aria-hidden="true">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#98A2B3" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
        </div>
        <div class="step-card">
            <div class="step-left">
                <div class="step-badge">3</div>
                <div class="step-icon">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
                </div>
            </div>
            <div class="step-right">
                <h3>Karşılıklı onayla</h3>
                <p>Etiketlediğin kişi kabul ederse karşılaşma doğrulanır; ortak hikâye için ayrıca yayın onayı gerekir.</p>
            </div>
        </div>
    </div>
</section>

{{-- 4. ŞEHİR BAZLI AKIŞ --}}
<section class="surface section-feature-band" id="sehir-akisi">
    <div class="wrap feature-row">
        <div class="feature-copy">
            <span class="kicker">ŞEHİR BAZLI AKIŞ</span>
            <h2>Şehrinde paylaşılanları<br>kendi ritminde keşfet.</h2>
            <p>Paylaşımlar varsayılan olarak şehir genelinde keşfedilebilir. Yakınlık, bir sıralama sinyalidir; paylaşımı küçük bir çembere hapsetmez.</p>
            <ul class="chip-list" aria-label="İçerik türleri">
                <li>Anı</li><li>Karşılaşma</li><li>İtiraf</li><li>Düşünce</li><li>Yolculuk</li>
            </ul>
            <dl class="spec-list">
                <div><dt>Kapsam</dt><dd>Tüm şehir · 5 km · 10 km · 25 km</dd></div>
                <div><dt>Sıralama</dt><dd>Yakın · Yeni · Popüler</dd></div>
                <div><dt>Filtreler</dt><dd>İçerik türü, fotoğraf ve ilgi alanı birlikte kullanılabilir.</dd></div>
            </dl>
        </div>
        <div class="feature-shot">
            <figure class="phone-shot"><img src="{{ asset('web/screens/app-home.png') }}" alt="SenMiydin Ana Sayfa: şehir akışı ve karşılaşma hikâyeleri" loading="lazy" width="540" height="1200"></figure>
        </div>
    </div>
</section>

{{-- 5. YAKINDAKİ İNSANLAR / HARİTA --}}
<section class="wrap section feature-row feature-row-reverse" id="harita">
    <div class="feature-shot">
        <figure class="phone-shot"><img src="{{ asset('web/screens/app-map.png') }}" alt="SenMiydin harita: yakındaki yaklaşık paylaşımlar" loading="lazy" width="540" height="1200"></figure>
    </div>
    <div class="feature-copy">
        <span class="kicker">YAKINDAKİ İNSANLAR VE HARİTA</span>
        <h2>Yakınında olanı gör,<br>kendini ise sen göster.</h2>
        <p>Yakınındaki İnsanlar listesinde yalnızca “yakınımda görünür” seçeneğini kendisi açan kişiler yer alır. Ayarı kapattığında listeden gerçekten çıkarsın.</p>
        <ul class="check-list">
            <li>Yalnızca yaklaşık mesafe gösterilir.</li>
            <li>Kesin GPS konumu ve açık adres paylaşılmaz.</li>
            <li>Gerçek zamanlı rota gösterilmez. Canlı kişi takibi yoktur.</li>
            <li>Konum izni vermezsen şehri elle seçip uygulamayı kullanmayı sürdürebilirsin.</li>
        </ul>
    </div>
</section>

{{-- 6. PAYLAŞIM OLUŞTURMA --}}
<section class="surface section-feature-band" id="paylasim">
    <div class="wrap feature-row">
        <div class="feature-copy">
            <span class="kicker">PAYLAŞIM OLUŞTURMA</span>
            <h2>Yalnızca metin de olur,<br>on fotoğrafa kadar da.</h2>
            <p>Bir paylaşımı yazmak yeterlidir. İstersen fotoğraf ekler, sırasını değiştirir ve sonradan düzenlersin.</p>
            <ul class="check-list">
                <li>En fazla 10 fotoğraf, kaydırmalı gösterim ve 1/2 gibi sayaç.</li>
                <li>Anonim paylaşım: adın ve profil bağlantın görünmez.</li>
                <li>Şehir görünürlüğü ve yaklaşık yer seçimi sende.</li>
                <li>Olayın gerçekleştiği zamanı belirtebilir, paylaşımını düzenleyip silebilirsin.</li>
            </ul>
        </div>
        <div class="feature-shot">
            <figure class="phone-shot"><img src="{{ asset('web/screens/app-compose.png') }}" alt="SenMiydin paylaşım oluşturma ekranı" loading="lazy" width="540" height="1200"></figure>
        </div>
    </div>
</section>

{{-- 7. KARŞILAŞMA + ONAY --}}
<section class="wrap section feature-row feature-row-reverse" id="karsilasma">
    <div class="feature-shot">
        <figure class="phone-shot"><img src="{{ asset('web/screens/app-encounter.png') }}" alt="SenMiydin karşılaşma ve onay ekranı" loading="lazy" width="540" height="1200"></figure>
    </div>
    <div class="feature-copy">
        <span class="kicker">KARŞILAŞMA VE ONAY</span>
        <h2>Doğrulanmış karşılaşma<br>iki tarafın kararıdır.</h2>
        <ol class="number-list">
            <li><strong>Etiketle.</strong> Karşılaştığın kişiyi @kullanıcıadı ile etiketlersin.</li>
            <li><strong>Karar versin.</strong> Karşı taraf isteği kabul eder ya da reddeder. Bekleyen isteği sen de geri çekebilirsin.</li>
            <li><strong>Hikâyeni yayınla.</strong> Kabulden sonra ortak hikâye oluşturabilirsiniz; diğer taraf onay vermeden yayınlanmaz.</li>
        </ol>
        <p class="note-line">“Geçtiğim Yerler” önerileri yalnızca bir tahmindir ve kendiliğinden karşılaşma oluşturmaz.</p>
    </div>
</section>

{{-- 8. YOLCULUK --}}
<section class="surface section-feature-band" id="yolculuk">
    <div class="wrap feature-row">
        <div class="feature-copy">
            <span class="kicker">Yolculuk Paylaşımları</span>
            <h2>Yolda yarım kalan bir an<br>için doğru ayrıntılar.</h2>
            <p>Yolculuk paylaşımına güzergâhı ve yaklaşık zamanı ekleyebilirsin. Aynı güzergâh ve zaman aralığı yalnızca bir keşif ipucudur.</p>
            <ul class="chip-list" aria-label="Ulaşım türleri">
                <li>Otobüs</li><li>Tren</li><li>Uçak</li><li>Feribot</li><li>Diğer</li>
            </ul>
            <dl class="spec-list">
                <div><dt>Güzergâh</dt><dd>Kalkış ve varış şehri, yaklaşık saat</dd></div>
                <div><dt>Ayrıntılar</dt><dd>Firma, sefer kodu ve isteğe bağlı araç kimliği; herkese açık veya özel</dd></div>
                <div><dt>Örnek</dt><dd>Pamukkale · Ankara → Erzincan · 07 NM 365</dd></div>
            </dl>
            <p class="note-line">Yolculuk grubu, oda veya katılım butonu yoktur; kimsenin aynı araçta bulunduğu iddia edilmez.</p>
        </div>
        <div class="feature-shot">
            <figure class="phone-shot"><img src="{{ asset('web/screens/app-journey.png') }}" alt="SenMiydin yolculuk paylaşımı ekranı" loading="lazy" width="540" height="1200"></figure>
        </div>
    </div>
</section>

{{-- 9. MESAJLAŞMA --}}
<section class="wrap section feature-row feature-row-reverse" id="mesajlasma">
    <div class="feature-shot">
        <figure class="phone-shot"><img src="{{ asset('web/screens/app-chat.png') }}" alt="SenMiydin birebir mesajlaşma ekranı" loading="lazy" width="540" height="1200"></figure>
    </div>
    <div class="feature-copy">
        <span class="kicker">MESAJLAŞMA</span>
        <h2>Birebir ve izinli<br>mesajlaşma.</h2>
        <p>İlk mesaj bir istektir; alıcı kabul ettiğinde sohbet devam eder. Hiç kimse seni dinlemeye mecbur bırakılmaz.</p>
        <ul class="check-list">
            <li>Mesaj isteğini kabul etme veya reddetme</li>
            <li>Fotoğraf mesajı, okundu bilgisi ve okunmamış sayacı</li>
            <li>Sohbeti gizleme, kullanıcıyı engelleme ve şikâyet etme</li>
        </ul>
    </div>
</section>

{{-- 10. GİZLİLİK / GÜVENLİK --}}
<section class="wrap section section-security" id="guvenlik">
    <div class="security-split">
        <div class="security-left">
            <span class="kicker">GİZLİLİK VE GÜVENLİK</span>
            <h2>Rahat, saygılı ve güvenli<br>bir deneyim.</h2>
            <p>Konumun, görünürlüğün ve iletişimin üzerinde kontrol sende kalır.</p>
            <a href="/guvenlik" class="button button-soft-blue">
                Güvenlik Sayfasını İncele
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
            </a>
        </div>
        <div class="security-right-rows">
            <div class="sec-row-item">
                <div class="sec-row-icon icon-blue">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#0877E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                </div>
                <div class="sec-row-content">
                    <h3>Geçtiğim Yerler varsayılan olarak kapalı</h3>
                    <p>Açarsan yaklaşık bölgeler en fazla 7 gün saklanır. Kapattığında kayıtların ve eşleşmelerin silinir.<span class="sr-only"> Canlı kişi takibi yoktur; diğer kullanıcılar yalnızca yaklaşık mesafeyi görür.</span></p>
                </div>
            </div>
            <div class="sec-row-item">
                <div class="sec-row-icon icon-blue">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#0877E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>
                </div>
                <div class="sec-row-content">
                    <h3>Bildirim tercihlerin ayrı ayrı</h3>
                    <p>Veri kaydı, geçtiğin yerlerden haber ve yakın bölge aktiviteleri ayrı ayrı açılıp kapanır.</p>
                </div>
            </div>
            <div class="sec-row-item">
                <div class="sec-row-icon icon-purple">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg>
                </div>
                <div class="sec-row-content">
                    <h3>Raporla, engelle, hesabını sil</h3>
                    <p>Uygunsuz davranışları bildir, istemediğin kişileri engelle, istediğin zaman hesabını ve verilerini sil.</p>
                </div>
            </div>
        </div>
    </div>
</section>

{{-- 11. GERÇEK MOBİL EKRANLAR --}}
<section class="surface section-screens" id="ekranlar">
    <div class="wrap section">
        <div class="section-head">
            <span class="kicker">GERÇEK EKRANLAR</span>
            <h2>Uygulamadan gerçek görüntüler</h2>
            <p class="section-sub">Aşağıdaki ekranlar, uygulamanın Android sürümünden alınmış gerçek ekran görüntüleridir.</p>
        </div>
        <ul class="screens-row">
            @foreach([['app-home', 'Ana Sayfa'], ['app-profile', 'Profil'], ['app-drawer', 'Menü'], ['app-viewer', 'Fotoğraf görüntüleyici']] as [$file, $label])
                <li><figure class="phone-shot"><img src="{{ asset('web/screens/'.$file.'.png') }}" alt="SenMiydin {{ $label }} ekranı" loading="lazy" width="540" height="1200"><figcaption>{{ $label }}</figcaption></figure></li>
            @endforeach
        </ul>
    </div>
</section>

{{-- 12. FİNAL CTA --}}
<section class="section-bottom-cta-wrap" id="indir">
    <div class="wrap final-cta">
        <div class="final-cta-copy">
            <h2>{{ $settings['web_cta'] }}</h2>
            @if(filled($settings['app_store_url']) || filled($settings['play_store_url']))
                <p>Uygulamayı indir ve şehrindeki karşılaşmaları keşfetmeye başla.</p>
            @else
                <p>Mağaza bağlantıları yayınlandığında burada olacak. Şimdilik “Yakında” durumundadır.</p>
            @endif
        </div>
        <div class="cta-stores-row">
            @include('website.stores')
        </div>
    </div>
</section>
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
