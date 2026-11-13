# Doğrulama

> **Güncel kaynak bu dosyanın ilk bölümüdür (14 Kasım 2026, sosyal derinlik).** Altındaki bölümler önceki turların tarihsel kayıtlarıdır; oradaki sayılar güncel durum değildir.

## Sosyal derinlik: Takip, yorum yanıtları, Mektuplarım, yakındaki yeni mektuplar — 14 Kasım 2026 (en güncel)

Başlangıç `135987f` (gerçekten çalıştırıldı): Laravel 146 test / 2375 assertion, Flutter 125, analyze temiz.

| Kontrol | Final |
|---|---|
| Laravel `php artisan test` | **162 test / 2627 assertion geçti** (+16 `SocialEngagementTest`, 1 `MapNotesTest` saklama testi güncellendi) |
| `flutter analyze` | **No issues found** |
| Flutter `flutter test` | **142 test geçti** (+17 `test/social_engagement_test.dart`) |
| Pixel 6a entegrasyon | **9/9 geçti**, `clean=true` |
| Pixel 6a location-time | **3/3 geçti** |

**Gerçek Pixel 6a E2E (arayüz üzerinden, ASCII metinle — adb Türkçe karakter yazamaz):**

- *Takip:* Demo'nun takip ettiği Elif'in normal paylaşımı Takip sekmesinde göründü (`following-feed.png`); profilden "Takip Ediliyor" ile takipten çıkınca Takip sekmesi "Henüz kimseyi takip etmiyorsun." + "İnsanları Keşfet" oldu (`following-feed-empty.png`).
- *Yorum yanıtı:* Demo'nun yazısına Elif ana yorum yazdı → Demo bildirimden yorum sayfasını açtı → **Yanıtla** ile composer `@elifdemo ` ile başladı, "Yanıtlanıyor" şeridi → gönderildi, yanıt ana yorumun altında girintili (`comment-replies.png`). Elif için `comment_reply` bildirimi oluştu ("Yorumuna bir cevap geldi.", hedef yazı, gönderen kimliği API'de yok).
- *Mektuplarım:* Demo not bıraktı → drawer'da tek satır "Mektuplarım" (`my-letters-drawer.png`) → Aktif ("6 gün kaldı", `my-letters-active.png`) → **Haritadan Kaldır** (onay penceresi) → Arşiv'de "Haritadan kaldırıldı" ve mektubun gerçek tarihi (`my-letters-archive.png`) → **Tekrar Paylaş**: yeni satırın `created_at` / `expires_at` = şimdi + 7 gün, `occurred_at` ilk mektubun tarihi aynen kaldı ("Tekrar paylaşıldı"), eski satır arşivde; haritada yeniden göründü. Test için ilk mektubun tarihi 20 gün geriye alındı (7 günü gerçekten beklemek yerine); sonuç DB satırlarıyla doğrulandı.
- *Yakındaki yeni mektup:* Elif yakına not bıraktı → Demo Ana Sayfa'da küçük "Yakınında 1 yeni mektup var · Haritada keşfet" (`nearby-new-letters-home.png`) → karta dokununca Harita **Notlar** modunda açıldı, sekmede "1 yeni" rozeti → Elif'in notunun detayı açılınca sayı 0'a düştü, kart ve rozet kayboldu (`map_note_reads` yalnız Demo'ya ait tek satır). Harita işareti yalnız görününce sayı düşmedi.
- Test verisi (not, yanıt, yorum, takip, sohbet, konum, bildirim) sonunda temizlendi; uygulama normal debug sürümüyle Demo girişli açık bırakıldı.

