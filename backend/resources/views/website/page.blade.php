@extends('website.layout')

@section('content')
@if($slug === '')
{{-- 1. HERO SECTION --}}
<section class="hero">
    <div class="wrap hero-grid">
        <div class="hero-copy">
            <div class="hero-eyebrow">
                <svg class="eyebrow-pin-svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                <span>Şehrinde Tanışma ve Karşılaşma Platformu</span>
            </div>
            <h1>Kaçırdığın<br>karşılaşmalar artık<br>sadece <span class="highlight-blue">bir ihtimal değil.</span></h1>
            <p class="hero-lead">SenMiydin, günlük hayatta yolunun kesiştiği, dikkatini çeken insanları yeniden bulmana ve anlamlı tanışmalara kapı aralamana yardımcı olur.<span class="sr-only"> Bazı karşılaşmalar yarım kalmasın.</span></p>
            
            <div class="hero-cta-group">
                @include('website.stores')
            </div>

            <div class="hero-trust-row">
                <span class="trust-item">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#0877E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                    Gerçek insanlarla
                </span>
                <span class="trust-item">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#0877E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                    Güvenli ve kontrollü
                </span>
                <span class="trust-item">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                    Şehrine özel
                </span>
            </div>
            <a class="sr-only" href="#nasil-calisir">Nasıl çalıştığını keşfet</a>
        </div>

        <div class="hero-showcase" aria-label="Uygulama önizlemesi">
            <div class="hero-showcase-glow" aria-hidden="true"></div>
            <div class="hero-photo-card">
                <img src="{{ asset('web/hero-istanbul-tram.jpg') }}" alt="İstanbul tramvay karşılaşma anı" class="hero-main-photo">

                <div class="hero-floating-quote">
                    <div class="quote-slide-inner">
                        <div class="quote-header">
                            <span class="quote-location">
                                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                                İstanbul · Kadıköy
                            </span>
                            <span class="sr-only">Temsili paylaşım</span>
                        </div>
                        <strong class="quote-title">Bugün vapurda karşılaştığımız kişi...</strong>
                        <p class="quote-text">“Sarı montlu, kitap okuyan ve vapurda karşı koltukta oturan sen miydin?”</p>
                    </div>
                    <a href="#indir" class="quote-action-btn" aria-label="Keşfet">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
                    </a>
                </div>
            </div>
            <div class="carousel-dots" aria-hidden="true">
                <span class="dot active"></span>
                <span class="dot"></span>
                <span class="dot"></span>
                <span class="dot"></span>
            </div>
        </div>
    </div>
</section>

{{-- 2. SENMİYDİN NEDİR? --}}
<section class="wrap section section-about">
    <div class="section-head-split">
        <div class="split-left">
            <span class="kicker">SENMİYDİN NEDİR?</span>
            <h2>Günlük karşılaşmaları<br>anlamlı tanışmalara dönüştürür.</h2>
            <p class="section-sub">Şehrinde fark ettiğin, dikkatini çeken, ama tanışma fırsatı bulamadığın<br>kişileri bulmanı, onlarla güvenli ve saygılı bir şekilde iletişim kurmanı sağlar.</p>
        </div>
        <div class="split-right-cards">
            <div class="about-card card-purple">
                <div class="about-card-icon">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                </div>
                <h3>Gerçek<br>Karşılaşmalar</h3>
            </div>
            <div class="about-card card-blue">
                <div class="about-card-icon">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#0877E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                </div>
                <h3>Şehre Özel<br>Keşif</h3>
            </div>
            <div class="about-card card-purple">
                <div class="about-card-icon">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
                </div>
                <h3>Hızlı, Kolay<br>ve Güvenli</h3>
            </div>
        </div>
    </div>
</section>

{{-- 3. NASIL ÇALIŞIR? --}}
<section class="wrap section section-steps" id="nasil-calisir">
    <div class="section-head">
        <span class="kicker">NASIL ÇALIŞIR?</span>
        <h2>Üç adımda, şehirdeki karşılaşmalarını keşfet.</h2>
    </div>
    <div class="steps-flow">
        <div class="step-card">
            <div class="step-left">
                <div class="step-badge">1</div>
                <div class="step-icon">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                </div>
            </div>
            <div class="step-right">
                <h3>Şehrini seç</h3>
                <p>Bulunduğun şehri (ve istersen<br>ilçeni) belirle.</p>
            </div>
        </div>
        <div class="step-arrow-connector" aria-hidden="true">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#98A2B3" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
        </div>
        <div class="step-card">
            <div class="step-left">
                <div class="step-badge">2</div>
                <div class="step-icon">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                </div>
            </div>
            <div class="step-right">
                <h3>Karşılaşmanı paylaş</h3>
                <p>Gördüğün kişiyi, zamanı ve yeri<br>kısaca anlat.</p>
            </div>
        </div>
        <div class="step-arrow-connector" aria-hidden="true">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#98A2B3" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
        </div>
        <div class="step-card">
            <div class="step-left">
                <div class="step-badge">3</div>
                <div class="step-icon">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                </div>
            </div>
            <div class="step-right">
                <h3>Bağlantı kur</h3>
                <p>Aynı kişiyi arayan biriyle eşleş,<br>sohbetini başlat.</p>
            </div>
        </div>
    </div>
