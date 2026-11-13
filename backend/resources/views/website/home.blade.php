@php
$icon = [
    'pin' => '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>',
    'mail' => '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="m3.5 7 8.5 6 8.5-6"/></svg>',
    'check' => '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>',
    'shield' => '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
    'arrow' => '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>',
];
$slides = [
    ['tram', 'İstanbul · İstiklal', 'Kırmızı tramvay durağındaki o an', '“Elinde kahve, kulaklığı boynunda olan; tramvaya birlikte baktığımız sen miydin?”', 'web/hero-istanbul-tram.webp', 1200, 670, 'İstiklal Caddesi’nde kırmızı tramvayın önünde konuşan iki kişi', 'Temsili paylaşım'],
    ['ferry', 'İstanbul · Kadıköy', 'Akşam vapurunda gün batımı', '“Martılara simit atarken göz göze geldiğimiz sen miydin?”', 'web/polaroid-kiz-kulesi.webp', 1024, 1024, 'Gün batımında Kız Kulesi ve Boğaz', 'Temsili paylaşım'],
    ['cafe', 'İstanbul · Moda', 'Köşe masadaki kahve', '“Kitabını kapatıp bana gülümseyen, ikinci kahveyi sipariş eden sen miydin?”', 'web/coffee.webp', 900, 600, 'Bir kafede demlenen filtre kahve', 'Temsili paylaşım'],
    ['note', 'Alanya · Harita notu', 'Haritaya bırakılan dijital mektup', '“Çok güzeldin kırmızı başlıklı kız. Yarın 11:00’de yine burada olacağım.” Bir süre sonra: “Notuna bir cevap geldi.”', null, 0, 0, null, 'Gerçek uygulama ekranı'],
    ['trip', 'Ankara → Eskişehir · Tren', 'Cam kenarında bir yolculuk', '“Seferin ortasında kitabını bana uzatan sen miydin?”', 'web/journey.webp', 1000, 589, 'Raylar boyunca ilerleyen bir tren', 'Temsili paylaşım'],
];
$gallery = [
    ['app-home', 'Ana Sayfa', 'Şehir akışı ve yakındaki insanlar', 540, 1200],
    ['app-notes-letter', 'Harita Notu', 'Anonim bir dijital mektup', 640, 1422],
    ['app-profile', 'Profil', 'Paylaşımların ve karşılaşmaların', 540, 1200],
    ['app-map', 'Harita', 'Yaklaşık yerler, canlı takip yok', 540, 1200],
    ['app-encounter', 'Karşılaşma', 'Kişiyi etiketle, onay iste', 540, 1200],
    ['app-chat', 'Mesajlar', 'İzinli, birebir sohbet', 540, 1200],
];
@endphp