**Bulunan ve düzeltilen gerçek hatalar:** (1) `purgeExpired` 30. günde süresi dolmuş mektubu fiziksel siliyordu — Mektuplarım arşiviyle çelişiyordu; artık yalnız kalıcı silinmiş / moderasyonla kaldırılmış satırlar temizlenir. (2) Kendi mektuplarım listesinde açık notun yazar kimliği gizleniyordu; artık "başkaları nasıl görüyorsa" gösterilir (anonimde yok). (3) Ana Sayfa kartı gereksiz yere cihaz konum senkronuna bağlıydı; karar sunucunun yakın zamanlı konumuna bırakıldı. (4) Yorum sayısı yetim yanıtları sayıyordu; yetim yanıt artık hiçbir yerde görünmez ve sayılmaz.

**Sınırlar:** harita işaretinin okundu sayılmadığı davranışı sunucu + widget testiyle ve Pixel'da elle doğrulandı. 7 günlük süre gerçek 7 gün beklenerek değil test saatiyle ve tarih geri alınarak doğrulandı. Güvenli 16+ (teen) modeli uygulanmadı, yalnız belgelendi (`docs/AGE_AND_STORE_READINESS.md`); üretim minimum yaşı 18.

---

## Public web final adayı — 14 Kasım 2026 (önceki tur)

Başlangıç `a866be9`: Laravel 142 test / 2098 assertion, Flutter 125, analyze temiz, Pixel 9/9, location-time 3/3. Mobil uygulama ve backend sosyal özellikleri değişmedi; yalnız `website/*` Blade, `public/web/*` varlıkları, `WebsiteTest` ve belgeler.

| Kontrol | Sonuç |
|---|---|
| Laravel `php artisan test` | **146 test / 2375 assertion geçti** (başlangıç 142 / 2098; +4 web testi) |
| `WebsiteTest` | 9 test (5 mevcut, 4 yeni): Harita Notları bölümü + 7 gün doğruluğu, anonim / cevap anlatımı, flört / sahte kanıt yok, başlık hiyerarşisi + tek H1, alt metinler, kırık görsel / ölü bağlantı yok, SEO + footer + gizli veri sızıntısı yok |
| `flutter analyze` / `flutter test` | Flutter kodu değişmedi: analyze temiz, 125 test geçti; Pixel entegrasyon 9/9, location-time 3/3 (yeniden doğrulandı) |
| Tarayıcı (Playwright) 1920 / 1440 / 1200 / 1024 / 768 / 430 / 390 / 360 | yatay taşma **0**, konsol hatası **0**, kırık görsel **0**, kırık iç bağlantı **0**, başlık taşması yok |
| Mobil menü | açılır, Esc ve dışarı tıklama kapatır, bağlantı seçince kapanır, "Uygulamayı Keşfet" menüde |

**Kapsam.** Ana sayfa yeniden kurgulandı (hikâye akışı, iki kolonlu hero, 5 hikâyeli klavye kullanılabilir slider, 4. hikâye gerçek Harita Notu ekranları: mektup + "Notuna bir cevap geldi." bildirimi + anonim yanıt "O kişi bendim :)"). Harita Notları ayrı büyük bölüm: 7 gün, açık / anonim, cevap, yaklaşık nokta; üç adım gerçek Pixel 6a ekranlarıyla (mektup bırak → noktadaki notlar → cevap). Geçtiğim Yerler (opt-in, varsayılan kapalı, yaklaşık bölge, 7 gün, kesin rota takibi yok), Yolculuk (sistem aynı araçta olduğunuzu bilmez), Mesajlaşma (grup sohbeti ve arama yok), Gizlilik ve Güvenlik (yaklaşık konum, anonim paylaşım, engel, şikâyet, moderasyon, konum tercihleri, hesap silme; doğrulanamayan güvenlik iddiası yok). Header en dar 901–1100 px aralığında sıkışmaz; 900 px ve altında hamburger. Footer'a KVKK ve Harita Notları bağlantısı eklendi. Yasal sayfalar, iletişim formu (hız sınırı, honeypot, kuyruk) ve hesap silme davranışı değişmedi.