</section>

{{-- 4. TÜM ÖZELLİKLER --}}
<section class="surface section-features-wrap" id="ozellikler">
    <div class="wrap section section-features">
        <div class="features-left">
            <span class="kicker">TÜM ÖZELLİKLER</span>
            <h2>SenMiydin ile<br>neler yapabilirsin?</h2>
            <p class="features-sub">Şehirdeki tesadüfleri, yeni tanışmalara<br>ve anlamlı hikâyelere dönüştürmen<br>için ihtiyacın olan tüm özellikler<br>tek uygulamada.</p>
            
            <div class="features-doodle" aria-hidden="true">
                <svg width="60" height="14" viewBox="0 0 60 14" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M2 11C12 3 22 13 32 5C42 1 50 10 58 4" stroke="#A855F7" stroke-width="2.8" stroke-linecap="round"/>
                </svg>
            </div>

            {{-- Phone Mockup from Approved Reference --}}
            <div class="features-mockup-container">
                <img src="{{ asset('web/features-phone-mockup.png') }}" alt="SenMiydin iPhone Önizlemesi" class="features-mockup-img">
            </div>
        </div>

        <div class="features-right-grid">
            <div class="feature-item-card">
                <div class="feature-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg>
                </div>
                <h3>Şehir Bazlı Akış</h3>
                <p>Bulunduğun şehirde paylaşılan<br>tüm karşılaşmaları keşfet.</p>
            </div>
            <div class="feature-item-card">
                <div class="feature-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><path d="M18 8a3 3 0 0 1 0 6"/><path d="M21 5a6 6 0 0 1 0 12"/></svg>
                </div>
                <h3>Yakındaki Kişiler</h3>
                <p>Çevrende aynı anda aktif olan<br>kullanıcılarla tanışma fırsatı yakala.</p>
            </div>
            <div class="feature-item-card">
                <div class="feature-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
                </div>
                <h3>Doğrulanmış Karşılaşmalar</h3>
                <p>Gerçek ve samimi paylaşımlarla<br>daha güvenilir eşleşmeler bul.</p>
            </div>
            <div class="feature-item-card">
                <div class="feature-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"/></svg>
                </div>
                <h3>Yolculuk Paylaşımları</h3>
                <p>Seyahatlerinde (otobüs, tren, uçak<br>vb.) dikkatini çeken kesitleri paylaş.</p>
            </div>
            <div class="feature-item-card">
                <div class="feature-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                </div>
                <h3>Konum Bazlı Keşif</h3>
                <p>Kafe, kampüs, etkinlik, toplu taşıma<br>gibi belirli yerlerdeki karşılaşmaları<br>keşfet.</p>
            </div>
            <div class="feature-item-card">
                <div class="feature-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
                </div>
                <h3>Özel Mesajlaşma</h3>
                <p>Eşleştiğin kişilerle güvenli, özel<br>sohbet başlat ve tanış.</p>
            </div>
            <div class="feature-item-card">
                <div class="feature-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
                </div>
                <h3>Ortak Karşılaşma Hikayeleri</h3>
                <p>Şehirdeki en güzel tesadüfleri,<br>komik veya unutulmaz anları<br>paylaş ve keşfet.</p>
            </div>
            <div class="feature-item-card">
                <div class="feature-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>
                </div>
                <h3>Gizlilik ve Güvenlik Kontrolleri</h3>
                <p>Görünürlüğünü, kimlerle<br>iletişim kurabileceğini ve hesap<br>ayarlarını sen belirle.</p>
            </div>
            <div class="feature-item-card">
                <div class="feature-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg>
                </div>
                <h3>Raporlama ve Engelleme</h3>
                <p>Rahatsız edici davranışları kolayca<br>bildir, istemediğin kullanıcıları<br>engelle.</p>
            </div>
        </div>
    </div>
</section>