{{-- 1. HERO --}}
<section class="h-hero" aria-labelledby="hero-baslik">
    <div class="wrap h-hero-grid">
        <div class="h-hero-copy">
            <p class="h-eyebrow">{!! $icon['pin'] !!} <span>Şehirdeki küçük tesadüfler için</span></p>
            <h1 id="hero-baslik">Belki de aradığın kişi <span class="h-hl">buradadır.</span></h1>
            <p class="h-lead">Tramvayda göz göze geldin, vapurda yan yana durdun ya da kafede aynı masaya baktın; ama konuşamadın. SenMiydin, o anı aynı şehirde, aynı rotada ve aynı yerde yeniden bulmanın yolunu sunar.<span class="sr-only"> Bazı karşılaşmalar yarım kalmasın.</span></p>

            <div class="h-hero-actions">
                @include('website.stores')
                <a class="h-textlink" href="#harita-notlari">Dijital mektuplara göz at {!! $icon['arrow'] !!}</a>
            </div>

            <ul class="h-trust" aria-label="Kısaca">
                <li><span class="t-blue">{!! $icon['check'] !!}</span> Karşılıklı onay</li>
                <li><span class="t-blue">{!! $icon['shield'] !!}</span> Kesin konum paylaşılmaz</li>
                <li><span class="t-purple">{!! $icon['pin'] !!}</span> Şehrine özel akış</li>
            </ul>
            <a class="sr-only" href="#nasil-calisir">Nasıl çalıştığını keşfet</a>
        </div>

        <div class="hs" data-slider role="region" aria-roledescription="carousel" aria-label="Örnek karşılaşma hikâyeleri">
            <div class="hs-glow" aria-hidden="true"></div>
            <div class="hs-stage">
                @foreach($slides as $i => [$key, $loc, $title, $text, $img, $w, $h, $alt, $badge])
                    <figure class="hs-slide hs-{{ $key }} @if($i === 0) is-active @endif" role="group" aria-roledescription="slide" aria-label="{{ $i + 1 }} / {{ count($slides) }}" @if($i !== 0) aria-hidden="true" @endif>
                        @if($img)
                            <img src="{{ asset($img) }}" alt="{{ $alt }}" width="{{ $w }}" height="{{ $h }}" decoding="async" @if($i === 0) fetchpriority="high" @else loading="lazy" @endif>
                        @else
                            <div class="hs-letter">
                                <img class="hs-letter-card" src="{{ asset('web/screens/story-letter-reply.webp') }}" alt="Uygulamadan gerçek ekran: haritaya bırakılmış bir mektup ve altında anonim bir yanıt" width="900" height="890" loading="lazy" decoding="async">
                                <img class="hs-letter-notice" src="{{ asset('web/screens/story-notification.webp') }}" alt="Uygulamadan gerçek ekran: “Notuna bir cevap geldi.” bildirimi" width="900" height="233" loading="lazy" decoding="async">
                            </div>
                        @endif
                        <figcaption class="hs-caption">
                            <span class="hs-meta">
                                <span class="hs-loc">{!! $icon['pin'] !!} {{ $loc }}</span>
                                <span class="hs-badge">{{ $badge }}</span>
                            </span>
                            <strong>{{ $title }}</strong>
                            <p>{{ $text }}</p>
                        </figcaption>
                    </figure>
                @endforeach
            </div>
            <div class="hs-controls">
                <div class="hs-dots">
                    @foreach($slides as $i => $slide)
                        <button type="button" class="hs-dot @if($i === 0) is-active @endif" data-index="{{ $i }}" aria-label="{{ $i + 1 }}. hikâye: {{ $slide[2] }}" @if($i === 0) aria-current="true" @endif></button>
                    @endforeach
                </div>
                <button type="button" class="hs-pause" data-pause aria-label="Otomatik geçişi duraklat" aria-pressed="false">
                    <svg class="icon-pause" width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/></svg>
                    <svg class="icon-play" width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>
                </button>
            </div>
        </div>
    </div>
</section>

{{-- 2. SENMİYDİN NEDİR? --}}
<section class="h-section h-about" id="nedir" aria-labelledby="nedir-baslik">
    <div class="wrap h-split">
        <div>
            <span class="kicker">SENMİYDİN NEDİR?</span>
            <h2 id="nedir-baslik">Şehrin içindeki küçük tesadüfleri yeniden keşfet.</h2>
            <p class="h-sub">SenMiydin bir flört uygulaması değildir. Gerçek hayatta yolun kesiştiği insanların, anıların ve yarım kalan hikâyelerin şehir bazlı bir araya geldiği sosyal bir deneyimdir. Bir karşılaşma ancak karşı taraf kabul ettiğinde doğrulanır.</p>
        </div>
        <p class="h-triptych" aria-label="Aynı şehir, aynı rota, aynı an">
            <span>Aynı şehir.</span>
            <span class="p">Aynı rota.</span>
            <span>Aynı an.</span>
        </p>
    </div>
</section>