**Performans / erişilebilirlik.** Hero görseli `preload` + `fetchpriority=high`, diğer görseller `loading=lazy`, tüm görsellerde boyut ve alt metin; fotoğraflar ve ekran görüntüleri WebP (ör. hero 858 KB JPG → 95 KB WebP). Tek H1, bölümler `aria-labelledby`, atla bağlantısı, odak halkaları, `prefers-reduced-motion`; kaydırmalı şeritler (`tabindex=0`, etiketli).

**Gerçek ekranlar.** Harita Notları ekranları, local API'ye tohumlanmış hikâye metinleriyle (not, anonim not, anonim yanıt, sohbet) Pixel 6a'da alındı; ekranlar gerçek uygulama çıktısıdır, çizim değildir. Android `adb input` Türkçe karakter yazamadığı için metinler API ile tohumlandı ve yalnız görüntülendi. Test verisi sonunda temizlendi.

Ekran görüntüleri: `docs/screenshots/web-final-v2/`.

---

## Harita notu yerleştirme düzeltmesi + arayüz E2E + harita düzeni — 14 Kasım 2026 (önceki tur)

Başlangıç `a9320b5`: Laravel 139 test / 1919 assertion, Flutter 112, analyze temiz, Pixel 9/9, location-time 3/3.

| Kontrol | Final |
|---|---|
| Laravel `php artisan test` | **142 test / 2098 assertion geçti** (+3 yerleştirme testi) |
| `flutter analyze` | **No issues found** |
| Flutter `flutter test` | **125 test geçti** (+2 yerleştirme / kamera, +11 harita düzeni ve atıf) |
| Pixel 6a entegrasyon | **9/9 geçti**, `clean=true` |
| Pixel 6a location-time | **3/3 geçti** |

**Kök neden.** Not konumu `location.post_grid` (0,005° ≈ 555 m K-G, ≈ 445 m D-B) ızgarasına yuvarlanıyordu: seçilen nokta 357 m'ye kadar kayabiliyordu. Gerçek cihaz örneği: gönderilen `36.43840723535241 / 32.206634040900184` → saklanan ve dönen `36.44 / 32.205` (≈ 229 m). Ana harita kamerası eski yerinde kaldığı için işaret görünür alanın kenarına düşüyordu ve görsel seçici gerçek merkezden kaymıştı. Ayrıca yükleme sırasında harita yeniden kurulabiliyor ve geç gelen eski yanıt yeni işareti silebiliyordu (bu kısım gerçek cihazda yeniden üretilemedi; kod yolu analiz edilip düzeltildi, widget testiyle kapsandı).

**Düzeltme.** Notlara özel ızgara `config/map_notes.php` → `location_grid` = **0,0005°** (≈ 55 m K-G, ≈ 45 m D-B, seçime en fazla ≈ 36 m); normal paylaşımlar `post_grid` ile aynen kalır. Eski kaba ızgara notları geçerli nokta olarak çalışır; aynı ızgara noktası = tek işaret + sayaç. Haversine testi: seçilen nokta ile saklanan nokta arasındaki fark ≤ 37 m, ham koordinat yanıtta ve veritabanında yok. Konum seçicide merkez nokta kaydedilen koordinatın kendisidir (zarf noktanın üstünde). Oluşturma yanıtı esastır: compose sayfası oluşturulan `MapNoteItem`'ı `Navigator.pop` ile döndürür, ana harita notlar modunda kalır, kamerayı sunucu koordinatına taşır (zoom ≥ 14), `mapNotesChanged()` çağrılır, yeni işaret ≈ 2 sn halelenir. Yükleme belirteci (token) eski yanıtların yeni durumu ezmesini önler.

**Gerçek Pixel 6a ölçümü.** Gönderilen (36.43840723535241, 32.206634040900184) eski ızgarada 36.44/32.205'e gidiyordu. Düzeltmeden sonra seçilen nokta DB'de ve yanıtta (36.4465, 32.1695) ince ızgarada saklandı; uygulama anında yeni işarete, zoom ≈ 14, halo ve "Notun haritaya bırakıldı." mesajıyla döndü; işarete dokununca "Bu noktaya bırakılan notlar" listesinde yeni not göründü. Yanlış şehirdeki seçim kullanıcı dilinde reddedildi. `docs/screenshots/ui-audit/map-note-location-selected.png`.