{{-- 5. DUAL SHOWCASE (Radar Map & Polaroid Stories) --}}
<section class="wrap section section-dual-showcase">
    <div class="showcase-card-dual radar-card">
        <div class="dual-card-copy">
            <div class="dual-icon-badge icon-badge-blue">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#0877E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>
            </div>
            <h3>Şehrinin<br>karşılaşma haritası</h3>
            <p>Popüler noktalar, aktif paylaşımlar ve yakın çevrendeki karşılaşmaları harita üzerinden keşfet.</p>
        </div>
        <div class="dual-card-graphic radar-graphic-box">
            <img src="{{ asset('web/radar-showcase.png') }}" alt="Kadıköy karşılaşma haritası" class="dual-preview-img">
        </div>
    </div>

    <div class="showcase-card-dual polaroid-card">
        <div class="dual-card-copy">
            <div class="dual-icon-badge icon-badge-purple">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
            </div>
            <h3>Gerçek hikâyeler,<br>gerçek insanlardan</h3>
            <p>Şehirde yaşanan en güzel ve unutulmaz karşılaşma hikâyelerini keşfet, kendi hikâyeni de paylaş.</p>
        </div>
        <div class="dual-card-graphic polaroid-graphic-area">
            <div class="polaroid-wrapper polaroid-one">
                <img src="{{ asset('web/polaroid-kiz-kulesi.jpg') }}" alt="Kız Kulesi gün batımı" class="polaroid-photo">
            </div>
            <div class="polaroid-wrapper polaroid-two">
                <img src="{{ asset('web/polaroid-red-tram.jpg') }}" alt="İstiklal kırmızı tramvay" class="polaroid-photo">
            </div>
            <svg class="floating-purple-heart" width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#A855F7" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>
            <svg class="floating-sparkle" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#A855F7" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/></svg>
        </div>
    </div>
</section>

{{-- 6. GÜVENLİK VE GİZLİLİK --}}
<section class="wrap section section-security" id="guvenlik">
    <div class="security-split">
        <div class="security-left">
            <span class="kicker">GÜVENLİK VE GİZLİLİK</span>
            <h2>Rahat, saygılı ve güvenli<br>bir deneyim.</h2>
            <p>SenMiydin'de topluluk kuralları, gizlilik ayarları ve güçlü güvenlik araçlarıyla her zaman kontrol sende.</p>
            <a href="/guvenlik" class="button button-soft-blue">
                Güvenlik Politikamızı İncele
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
            </a>
        </div>
        <div class="security-right-rows">
            <div class="sec-row-item">
                <div class="sec-row-icon icon-blue">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#0877E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                </div>
                <div class="sec-row-content">
                    <h3>Şeffaflığın Önceliğimiz</h3>
                    <p>Kişisel bilgilerin güvende, profil görünürlüğünü sen kontrol edersin.<span class="sr-only"> Canlı kişi takibi yoktur; diğer kullanıcılar yalnızca yaklaşık mesafeyi görür.</span></p>
                </div>
            </div>
            <div class="sec-row-item">
                <div class="sec-row-icon icon-blue">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#0877E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>
                </div>
                <div class="sec-row-content">
                    <h3>Güvenli Topluluk</h3>
                    <p>Gerçek kişilerle, saygılı ve olumlu bir ortamda tanış.</p>
                </div>
            </div>
            <div class="sec-row-item">
                <div class="sec-row-icon icon-purple">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                </div>
                <div class="sec-row-content">
                    <h3>Raporla ve Engelle</h3>
                    <p>Uygunsuz davranışları bildir, istemediğin kullanıcıları engelle.</p>
                </div>
            </div>
        </div>
    </div>
</section>

{{-- 7. BOTTOM DOWNLOAD CTA BANNER --}}
<section class="section-bottom-cta-wrap" id="indir">
    <div class="wrap bottom-cta-banner">
        <div class="cta-phone-side">
            <div class="cta-phone-decor">
                <span class="cta-rays left-rays" aria-hidden="true">
                    <svg width="28" height="28" viewBox="0 0 28 28" fill="none"><path d="M5 14H1M8 7L4 3M14 5V1" stroke="#A855F7" stroke-width="2.5" stroke-linecap="round"/></svg>
                </span>
                <img src="{{ asset('web/bottom-cta-phone.png') }}" alt="SenMiydin Mobil Uygulama" class="cta-phone-img">
            </div>
        </div>
        <div class="cta-content-side">
            <div class="cta-headline-wrapper">
                <span class="cta-top-burst" aria-hidden="true">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M12 2V6M5 5L8 8M19 5L16 8" stroke="#A855F7" stroke-width="2.5" stroke-linecap="round"/></svg>
                </span>
                <h2>{{ $settings['web_cta'] }}</h2>
            </div>
            <p>Hemen uygulamayı indir, kaçırdığın tanışma fırsatlarını yakala.</p>
            <div class="cta-stores-row">
                @include('website.stores')
            </div>
        </div>
        <div class="cta-skyline-side" aria-hidden="true">
            <img src="{{ asset('web/bottom-cta-skyline.png') }}" alt="" class="cta-skyline-img">
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