{{-- 3. NASIL ÇALIŞIR? --}}
<section class="h-section h-soft" id="nasil-calisir" aria-labelledby="nasil-baslik">
    <div class="wrap">
        <div class="h-head">
            <span class="kicker">NASIL ÇALIŞIR?</span>
            <h2 id="nasil-baslik">Üç adımda yarım kalan hikâyeye geri dön.</h2>
        </div>
        <ol class="h-steps">
            <li>
                <span class="h-num" aria-hidden="true">1</span>
                <h3>Bir an bırak</h3>
                <p>Anı, karşılaşma, itiraf, düşünce ya da yolculuk. Yaz, istersen on fotoğrafa kadar ekle, istersen anonim kal.</p>
            </li>
            <li>
                <span class="h-num" aria-hidden="true">2</span>
                <h3>Şehrinde keşfet</h3>
                <p>Akışı şehir genelinde gez; haritada yaklaşık bölgelere, insanlara, paylaşımlara ve notlara göz at.</p>
            </li>
            <li>
                <span class="h-num" aria-hidden="true">3</span>
                <h3>Karşılıklı onayla</h3>
                <p>Karşılaştığın kişiyi @kullanıcıadı ile etiketle. Kabul ederse karşılaşma doğrulanır; ortak hikâye için ayrıca yayın onayı gerekir.</p>
            </li>
        </ol>
    </div>
</section>

{{-- 4. ŞEHİR BAZLI SOSYAL KEŞİF --}}
<section class="h-section" id="sehir-akisi" aria-labelledby="sehir-baslik">
    <div class="wrap h-split">
        <div class="h-copy">
            <span class="kicker">ŞEHİR BAZLI SOSYAL KEŞİF</span>
            <h2 id="sehir-baslik">Önce şehrin akışı, sonra yakınlık.</h2>
            <p>SenMiydin yalnızca çevrendeki insanları gösteren bir uygulama değildir. Paylaşımlar varsayılan olarak şehir genelinde keşfedilir; yakınlık, sıralamaya yardım eden bir ipucudur ve paylaşımı küçük bir çembere hapsetmez.</p>
            <ul class="h-chips" aria-label="İçerik türleri">
                <li>Anı</li><li>Karşılaşma</li><li>İtiraf</li><li>Düşünce</li><li>Yolculuk</li>
            </ul>
            <dl class="h-spec">
                <div><dt>Kapsam</dt><dd>Tüm şehir · 5 km · 10 km · 25 km</dd></div>
                <div><dt>Sıralama</dt><dd>Yakın · Yeni · Popüler</dd></div>
                <div><dt>Filtreler</dt><dd>İçerik türü, fotoğraf ve ilgi alanı birlikte kullanılabilir.</dd></div>
            </dl>
        </div>
        <figure class="h-shot h-visual">
            <img src="{{ asset('web/screens/app-home.webp') }}" alt="SenMiydin Ana Sayfa: şehir akışı ve karşılaşma hikâyeleri" loading="lazy" decoding="async" width="540" height="1200">
        </figure>
    </div>
</section>

{{-- 5. KARŞILAŞMALAR --}}
<section class="h-section h-soft" id="karsilasma" aria-labelledby="karsilasma-baslik">
    <div class="wrap h-split rev">
        <figure class="h-shot h-visual">
            <img src="{{ asset('web/screens/app-encounter.webp') }}" alt="SenMiydin karşılaşma paylaşımı: kişiyi @kullanıcıadı ile etiketleme" loading="lazy" decoding="async" width="540" height="1200">
        </figure>
        <div class="h-copy">
            <span class="kicker">KARŞILAŞMALAR</span>
            <h2 id="karsilasma-baslik">Doğrulanmış karşılaşma iki tarafın kararıdır.</h2>
            <ol class="h-list-num">
                <li><strong>Etiketle.</strong> Karşılaştığın kişiyi @kullanıcıadı ile bulursun.</li>
                <li><strong>Karar versin.</strong> Karşı taraf isteği kabul eder ya da reddeder. Bekleyen isteği sen de geri çekebilirsin.</li>
                <li><strong>Hikâyeni yayınla.</strong> Kabulden sonra ortak hikâye oluşturabilirsiniz; diğer taraf onay vermeden yayınlanmaz.</li>
            </ol>
            <p class="h-note">Karşılaşma, belirli bir kişiyi bulmak ve onaylamaktır. Bir mekâna bırakılan açık mektup ise bundan ayrı bir özelliktir: aşağıdaki Harita Notları.</p>
        </div>
    </div>
</section>