**Arayüzden arayüze yanıt E2E (API ile yanıt oluşturulmadı).** Demo UI'dan açık not bıraktı → çıkış → Elif UI'dan giriş → Harita → Notlar → işaret → nota dokun → "Anonim yanıt" seçip yanıt yazdı ve gönderdi → çıkış → Demo UI'dan giriş → Bildirimler → "Notuna bir cevap geldi." → dokununca not detayı, yanıt "Anonim" olarak görünüyor (ad / kullanıcı adı yok). `map-note-replies.png`. adb `input text` Türkçe karakter yazamadığı için metinler ASCII; bu bir uygulama hatası değildir.

**Admin tarayıcı E2E** (gerçek panel, tek kullanımlık notlar): liste açık ve anonim notu gösterir (anonimde gerçek sahip yönetici görünümünde: Elif B. @elifdemo · "Kullanıcılara ANONİM görünür"), detayda yanıtlar ve yazarları, "Notu haritadan kaldır" → durum Kaldırıldı + moderasyon geçmişi, "Geri aç" → Aktif, yanıt kaldırma, `/admin/audit` içinde "Harita notu · kaldırıldı" ve "geri açıldı" kayıtları. Test verisi sonunda temizlendi. Admin tasarımı değiştirilmedi.

**Harita düzeni (yalnız layout).** "Buraya Not Bırak", sağ alttaki konum butonu ve `© OpenStreetMap contributors` kutusu birbirine çok yakındı. Ortak `MapAttribution` bileşeni: haritanın sol üstünde küçük, yarı saydam beyaz hap (10 px, lacivert/muted), görünür metin `© OpenStreetMap`, telif URL'sine tıklanabilir (`MAP_ATTRIBUTION_URL`), erişilebilirlik etiketi tam sağlayıcı adı. Uygulamadaki tüm OSM haritaları (ana harita – İnsanlar / Paylaşımlar / Notlar, yaklaşık yer seçimi, not yerleştirme) aynı bileşeni kullanır; not yerleştirme haritasında atıf daha önce hiç yoktu, eklendi. Alt alan artık CTA (sol) ve konum butonu (sağ) tek satırda, aralarında 12 px boşlukla. Üstteki katmanlar (boş durum, hata, İnsanlar şeridi) atfı örtmemesi için 30 px aşağıdan başlar. 320 dp'de üç sekme (İnsanlar / Paylaşımlar / Notlar) kesilmek yerine hafifçe küçülür (`FittedBox`, daha önce taşıyordu). Widget testleri 320 / 360 / 390 / 430 px (dolu ve boş), 320 px + 1,5× yazı, atıf tıklanabilirliği ve not yerleştirme haritası. Pixel 6a: `map-attribution-layout-411dp.png`, `map-attribution-layout-320dp.png` (`wm size 840x1866`, sonra sıfırlandı).

Sınırlar: 7 günlük süre gerçek 7 gün beklenerek değil test saatiyle doğrulandı. Harita yeniden kurulma yarışı gerçek cihazda yeniden üretilemedi; kod + widget testi ile kapsandı.

---

## Harita Notları / Dijital Mektuplar — 14 Kasım 2026 (önceki tur)

Başlangıç `dfa95a1`: Laravel 117 test / 1545 assertion, Flutter 99, analyze temiz, Pixel 9/9, location-time 3/3 (doğrulandı).

| Kontrol | Final |
|---|---|
| Laravel `php artisan test` | **139 test / 1919 assertion geçti** (+22: 20 `MapNotesTest`, 2 matcher anahtarı testi) |
| `flutter analyze` | **No issues found** |
| Flutter `flutter test` | **112 test geçti** (+13 `test/map_notes_test.dart`) |
| Pixel 6a entegrasyon | **9/9 geçti**, `clean=true` |
| Pixel 6a location-time | **3/3 geçti** |
| Harita Notları Pixel E2E | Aşağıda (elle, gerçek cihaz + local API) |