{{-- 6. HARİTA --}}
<section class="h-section" id="harita" aria-labelledby="harita-baslik">
    <div class="wrap h-split">
        <div class="h-copy">
            <span class="kicker">HARİTA</span>
            <h2 id="harita-baslik">Haritada izleri gör, kendini sen göster.</h2>
            <p>Harita üç görünüm sunar: İnsanlar, Paylaşımlar ve Notlar. İnsanlar listesinde yalnızca “yakınımda görünür” seçeneğini kendisi açan kişiler yer alır; ayarı kapattığında listeden gerçekten çıkarsın.</p>
            <ul class="h-checks">
                <li>Yalnızca yaklaşık konum gösterilir; kesin GPS ve açık adres paylaşılmaz.</li>
                <li>Gerçek zamanlı rota gösterilmez. Canlı kişi takibi yoktur.</li>
                <li>Konum izni vermezsen şehri elle seçip uygulamayı kullanmayı sürdürebilirsin.</li>
            </ul>
        </div>
        <figure class="h-shot h-visual">
            <img src="{{ asset('web/screens/app-map.webp') }}" alt="SenMiydin harita: yakındaki yaklaşık paylaşımlar" loading="lazy" decoding="async" width="540" height="1200">
        </figure>
    </div>
</section>

{{-- 7. HARİTA NOTLARI / DİJİTAL MEKTUPLAR --}}
<section class="h-notes" id="harita-notlari" aria-labelledby="notlar-baslik">
    <div class="wrap">
        <div class="h-notes-top">
            <div class="h-copy">
                <span class="kicker">HARİTA NOTLARI · DİJİTAL MEKTUPLAR</span>
                <h2 id="notlar-baslik">Birini bulamadıysan, geçtiğiniz yere bir not bırak.</h2>
                <p class="h-sub">Haritada yaklaşık bir noktaya 7 gün kalan dijital bir mektup bırak. İstersen açık, istersen anonim. Belki aradığın kişi notunu görür ve sana cevap verir.</p>
                <ul class="h-facts" aria-label="Harita notları nasıl çalışır">
                    <li>{!! $icon['mail'] !!} 7 gün haritada kalır</li>
                    <li>Açık ya da anonim</li>
                    <li>Cevaplanabilir</li>
                    <li>Yaklaşık nokta</li>
                </ul>
                <p class="h-note">Harita notu, @kullanıcıadı ile onaylanan karşılaşmadan ayrıdır: bir mekâna bırakılmış, herkesin okuyabildiği açık bir mektuptur.</p>
            </div>
            <figure class="h-shot h-visual h-notes-hero">
                <img src="{{ asset('web/screens/app-notes-map.webp') }}" alt="SenMiydin Harita Notları: haritada mor zarf işaretleri; üç notun biri iki mektup içeriyor" loading="lazy" decoding="async" width="640" height="1422">
            </figure>
        </div>

        <div class="h-head h-head-left">
            <h3 class="h-h3-big">Bir mektubun üç anı</h3>
        </div>
        <ol class="h-note-steps" role="list" tabindex="0" aria-label="Harita notu adımları: kaydırarak gez">
            <li>
                <figure class="h-shot"><img src="{{ asset('web/screens/app-notes-compose.webp') }}" alt="Not bırakma ekranı: metin alanı, açık ya da anonim seçimi ve haritada seçilen yaklaşık nokta" loading="lazy" decoding="async" width="640" height="1422"></figure>
                <span class="h-badge" aria-hidden="true">1</span>
                <h3>Bir noktaya mektup bırak.</h3>
                <p>Notunu yaz, açık ya da anonim seç ve haritada yaklaşık yeri işaretle. Not 7 gün boyunca haritada kalır.</p>
            </li>
            <li>
                <figure class="h-shot"><img src="{{ asset('web/screens/app-notes-list.webp') }}" alt="Bir noktaya bırakılan notlar: biri anonim, biri açık iki mektup" loading="lazy" decoding="async" width="640" height="1422"></figure>
                <span class="h-badge" aria-hidden="true">2</span>
                <h3>O bölgedeki insanlar notu keşfetsin.</h3>
                <p>Aynı noktadaki notlar tek işaret altında toplanır. Şehirdeki herkes Notlar görünümünden okuyabilir.</p>
            </li>
            <li>
                <figure class="h-shot"><img src="{{ asset('web/screens/app-notes-replies.webp') }}" alt="Bir harita notu ve altında anonim bir yanıt" loading="lazy" decoding="async" width="640" height="1422"></figure>
                <span class="h-badge" aria-hidden="true">3</span>
                <h3>Belki o kişi cevap versin.</h3>
                <p>Yanıtlar notun altında görünür; yanıtlayan da açık ya da anonim olabilir. Not sahibi bildirim alır.</p>
            </li>
        </ol>
    </div>
</section>

{{-- 8. GEÇTİĞİM YERLER --}}
<section class="h-section" id="gectigim-yerler" aria-labelledby="yerler-baslik">
    <div class="wrap h-split">
        <div class="h-copy">
            <span class="kicker">GEÇTİĞİM YERLER</span>
            <h2 id="yerler-baslik">Geçtiğin yerler, yalnızca sen istersen.</h2>
            <p>Geçtiğim Yerler isteğe bağlı bir özelliktir. Açarsan, yolunun geçtiği yaklaşık bölgeler kısa bir süre saklanır; aynı yerde ve zamanda bulunan biri varsa yalnızca bir keşif önerisi çıkabilir. Öneri tahmindir; kendiliğinden bir karşılaşma oluşturmaz.</p>
            <p class="h-note">Kapattığında örnek toplama durur; kendi geçmiş kayıtların ve bu kayıtlardan çıkan öneriler temizlenir.</p>
        </div>
        <dl class="h-facts-big">
            <div><dt>Varsayılan</dt><dd>Kapalı</dd></div>
            <div><dt>Konum</dt><dd>Yaklaşık bölgeler</dd></div>
            <div><dt>Saklama</dt><dd>En fazla 7 gün</dd></div>
            <div><dt>Kesin rota takibi</dt><dd>Yok</dd></div>
        </dl>
    </div>
</section>

{{-- 9. YOLCULUK --}}
<section class="h-section h-soft" id="yolculuk" aria-labelledby="yolculuk-baslik">
    <div class="wrap h-split">
        <div class="h-copy">
            <span class="kicker">Yolculuk Paylaşımları</span>
            <h2 id="yolculuk-baslik">Yolda yarım kalan bir an için doğru ayrıntılar.</h2>
            <p>Yolculuk paylaşımına güzergâhı ve yaklaşık zamanı ekleyebilirsin. Aynı güzergâh ve zaman aralığı yalnızca bir keşif ipucudur; sistem aynı araçta bulunduğunuzu bilmez.</p>
            <ul class="h-chips" aria-label="Ulaşım türleri">
                <li>Otobüs</li><li>Tren</li><li>Uçak</li><li>Feribot</li><li>Diğer</li>
            </ul>
            <dl class="h-spec">
                <div><dt>Güzergâh</dt><dd>Kalkış ve varış şehri, yaklaşık saat</dd></div>
                <div><dt>Ayrıntılar</dt><dd>Firma, sefer kodu ve isteğe bağlı araç kimliği; herkese açık veya özel</dd></div>
                <div><dt>Örnek</dt><dd>Pamukkale · Ankara → Erzincan · 07 NM 365</dd></div>
            </dl>
            <p class="h-note">Yolculuk grubu, oda veya katılım butonu yoktur; kimsenin aynı araçta bulunduğu iddia edilmez.</p>
        </div>
        <figure class="h-shot h-visual">
            <img src="{{ asset('web/screens/app-journey.webp') }}" alt="SenMiydin yolculuk paylaşımı: güzergâh ve zaman ayrıntıları" loading="lazy" decoding="async" width="540" height="1200">
        </figure>
    </div>
</section>

{{-- 10. MESAJLAŞMA --}}
<section class="h-section" id="mesajlasma" aria-labelledby="mesaj-baslik">
    <div class="wrap h-split rev">
        <figure class="h-shot h-visual">
            <img src="{{ asset('web/screens/app-chat.webp') }}" alt="SenMiydin birebir mesajlaşma: mesaj isteği ve fotoğraf mesajı" loading="lazy" decoding="async" width="540" height="1200">
        </figure>
        <div class="h-copy">
            <span class="kicker">MESAJLAŞMA</span>
            <h2 id="mesaj-baslik">Birebir ve izinli mesajlaşma.</h2>
            <p>İlk mesaj bir istektir; alıcı kabul ettiğinde sohbet devam eder. Karşılaşma onaylandıktan sonra da iletişim aynı izinli sohbet üzerinden sürer.</p>
            <ul class="h-checks">
                <li>Mesaj isteğini kabul etme veya reddetme</li>
                <li>Fotoğraf mesajı, okundu bilgisi ve okunmamış sayacı</li>
                <li>Sohbeti gizleme, kullanıcıyı engelleme ve şikâyet etme</li>
            </ul>
            <p class="h-note">Grup sohbeti ve arama yoktur; SenMiydin sade, birebir mesajlaşmaya odaklanır.</p>
        </div>
    </div>