**Pixel 6a Harita Notları E2E** (Pixel_6a, normal debug uygulama, `http://127.0.0.1:8000`, Demo + Elif): Harita → Notlar sekmesi (zarf ikonlu, marka moru) → "Buraya Not Bırak" → haritada yaklaşık yer → açık not + aynı noktaya ikinci **anonim** not → işaret üzerinde **2** rozeti → işarete dokununca "Bu noktaya bırakılan notlar" (yeni not üstte, anonim kart "Anonim") → Elif (API) nota **açık yanıt** + **anonim yanıt** → Demo'da "Notuna bir cevap geldi." bildirimi → not detayında yanıtlar eskiden yeniye, anonim yanıtta ad / kullanıcı adı yok → ikinci hesap çağrısıyla JSON'da `elifdemo` yok → "Notu Sil" onayı → işaret sayısı düştü → eski bildirime dokununca güvenli "Bu not artık kullanılamıyor." ekranı. Test verisi (notlar, yanıtlar, bildirimler) sonunda temizlendi.

Sınırlar: Elif'in yanıtları, ikinci cihaz / emülatör kullanılmadığı için API üzerinden gönderildi (aynı hesap kimlik doğrulamasıyla, uygulama arayüzünden değil). 7 günlük süre gerçek 7 gün beklenerek değil, test saatiyle (6 gün 23:59 görünür, 7 gün sonrası gizli) doğrulandı. Admin paneli akışı tarayıcıda değil, backend testleriyle doğrulandı. adb `input text` Türkçe "ı" harfini yazamadığı için cihazdaki not metinleri ASCII yazıldı.

Bu turda bulunan ve düzeltilen iç problemler: `encounter_suggestions` ve `city_discovery` kaydediliyor ama gerçek eşleştirici davranışında kullanılmıyordu (şimdi kapalıyken otomatik öneri üretilmiyor; manuel encounter, Harita ve Nearby etkilenmiyor). Mevcut Pixel fixture ve test kullanıcıları bu iki tercihi açıkça açık oluşturacak şekilde güncellendi. Ayrıca APK paketlemesindeki bayat `kernel_blob.bin` çakışması `flutter clean` / çıktı klasörü silme ile giderildi (kod değişikliği gerekmedi).

---

## Release candidate sertleştirme — 13 Kasım 2026 (2. tur)

Başlangıç `23125a5` (109 test / 1405 assertion, Flutter 98, analyze temiz, Pixel 9/9, location-time 3/3 doğrulandı). Yeni özellik eklenmedi; yalnız gerçek cihaz / güvenlik denetiminde bulunan iç sorunlar düzeltildi.

| Kontrol | Final |
|---|---|
| Laravel | **117 test / 1545 assertion geçti** (`release_check` içinde `composer test`) |
| Flutter | **99 test geçti**; `flutter analyze`: No issues found |
| Pixel 6a entegrasyon | **9/9 geçti**, fixture temizliği `clean=true` |
| Pixel 6a location-time | **3/3 geçti** |
| `tool/release_check.ps1` | Teknik adımların hepsi OK (analyze, testler, composer, migration, paket kimlikleri, seeder koruması, secret taraması). `MISSING` olanlar yalnız dış bağımlılık / production yapılandırması: Android signing, SMTP, FCM, Google/Apple OAuth, APP_URL HTTPS, mağaza URL'leri, operatör/legal, production yönetici |

Bulunan ve düzeltilen gerçek problemler:

1. **Pixel fixture otomasyonu** — `demo_ahmet`'in `user_locations.city_id` değeri NULL kalabiliyor ve yakınındakiler testi elle DB düzeltmesi gerektiriyordu. Kök neden: `demo:refresh-locations` yalnız zaman damgasını yeniliyordu, koordinat/şehri geri yazmıyordu. `DemoDataSeeder::restoreLocations()` artık her tohum hesabın koordinat ve açık şehrini deterministik yazıyor; seeder ve komut ortak kullanıyor (`DemoFixtureTest`). Regresyon elle müdahalesiz geçti.
2. **Onboarding metni** — "İlgi alanların profilinde görünsün" final kararla (public profilde hobi yok) çelişiyordu; metin düzeltildi.
3. **Profil hata durumu** — sunucu kapalıyken Profil sekmesi düz mavi metin gösteriyordu; mevcut `InlineState` + "Tekrar Dene" kartına geçti ve uygulama yeniden başlatılmadan toparlanıyor (`profile_refresh_test`).
4. **`PushDelivery` log sürücüsü** production'da bildirim kimliklerini loga yazabiliyordu; production'da yazmıyor (`DeliveryReadinessTest`).
5. **`tool/release_common.ps1`** — Windows PowerShell 5.1'de Composer'ın stderr satırı yönlendirilmiş komutu sahte "FAIL" yapıyordu. Yalnız çıkış kodu belirleyici oldu; teknik hata ile dış bekleme ayrımı doğru raporlanıyor.
6. **Eksik regresyon testleri**: kapak güvenliği (`CoverSecurityTest`: sahte uzantı, MIME uyuşmazlığı, SVG, bozuk görüntü, boyut/8 MB, EXIF GPS, dosya adı sızıntısı, eski kapak silme, hesap silmede temizlik, askıya alınmış/yasaklı hesap, traversal) ve block'un bildirim / sohbet / okunmamış sayaç filtrelemesi + unblock.

Gerçek Pixel 6a senaryoları (normal debug uygulama, local API): clean install (Splash → onboarding → kayıt → profil → ilgi alanları → izin açıklamaları → Ana Sayfa); konum izni DENY ile uygulama kullanılabilir, manuel şehir Alanya, akış görünür, anonim gönderi yayımlandı, izin döngüsü yok; bildirim izni reddi ile uygulama içi bildirim merkezi çalışıyor; Geçtiğim Yerler varsayılan KAPALI, açınca örnek yazıldı, uygulama arka plana alınınca location foreground service (tip 0x8) sürdü ve yeni örnek geldi, kapatınca geçmiş ve eşleşmeler silindi, servis durdu, yeni örnek gelmedi; process kill sonrası token geri yüklendi ve Ana Sayfa açıldı; duyuru admin panelinden oluşturuldu → Bildirimler'de göründü → dokununca duyuru ayrıntısı → pasifleştirince "Bu içerik artık kullanılamıyor"; minimum sürüm: admin formu resmî mağaza bağlantısı olmadan minimum sürümü reddediyor ("Minimum sürüm için resmî mağaza bağlantısı gerekli"); doğrulamayı atlayıp değer doğrudan yazıldığında uygulama kırık bağlantı açmamak için kapıyı kurmadı ve Ana Sayfa'ya devam etti — sahte mağaza bağlantısı üretilmediğinden gerçek cihazda "Güncelleme gerekli" ekranı gösterilemedi (EXTERNAL: gerçek Play adresi); kapı mantığı mevcut `production_test.dart` widget testiyle doğrulanır, değer geri alındı; API durdurulunca Ana Sayfa / Mesajlar / Bildirimler "İçerik yüklenemedi · Tekrar Dene" gösterdi, API açılınca yeniden başlatmadan toparlandı; polling ölçümü (API günlüğü): açık sohbette ~4,5 sn (7 istek / 32 sn, yalnız sohbet uçları), kök sayaçlar ~8 sn (4 istek / 32 sn), arka planda 0 istek, ön plana dönüşte hemen 1 sayaç isteği; yazı taslağı arka plana gidip gelince korundu; 1,6× yazı tipinde Ana Sayfa, Profil, Mesajlar ve Compose'da taşma yok; anonim gönderi başka hesaptan `author:null`, ad / kullanıcı adı / avatar / e-posta sızmıyor; hesap silme sonrası token 401, profil 404, arama ve yakında listesinde yok, konum / geçmiş / eşleşme / cihaz / token kayıtları silindi, cihazda oturum login ekranına döndü.