</section>

{{-- 11. GİZLİLİK VE GÜVENLİK --}}
<section class="h-section h-privacy" id="guvenlik" aria-labelledby="guvenlik-baslik">
    <div class="wrap">
        <div class="h-head h-head-left">
            <span class="kicker">GİZLİLİK VE GÜVENLİK</span>
            <h2 id="guvenlik-baslik">Rahat, saygılı ve güvenli bir deneyim.</h2>
            <p class="h-sub">Konumun, görünürlüğün ve iletişimin üzerinde kontrol sende kalır.</p>
        </div>
        <ul class="h-safe">
            <li><h3>Yaklaşık konum</h3><p>Diğer kullanıcılar yalnızca yaklaşık mesafe ve bölge görür; kesin GPS gösterilmez.</p></li>
            <li><h3>Anonim paylaşım</h3><p>Paylaşımlarda ve harita notlarında adın ve profilin görünmez.</p></li>
            <li><h3>Engelle ve şikâyet et</h3><p>İstemediğin kişiyi engelle, uygunsuz içeriği ve davranışı bildir.</p></li>
            <li><h3>Moderasyon</h3><p>Şikâyetler incelenir; uygunsuz içerikler kaldırılabilir.</p></li>
            <li><h3>Konum tercihleri</h3><p>“Yakınımda görün”, Geçtiğim Yerler ve bildirimler ayrı ayrı açılıp kapanır.</p></li>
            <li><h3>Hesap silme</h3><p>Hesabını uygulamadan ya da web’deki Hesap Silme sayfasından talep ederek kapatabilirsin.</p></li>
        </ul>
        <div class="h-links">
            <a href="/guvenlik" class="button button-soft-blue">Güvenlik sayfasını incele {!! $icon['arrow'] !!}</a>
            <a href="/hesap-silme" class="h-textlink">Hesap silme talebi</a>
        </div>
        <p class="sr-only">Geçtiğim Yerler varsayılan olarak kapalıdır. Canlı kişi takibi yoktur; diğer kullanıcılar yalnızca yaklaşık mesafeyi görür.</p>
    </div>
</section>

{{-- 12. GERÇEK MOBİL EKRANLAR --}}
<section class="h-section h-soft" id="ekranlar" aria-labelledby="ekranlar-baslik">
    <div class="wrap">
        <div class="h-head h-head-left">
            <span class="kicker">GERÇEK EKRANLAR</span>
            <h2 id="ekranlar-baslik">Uygulamadan gerçek görüntüler</h2>
            <p class="h-sub">Aşağıdaki ekranlar, uygulamanın Android sürümünden alınmış gerçek ekran görüntüleridir.</p>
        </div>
        <ul class="h-gallery" role="list" tabindex="0" aria-label="Uygulama ekranları: kaydırarak gez">
            @foreach($gallery as [$file, $label, $caption, $w, $h])
                <li>
                    <figure class="h-shot"><img src="{{ asset('web/screens/'.$file.'.webp') }}" alt="SenMiydin {{ $label }} ekranı" loading="lazy" decoding="async" width="{{ $w }}" height="{{ $h }}"><figcaption><strong>{{ $label }}</strong><span>{{ $caption }}</span></figcaption></figure>
                </li>
            @endforeach
        </ul>
    </div>
</section>

{{-- 13. FİNAL CTA --}}
<section class="h-cta" id="indir" aria-labelledby="indir-baslik">
    <div class="wrap h-cta-inner">
        <div>
            <h2 id="indir-baslik">{{ $settings['web_cta'] }}</h2>
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