Sınırlar: hesap silme formundaki "SİL" onay metninin noktalı İ harfi `adb input text` ile yazılamadığı için bu turda elle yazılmadı; aynı form her Pixel regresyonunda (`account_test.dart`) gerçek UI'dan çalıştırılıp geçiyor. Silme bu turda uygulamanın gönderdiği aynı gövdeyle API üzerinden çağrılıp cihazdaki etkisi gözlendi. Tam TalkBack sertifikasyonu iddia edilmez (Flutter semantics widget testleriyle, 1,6× yazıyla görsel olarak denetlendi). Force-stop sonrası konum kaydı iddia edilmez.

Kapak dosyaları `GET /api/v1/covers/{uuid}.jpg` ile kimlik doğrulamasız sunulur — bilinçli: herkese açık profil kapağı. Yalnız aktif bir kullanıcının `covers/` altındaki bağlı dosyası sunulur; UUID regex'i, traversal / yetim dosya / askıya alınmış / yasaklı / silinmiş hesap için 404 testlidir.

---

## Ürün tamamlama doğrulaması — 13 Kasım 2026 (1. tur)

Başlangıç (`db90b1e`, değişiklik öncesi) ile final karşılaştırması:

| Kontrol | Başlangıç | Final |
|---|---|---|
| Laravel `php artisan test` | 105 test / 1303 assertion | **109 test / 1405 assertion geçti** (+4 test: kapak yükleme, public profil gizliliği, scheduler/7 gün saklama, public web akışı) |
| `flutter analyze` | No issues found | **No issues found** |
| Flutter `flutter test` | 96 geçti | **98 geçti** (+2: kapak yükleme, kişi satırında şehir yok) |
| Pixel 6a entegrasyon (`tool/run_pixel_regression.ps1`) | — (başlangıçta koşulmadı) | **9/9 geçti**, sahipli fixture temizliği `clean=true` (`tool/run_pixel_regression.ps1 -SkipClean`) |
| Pixel 6a location-time (`-Suite location-time`) | — | **3/3 geçti** |

Hiçbir test silinmedi, atlanmadı veya assertion'ı gevşetilmedi. Entegrasyon testlerinde yalnızca kilitli final arayüzle ve bu çalışmadaki kararla uyumsuz bulucular güncellendi: "Profili Düzenle" etiketi, ikinci "Paylaşım oluştur" semantiği için `compose-button` anahtarı, kişi satırlarında artık şehir olmadığı için `@kullanıcıadı` (önceki `@kullanıcıadı · şehir`) bulucusu ve boş bulucuda çöken kaydırma yardımcısı.

Gerçek cihaz / tarayıcı kanıtları: Pixel 6a (`Pixel_6a`, emulator-5554) üzerinde normal debug uygulama, local API `http://127.0.0.1:8000/api/v1`; admin paneli → mobil uçtan uca: Yakınındaki İnsanlar modülü kapatıldı → mobil Ana Sayfa'dan kayboldu → yeniden açıldı; bakım modu açıldı → mobil bakım ekranı → kapatıldı → uygulama normale döndü (`docs/screenshots/ui-audit/e2e-module-disabled.png`, `e2e-maintenance.png`). Duyuru ve minimum sürüm akışları testlerle (`AdministrationTest`, `ProductionReadinessTest`) doğrulandı; bu turda cihazda ayrıca denenmedi. Public web: 1200 px masaüstü ve 390 px mobil tam sayfa görüntüleri `docs/screenshots/web-final/` altındadır; yatay taşma yok, mobil menü çalışıyor.

Dış bağımlılıklar (Firebase/FCM, Google/Apple production, APNs, SMTP, Android keystore, alan adı/sunucu/SSL, gerçek operatör ve legal bilgileri, App Store / Play Store adresleri) bu çalışmada sahte değerle doldurulmadı: EXTERNAL / WAITING.

---

# Doğrulama — 10 Kasım 2026 (tarihsel kayıt)

Güncel çalışma mobil UI/UX denetimi ile uçtan uca ürün bütünlüğü (mobil + Laravel API + Admin panel + Public web) tamamlamasıdır. [Ürün bütünlüğü denetimi](PRODUCT_GAP_AUDIT.md), [41 yüzeylik envanter](UI_AUDIT.md), [tasarım sistemi](UI_DESIGN_SYSTEM.md) ve [cihaz/ekran kanıtları](UI_AUDIT_VALIDATION.md) birlikte okunmalıdır. Önceki [store hazırlık raporu korunur](test-history/validation-2026-11-09-before-ui-audit.md); [store paketinin gerçek yayın kapıları](store/README.md) değişmedi.

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| Flutter test | **83 geçti**; birleşik filtre ve UI kalite regresyonları dahil | `flutter test` |
| Flutter analyze | **No issues found** | `flutter analyze` |
| Android normal debug APK | **Başarılı**, `lib/main.dart` | [Checksum](apk-checksum.json) |
| APK bütünlüğü | **1 kernel_blob.bin, 0 mükerrer ZIP entry** | [Checksum](apk-checksum.json) |
| Laravel test | **105 test / 1303 assertion geçti** | `php artisan test` |
| Pixel 6a | Normal Demo UI walkthrough; birleşik filtre, harita, akış ve bildirim kontrolü | [UI doğrulaması](UI_AUDIT_VALIDATION.md) |
| Mobil ekran kanıtları | İstenen 24 dahil 32 gerçek PNG tek tek incelendi (`03-filters.png` güncellendi) | [Screenshot indeksi](UI_AUDIT_VALIDATION.md#tek-tek-görsel-kontrol) |
| Web & Admin kanıtları | Public web (5 PNG) ve Admin panel (12 PNG) olmak üzere **17 gerçek browser ekran görüntüsü** | `docs/screenshots/web-admin-audit/` |
| Geçici veri temizliği | **10 sahipli kullanıcı, 0 test postu/sohbet; clean=true** | [Temizlik](ui-pixel-cleanup-audit.json) |

Ürün tanımındaki 29 ekranın hiçbiri eksik değildi. Profil taslak koruması, birleşik feed filtreleri (`Karşılaşmalar + Fotoğraflı + 10 km + Yeni`), bildirim hedefi erişilebilirlik kontrolü (`available`), uygulama içi + push bildirim tercihlerinin ortak uygulanması, duyuru yaşam döngüsü (`is_active`, `expires_at`), admin engellemeler/modüller/roller/kullanıcı moderasyon geçmişi ve public web yolculuk anlatısı tamamlandı. Home sırası korundu; sabit sayı/sahte online işareti kaldırıldı.

Normal uygulama Demo hesabıyla Pixel 6a Ana Sayfa'da açık bırakıldı; [güncel ekran](screenshots/pixel6a-current.png) bunun kanıtıdır. Fotoğrafsız ve anonim gönderi kuralları, gerçek medya, konum/zaman/yolculuk ve mesaj polling davranışları korundu.

İşlevsel sınırlar: harita yalnız desteklediği mesafe parametrelerini uygular, arama ilgi alanına göre insan aramaz. Tam TalkBack/VoiceOver, iOS fiziksel cihaz ve tüm temiz-kurulum izin varyantları ayrıca doğrulanmalıdır. Final logo, production provider/signing/legal/store bilgileri ve mağaza gönderimi bu çalışmanın dışındadır; [STORE_READINESS.md](STORE_READINESS.md) geçerlidir.
