# Doğrulama

> **Güncel kaynak bu dosyanın ilk bölümüdür (15 Kasım 2026, splash, değerlendirme ve dış paylaşım).** Altındaki bölümler önceki turların tarihsel kayıtlarıdır; oradaki sayılar güncel durum değildir.

## Splash, haftalık değerlendirme ve dış paylaşım kartları — 15 Kasım 2026 (en güncel)

Başlangıç `1a3a9ce` (yeniden ölçüldü: Laravel 265 / 5335, Flutter 342, analyze temiz). Bu tur freeze'e **kullanıcının açıkça istediği** üç özellik girdi: Android native splash, göz animasyonu, haftalık değerlendirme daveti, dış paylaşım kartları. Dördü de yayın hazırlığının parçasıdır; başka özellik eklenmedi.

| Kontrol | Sonuç |
|---|---|
| Laravel `php artisan test` | **278 test / 5423 assertion** (+13: `PublicShareTest` 12 incl. app-ads.txt, `FcmDeliveryTest` 1; `ReleaseOperationsTest` yerel .env'den bağımsız hâle getirildi) |
| `flutter analyze` | **No issues found** |
| Flutter `flutter test` | **393 test** (+51: `android_splash_test` 4, `review_prompt_test` 21, `share_card_test` 8, `share_service_test` 18; eski göz animasyonu testi yeni sıraya uyarlandı: merkez → sağ → sol → merkez) |
| `tool/l10n_audit.py --all` | **0 eksik** (catalog 807) |
| `platform_manifest_check.py android --build` | FAIL yok; App Links (`/p/`, `/n/`, `autoVerify`) kabul edilir, başka https yolu reddedilir (15 birim testi). AdMob kimliği `MISSING` |
| `platform_manifest_check.py ios` | FAIL yok (Associated Domains `applinks:` eklendi) |
| Pixel 6a regresyon | **9/9**, `clean=true` |

**Android native splash.** `androidx.core:core-splashscreen` (SplashScreen API) + beyaz yüzey + yalnız ikon (`native_splash_icon.png`, onaylı splash artwork'ünden `tool/make_native_splash_icon.py` ile çıkarıldı: yırtık kâğıt, gözler, üç ışık çizgisi; 1152 px = 288 dp, Android 12'nin 192 dp maske dairesinin içinde). Eski mor dikdörtgen artwork, `values-v31` / `values-night` geçersiz kılmaları ve `launch_background` çizimleri kaldırıldı. Pixel 6a'da soğuk / sıcak / süreç öldürme kayıtları (ffmpeg kare analizi): beyaz native splash → Flutter splash'ta 220 ms yumuşak geçiş → Home; siyah/beyaz parlama, kare atlaması ve havada asılı gözbebeği yok. Kayıtlar `docs/screenshots/ui-audit/splash-*.png`.

**Göz animasyonu — kök neden.** Animasyon vardı ama (1) hareket genliği artwork'ün kendi pozuna çok yakındı (±36 / 1080 px), (2) yaklaşık 3 sn süren soğuk açılıştan sonra yalnız 1,7 sn görünüyordu ve (3) her kare `Stack`'in anahtarı değiştiği için yeniden kuruluyordu. Şimdi: merkez → biraz sağ → biraz sol → merkez, 1,4 sn, `easeInOutCubic`, genlik ×1,15 (gözbebeği göz akında kalır); büyük artwork çözülmeden hiçbir şey çizilmez (gözbebekleri tek başına görünmez).

**Haftalık değerlendirme.** `in_app_review` 2.0.12 (MIT, doğrulanmış yayıncı, 160/160 puan) → Android Play In-App Review, iOS StoreKit. Kural: hesap ≥ 3 günlük (sunucudan `created_at`) **ve** ≥ 3 anlamlı işlem (paylaşım, yorum, mesaj, Harita Notu, not yanıtı) **ve** son davetten ≥ 7 gün; oturum başına en fazla 1; hesap başına ayrı sayaç; hesap silinince temizlenir. Davet yalnız anlamlı işlemden sonra ve kişi Home'a döndüğünde 1,6 sn gecikmeyle çıkar (üstte başka sayfa/diyalog varsa bekler). "Şimdi Değil", kaydırarak kapatma ve "Değerlendir" aynı 7 günlük bekleme süresini başlatır; "Değerlendir" herkes için aynı resmi isteği açar (önce "sevdin mi?" kapısı yok). OS sheet'i bastırırsa/hata verirse sessizce geçilir; yalnızca gerçek bir `PLAY_STORE_URL` / `APP_STORE_URL` (https) tanımlıysa mağaza sayfası yedek olarak açılır. Resmi sheet'in gerçekten görünmesi Play kotasına bağlıdır ve closed-test Play yüklemesinde ayrıca doğrulanır; debug'da yalnız davet zamanlaması (seam + Pixel) doğrulandı.

**Dış paylaşım.** Herkese açık, yetişkin yazarlı gönderi / yayında ortak karşılaşma hikâyesi / canlı Harita Notu `https://<alan adı>/p/<id>` ve `/n/<id>` bağlantısı alır (`public_id`: rastgele 12 karakter, satır id'siyle ilgisiz). Özel, silinmiş, moderasyonlu, süresi dolmuş/arşivlenmiş, onaysız karşılaşma ve **16–17 yaş içeriği** bağlantı almaz (web 404). Kartlar uygulamada çizilir (Flutter, ekran dışı → PNG, metaveri yok): Hikâye 1080×1920, diğerleri 1080×1350; anonim kartta ad/avatar/handle hiç yok, Harita Notu kartında yalnız yaklaşık bölge etiketi var. Paylaşım sayfası (`Paylaş`): Hikâyede Paylaş (Instagram yüklüyse ve `INSTAGRAM_FACEBOOK_APP_ID` verilmişse doğrudan Story composer, aksi halde normal paylaşım sayfası), Görsel Kart, Bağlantıyı Kopyala, Diğer. Gelen bağlantı Android App Links ile uygulamada açılır (`app_links` 7.2.2, Apache-2.0); uygulama yoksa web önizleme (OG/Twitter/canonical, noindex). `/.well-known/assetlinks.json` ve `apple-app-site-association` yalnız gerçek imza parmak izi / Team ID yapılandırılınca sunulur. Pixel 6a: metin, fotoğraflı, anonim, ortak karşılaşma ve Harita Notu kartları cihazda üretildi (`docs/screenshots/ui-audit/share-card-*.png`, `share-sheet.png`); Android paylaşım seçicisine görsel+bağlantı ile ulaşıldı; Instagram kurulu olmadığı için yedek yol doğrulandı; bağlantıyla soğuk/sıcak açılış doğrulandı.

**Sağlayıcı operasyonu (özet — ayrıntı `docs/PRODUCTION_OPERATIONS.md`).** Firebase projesi + Android uygulaması + parmak izleri + Google sağlayıcı + FCM servis hesabı; AdMob Android/iOS uygulamaları ve native birimleri; imzalı AAB (81,3 MB, upload sertifikası, gerçek AdMob kimliği, `platform_manifest_check` **OK**). **Gerçek FCM push Pixel 6a'da doğrulandı** (mesaj: arka plan / süreç kapalı / ön plan; beğeni, yorum, mesaj isteği; kapalı uygulamadan bildirime dokunup sohbete gitme). Gerçek push yolunda bulunan hata (`accessToken` closure'ı `$project`'i yakalamıyordu) düzeltildi. Play Console / App Store Connect / üretim sunucusu / SMTP / alan adı için **HUMAN ACTION REQUIRED** maddeleri belgededir; `senmiydin.com` DNS'te çözülmüyor.

**Cihazda bulunup düzeltilenler:** `share_plus` kendi `share_plus` önbellek klasörünü her paylaşımda boşalttığı için kartlar kendi klasörümüze (`senmiydin_share`) taşındı; Flutter, gelen bağlantıyı ayrıca rota adı (`/p/<id>`) olarak itiyordu ("Sayfa Bulunamadı") → bağlantı rotası kendini kapatıp tek yoldan açıyor; davet zamanlayıcısı üstte sayfa varken sönüyordu → Home geri gelene kadar yeniden dener.

---

## Son mesajlaşma/medya ve release freeze doğrulaması — 15 Kasım 2026 (önceki tur)

Başlangıç `1519d36` (RC). Bu turda: gelişmiş emoji paneli, sesli mesaj, ücretsiz hediyeler, fotoğraflı Harita Notu, ham zaman damgasından canlı dil değişen göreli zaman, birleşik Android release manifest kontrolü, iOS statik kontrol, release freeze.

| Kontrol | Sonuç |
|---|---|
| Laravel `php artisan test` | **265 test / 5335 assertion geçti** (+18: `VoiceAndGiftMessageTest` 10, `MapNoteImageTest` 8) |
| `flutter analyze` | **No issues found** |
| Flutter `flutter test` | **342 test geçti** (+65: emoji/sesli mesaj 27, hediye/mesaj türü/göreli zaman 18, Harita Notu fotoğrafı 18, release kontrol 2). Mevcut testler silinmedi/gevşetilmedi; yalnız eski emoji sayfası ve "boş girdide mikrofon" UX'ine uyarlandı |
| `tool/l10n_audit.py --all` | **0 eksik** (catalog 793) |
| `tool/platform_manifest_check.py android --build` | Gradle `processReleaseMainManifest` → **birleşik release manifest**: paket, cleartext kapalı, yedek kapalı, debuggable değil, izinler (mikrofon dahil), FCM, AdMob bileşenleri, konum foreground servisi, provider'lar dışa kapalı, yalnız beklenen exported bileşenler, yalnız `signinwithapple` şeması, yerel/debug uç yok → **FAIL yok**; AdMob uygulama kimliği Google örneği olduğu için `MISSING` (harici kimlik bilgisi). 13 birim testi sentetik manifestlerle yanlış durumda FAIL verdiğini doğrular |
| `tool/platform_manifest_check.py ios` | Info.plist / gizlilik manifesti / yerelleştirilmiş izin metinleri / ATS / arka plan modları: **FAIL yok**; AdMob iOS kimliği `MISSING`. **Xcode derlemesi, imzalama, archive yapılmadı** (`docs/IOS_MAC_HANDOFF.md`) |
| `tool/release_check.ps1` | Flutter env/pub/analyze/test, Composer test, migration, paket kimlikleri, demo seeder, hassas dosya, **Android birleşik manifest**, **iOS statik**: OK; yalnız production config, AdMob kimlikleri ve Android imzası `MISSING` (exit 2) |
| `tool/store_readiness_check.ps1 -SkipRuntime` | `READY 34 / WAITING 6 / MISSING 6`, **FAIL yok** (`RECORD_AUDIO` ve AdMob `AD_ID` artık yasaklı değil, gerekli/beklenen) |
| Pixel 6a regresyon | **9/9**, `clean=true` |
| Pixel 6a location-time | **3/3**, `clean=true` |

**Gerçek Pixel 6a senaryoları (Demo ↔ Elif):** emoji paneli (imlece ekleme, boş alan / Android geri / klavye ile kapanma, 1.5× yazı), mikrofon reddi (tek açıklama + tek sistem izni, tekrar sormaz), 2 dk otomatik durma (02:00), önizleme dinleme, gönderim (UUID adlı özel dosya, kimliksiz istek 401, Elif'te 200 `audio/mp4`), okundu bilgisi, benim için sil, Elif'ten gelen sesli mesajı oynatma/duraklatma, hediye gönder/al + şikâyet (`reports` kaydı), fotoğraflı Harita Notu (galeri → önizleme → yayın → marker → aç → Mektuplarım Aktif → haritadan kaldır → Arşiv'de fotoğraf duruyor, başka hesap 404 → yeniden paylaş: yeni 7 gün, `occurred_at` korundu, görsel kopyalandı).

**Cihazda bulunan ve düzeltilen gerçek hatalar:** (1) Harita Notu fotoğrafı ve gelen sesli mesaj, `mediaHeaders` yalnız `post-media`/`message-images` için token gönderdiği için yüklenmiyordu → izin listesi `message-audio` ve `map-notes/{id}/image` ile genişletildi (+regresyon testi). (2) Durdur düğmesi 1 sn'den kısa kaydı bildirimsiz siliyordu → ekran üzerinden `stopVoice` ile uyarı gösteriyor. (3) Hediye adları hesap diline göre sunucudan geliyordu, İngilizce arayüzde Türkçe görünüyordu → istemci tarafında yerelleştirildi. (4) İngilizce arayüzde `Durdur`/`Dinle`/`Duraklat`/`Hediye`/`Hobi ara` Türkçe kalıyordu (tek sözcükler denetimden kaçıyordu) → katalog tamamlandı. Test altyapısı: platform eklentileri testlerde yüklenmez (`test/flutter_test_config.dart`, sahte mikrofon/oynatıcı).

**Temizlik:** test sohbeti, sesli mesaj dosyaları, hediye mesajları, Harita Notu fotoğrafları, bildirimler ve şikâyet kaydı silindi (`voice_files=0`, `note_images=0`); cihaz geçici kayıt klasörü boşaltıldı; fixture temizliği ses/not görsellerini de kuyruğa alır.

---

## Final Release Candidate doğrulaması — 15 Kasım 2026 (önceki tur)

Başlangıç `2e8690f` (gerçekten ölçüldü, hiçbir şey değiştirilmeden): Laravel **215 test / 3846 assertion geçti**, `flutter analyze` temiz, Flutter **257 geçti / 2 düştü** (yorum başlığı 320 dp / 1.5× taşması; yalnız saate bağlı olduğu için önceki turda "şimdi" etiketiyle gizlenmişti — gerçek UI hatası, düzeltildi), `release_check` yalnız dış bağımlılık `MISSING`, `store_readiness_check` `READY 53 / WAITING 8 / MISSING 29`. Pixel baseline koşusu, ben çalışırken eklediğim yerel migration henüz uygulanmadığı için 3 testte düştü (yerel API 500); migration uygulanınca geçti — bu yüzden "gerçek baseline" Pixel sayısı olarak son tam koşu esas alınmıştır.

| Kontrol | Final |
|---|---|
| Laravel `php artisan test` | **247 test / 5080 assertion geçti** (+32 test: `AgeBandTransitionTest` 4, `NotificationMatrixTest` 10, `AnnouncementBatchTest` 6, `QueueSchedulerTest` 5, `ImagePrivacyTest` 3, `ApiMessageLocaleTest` 3, `GlobalReleaseTest` +1) |
| `flutter analyze` | **No issues found** |
| Flutter `flutter test` | **277 test geçti** (+18: `test/release_candidate_test.dart` 18; `comment_likes_collections_drafts_test` +1 saatten bağımsız yorum testi) |
| Pixel 6a entegrasyon | **9/9 geçti**, `clean=true` |
| Pixel 6a location-time | **3/3 geçti**, `clean=true` |
| `tool/release_check.ps1` | Flutter env/pub/analyze/test, Composer, migration, paket kimlikleri, demo seeder koruması, hassas dosya taraması **OK**; yalnız production config ve Android imzası `MISSING` |
| `tool/store_readiness_check.ps1` | `READY 53 / WAITING 8 / MISSING 30` (+1 satır: "AdMob production identifiers"); `FAIL` yok |
| Public web | 20 sayfa × 9 genişlik (1920 … 320): yatay taşma 0, kırık bağlantı 0 (44 benzersiz iç bağlantı), kırık görsel 0, konsol hatası 0, tek H1 |
| Admin konum duyurusu (tarayıcı) | Gerçek form + Leaflet seçici: 500 m ve 1 km duyuru oluşturuldu; 1 km'de 4 hesap (yakınındakiler) bildirim aldı, diğer 11 konumlu hesap almadı; Pixel'de TR metin + "Haritada Gör"; pasifleştirme ve denetim günlüğü kayıtları doğrulandı |
| Gizli bilgi taraması | 10 commit'in tamamı + izlenen dosyalar: gerçek sır yok; backend ZIP'leri (`.env`, geliştirme DB, test, sır, demo seeder içermez) doğrulandı |
| Sıfırdan MySQL migration | 47 tablo, rollback `--step=3` ve yeniden migrate, `db:seed` yalnız 82 şehir + 21 ilgi alanı (kullanıcı yok); geliştirme DB'sine dokunmayan `audit_` önekli tablolarda |

**Bu turda bulunan ve düzeltilen gerçek hatalar** `docs/FINAL_RELEASE_CANDIDATE.md` §2 içindedir (yorum başlığı taşması, 18. doğum günü sınır günü PHP/SQL tutarsızlığı, yorum silme / harita yanıtı silme / engel listesinde yaş bandı sızıntıları, push–gelen kutusu dil kararı, `devices:prune` hatası, push idempotansı, EXIF yönü, "DELETE" ile hesap silinememesi, ~190 çevrilmemiş arayüz metni ve broken l10n denetim aracı, API mesajlarının İngilizce olmaması, iOS lproj/PrivacyInfo/AdMob xcconfig, AdMob örnek kimlik koruması, dil değişiminde `const` widget'ların güncellenmemesi).

**Gerçek Pixel 6a senaryoları (Demo ↔ Elif, ASCII metin):**
- *Kamera:* mesaj `+` → Kamera → gerçek kamera uygulaması (sanal sahne) → fotoğraf → ✓ → önizleme → gönder; sunucu 1440×1920, `image/jpeg`, **EXIF/GPS yok** (APP1 yok); Elif tarafında açıldı ve Media Viewer'da dik görüntülendi.
- *Mevcut konumu gönder:* izin açık, GPS sağlayıcısı beslenirken konum alındı; sunucu ham `36.54467 / 32.00213` yerine `36.5445 / 32.0020` sakladı ve yalnız bunu döndürdü; Elif'te "Konum · Yaklaşık bölge · Haritada Aç" balonu, haritayı yaklaşık noktaya odakladı. Emülatörde GPS her 2 sn beslenmezse 12 sn'lik zaman aşımı oluşur; bu yüzden artık "Konum alınıyor…" bilgisi gösterilir.
- *Yaşam döngüsü:* metin + emoji (imleç konumu) + fotoğraf + konum; iyimser gönderim; internet yokken hata ("İnternet bağlantını kontrol edip tekrar dene."), metin korunur, bağlantı gelince aynı istekle yeniden dene (yinelenen mesaj yok); uygulama arka plandayken **0** sorgulama isteği (15 sn), ön plana gelince mesajlar akar; okundu ✓✓; okunmamış rozeti (Mesajlar + zil); kendi mesajını "Benim için sil"; alınan mesajı şikâyet ekranı; engelle → Engellenen Kullanıcılar → engeli kaldır.
- *Dil:* cihaz English → giriş → Ayarlar → Türkçe → tüm ana ekranlar, Ayarlar alt sayfaları, çekmece sayfaları, bildirim paneli/tam sayfa, sohbet; English'e geri dönüş; yeniden başlatma sonrası seçim korunur; sunucuda `preferred_locale` / `last_locale` güncellenir. Gerçek yürüyüş ~60 çevrilmemiş metin ve canlı geçişte `const` widget'ların eski dilde kalması hatasını ortaya çıkardı (düzeltildi).

---

## Küresel sosyal sürüm — 15 Kasım 2026 (en güncel)

Başlangıç `9999d9c` (yeniden ölçüldü): Laravel 170 test / 2844 assertion, Flutter 189, analyze temiz, Pixel 9/9, location-time 3/3.

| Kontrol | Final |
|---|---|
| Laravel `php artisan test` | **215 test / 3846 assertion geçti** (+45: `AgeSafetyTest` 14, `GlobalReleaseTest` 16, `WebsiteLocalizationTest` 15) |
| `flutter analyze` | **No issues found** |
| Flutter `flutter test` | **259 test geçti** (+70: `test/global_release_test.dart`) |
| Pixel 6a entegrasyon | **9/9 geçti**, `clean=true` |
| Pixel 6a location-time | **3/3 geçti**, `clean=true` |
| Public web tarayıcı QA | 16 sayfa × 1920 / 1440 / 1200 / 1024 / 768 / 430 / 390 / 360 / 320 px: **yatay taşma 0**, kırık iç bağlantı 0, her sayfada tek H1, sitedeki konsol hatası 0 |
| Admin konum duyurusu (tarayıcı) | Gerçek form + Leaflet nokta seçici ile oluşturuldu; yarıçap içindeki hesaplara bildirim, dışındaki Elif'e yok; sayılar panelde; pasifleştirilince hedef "kullanılamıyor"; test verisi silindi |

**Hiçbir mevcut test silinmedi veya gevşetilmedi.** Yeni gerekliliğe uyarlananlar: minimum yaş 18 → 16 (`AccountApiTest`, `SocialEngagementTest`, `social_engagement_test.dart`), `ConversationTile` / bildirim paneli / ikon eylemleri için entegrasyon adımları (`communication_test`, `encounter_test`, `social_test`, `media_test`, `app_test`), backend test tabanına Türkçe `Accept-Language`. Araç düzeltmeleri: `tool/store_readiness.py` ATT metnini yalnız AdMob varken kabul eder; regresyon betiği `ADS_DISABLED=true` ile reklamsız koşar.

**Gerçek Pixel 6a (cihaz dili English ile açılış → dil anahtarı → yeniden başlatma):** Home kontrolleri tek satır + şehir altta; profil 2×2 seçenek ızgarası; PostCard / karşılaşma kartı; bildirim paneli (Bugün / Dün / Daha Önce, okunmamış sayısı, Tümünü okundu, Tümünü Gör); konumlu duyuruda **View on map** → harita yaklaşık noktaya odaklandı; mesaj listesi ("Location" önizleme, okunmamış rozeti); sohbette **+** menüsü (Photo / Camera / Location), **emoji** imleçte, metin gönderme, **haritadan seçilen konum mesajı** (sunucuda ızgaraya yuvarlandı), konum balonu + **Open on map**; Ayarlar'da Language / Dil seçimi, **Türkçe seçimi yeniden başlatmada korundu ve hesapta `preferred_locale=tr` oldu**; akışta gerçek **Google test native reklamı** "Reklam" etiketiyle ve AdMob doğrulayıcısı "No implementation issues found" ile görüldü. Test verisi (bildirim, sohbet, duyuru, 10 gönderi) silindi.

**CODE READY / EXTERNAL CREDENTIAL REQUIRED:** CODE READY — bildirim zinciri, tüm push türleri (log sürücüsüyle test), localized FCM gövdesi, nearby_post, konum duyurusu, konum mesajı, yaş bandı, AdMob entegrasyonu, TR/EN. EXTERNAL — gerçek Firebase / FCM service account ve cihaz teslimatı; gerçek AdMob App ID / ad unit ID ve konsolda UMP mesajı; operatör kimliği; mağaza hesapları; iOS derleme / Xcode'a lproj ekleme (Mac).

**Sınırlar (dürüst):** (1) Gerçek FCM ağ teslimatı doğrulanmadı. (2) Kamera ile çekilen fotoğraf Pixel'de denenmedi; galeri fotoğrafı mesajı regresyonda (`communication_test`) doğrulandı. (3) Konum mesajı için "mevcut konumum" yolu cihazda izin penceresine kadar denendi; haritadan seçim yolu uçtan uca doğrulandı. (4) Bildirim dokunma E2E'si Demo hesabında yapıldı (Elif hesabına geçilmedi); yönlendirme tüm türler için widget testiyle kanıtlı. (5) Teen ↔ adult E2E yalnız sunucu testleriyle (istenen); cihazda teen hesabı açılmadı. (6) İngilizce kapsam: yeni ekranlar ARB'de, yerleşik ekranlar ~430 girişli sözlükte; sözlükte olmayan metinler (bazı kayıt / izin açıklamaları, sunucudan gelen ilgi alanı adları, kullanıcı içeriği) Türkçe kalır. (7) iOS derlenmedi.

---

## Compose sadeleştirme ve yorumları alt panele taşıma — 14 Kasım 2026 (önceki tur)

Başlangıç `631123e` (gerçekten çalıştırıldı): Laravel 170 test / 2844 assertion, Flutter 165, analyze temiz, Pixel 9/9, location-time 3/3. Backend bu turda değişmedi.

| Kontrol | Final |
|---|---|
| Laravel `php artisan test` | **170 test / 2844 assertion geçti** (değişmedi) |
| `flutter analyze` | **No issues found** |
| Flutter `flutter test` | **189 test geçti** (+24: `test/compose_comments_sheet_test.dart`; mevcut testler silinmedi / atlanmadı, yalnız yeni UX'e uyarlandı) |
| Pixel 6a entegrasyon | **9/9 geçti**, `clean=true` |
| Pixel 6a location-time | **3/3 geçti**, `clean=true` |

**Yeni Flutter testleri:** Compose 320 / 360 / 390 / 430 dp (iki ikon düğmesi 44×44, beş tür aynı satırda ve sarmıyor, "Konum Ekle" yok, yeni konum adları, harita noktası ↔ cihaz konumu dışlaması, Home konum kısayolu). Yorum paneli 320 / 360 / 390 / 430 dp × 1,0 ve 1,5× yazı; yapı / kapat / yapışık composer, aşağı sürükleyerek kapatma, klavye (viewInsets), boş ve kapalı durum, beğeni kalıcılığı (kapat-aç), uçuştaki istekle kapatma güvenliği, **Home akışında kaydırma konumu korunur + sayaç 0 → 1**, Paylaşım Detayı "Yorum Yaz", `comment` / `comment_reply` / `comment_like` bildirim rotası (köprü), Kaydedilenler'den açılış.

**Mevcut testlerin yeni UX'e uyarlanması (silme / gevşetme yok):** `CommentsPage` → `test/support/comments_host.dart` (`OpenComments`); `widget_test.dart` rota döngülerinde `/comments` köprüsü (yazı + panel) için ek `pop`; entegrasyonda Fotoğraf düğmesi `find.byTooltip('Fotoğraf Ekle')` (`encounter_test`, `social_test`, `media_test`), yorum paneli `comments-close` ile kapanır (`social_test`), `app_test` köprü rotası için ek `pop`, `location_time_test` `Haritada yer seç`.

**Araç düzeltmesi:** `tool/set_demo_location.ps1`, emülatör yeniden başlayınca (test sağlayıcısı henüz yokken) `adb` stderr çıktısını Windows PowerShell 5.1'de sonlandırıcı hataya çeviriyordu; yoklama `Continue` ile yapılıp yalnız çıkış koduna bakılıyor.

**Gerçek Pixel 6a E2E (Demo; arayüz üzerinden, ASCII metin):**

- *Compose:* üstte Konum Ekle yok; iki kompakt ikon düğmesi; beş tür tek satırda (`compose-clean-actions.png`, `compose-types-one-row.png`); `Şehir`, `Haritada yer seç`, `Mevcut konumumu ekle`.
- *Panel:* Home'da yorum ikonu → alt panel arkada Home'u koyulaşmış bırakarak açıldı (`comments-bottom-sheet.png`) → yorum yazıldı, "Yorumlar (2)" ve Home kartı sayacı 2 oldu → kapatınca Home aynı yerde → tekrar açınca yeni yorum duruyor.
- *Yanıt:* Yanıtla → "Yanıtlanıyor: @elifdemo" + `@elifdemo ` ile başlayan composer, klavye açıkken gönder düğmesi görünür (`comments-bottom-sheet-keyboard.png`, `comments-bottom-sheet-reply.png`).
- *Beğeni:* ana yorum ve yanıt kalbi dolu / 1; panel kapatılıp açılınca korundu.
- *Bildirim:* "Paylaşımına yorum yapıldı." bildirimine dokununca Paylaşım sayfası + yorum paneli açıldı.
- Test verisi (yazı, yorumlar, beğeni, bildirim) sonunda temizlendi.

**Sınırlar:** Panelin soğuk başlangıçta bildirimden açılışı widget testinde (köprü rotasıyla) kanıtlıdır; cihazda uygulama canlıyken bildirim denendi. `docs/UI_AUDIT.md` tarihsel rapordur, eski "CommentsPage" satırını olduğu gibi korur; güncel davranış `SENMIYDIN_URUN_TANIMI.md` bölüm 39–40'tadır.

---

## Yorum beğenileri, kaydedilen koleksiyonları ve dayanıklı taslak — 14 Kasım 2026 (önceki tur)

Başlangıç `11721d2` (gerçekten çalıştırıldı): Laravel 162 test / 2627 assertion, Flutter 142, analyze temiz.

| Kontrol | Final |
|---|---|
| Laravel `php artisan test` | **170 test / 2844 assertion geçti** (+8 `CommentLikesAndCollectionsTest`) |
| `flutter analyze` | **No issues found** |
| Flutter `flutter test` | **165 test geçti** (+23 `test/comment_likes_collections_drafts_test.dart`) |
| Pixel 6a entegrasyon | **9/9 geçti**, `clean=true` |
| Pixel 6a location-time | **3/3 geçti** (ilk denemede bayat `kernel_blob.bin` paketleme çakışması; `build/app` temizlenip yeniden koşuldu) |

**Gerçek Pixel 6a E2E (arayüz üzerinden, ASCII metin):**

- *Yorum beğenisi:* Elif yorum yazdı → Demo bildirimden yorum ekranını açtı → ♡ 0 `Yanıtla` satırı → kalbe dokununca dolu kalp ve 1; DB'de `comment_likes` satırı ve Elif için `comment_like` bildirimi ("Yorumunu beğendi.", hedef yazı, `/comments`) → tekrar dokununca geri alındı, sayaç 0, ek bildirim yok (`comment-likes.png`).
- *Koleksiyonlar:* Demo bir gönderiyi kaydetti → ⋮ → **Koleksiyona Ekle** → "Yeni koleksiyon oluştur" → `Alanya` → gönderi koleksiyonda (`collection-add-sheet.png`) → Kaydedilenler: `Tümü | Alanya | +` → Alanya'da gönderi (`saved-collection.png`) → koleksiyonu sil (onay: "içindeki gönderiler Kaydedilenler'de kalır") → koleksiyon yok, gönderi **Tümü**'nde ve `post_saves`'te duruyor.
- *Taslak + süreç öldürme:* Compose → uzun metin + **Yolculuk** türü + galeriden gerçek fotoğraf + Yolculuk bilgileri → 800 ms sonra uygulamanın özel `files/compose_drafts/account-16/` klasöründe `draft.json` ve `media/<n>.jpg` → `am force-stop` (süreç öldürme) → yeniden aç → Compose → "Kaydedilmiş bir taslağın var." → **Devam Et**: metin, tür, fotoğraf (görüntü) geri geldi (`draft-restore-prompt.png`, `draft-restored.png`) → yayınla → klasör silindi, Compose tekrar açılınca uyarı yok.
- *Hesap ayrımı:* Demo taslak bıraktı → çıkış → Elif girişi → Compose temiz, uyarı yok; Demo'nun klasörü diskte durdu.
- Test verisi (yazı, yorum, beğeni, koleksiyon, kayıt, bildirim, taslak klasörü, galeri fotoğrafı) sonunda temizlendi; uygulama normal debug sürümüyle Demo girişli bırakıldı.

**Gerçek cihazda bulunan ve düzeltilen hata:** ilk uygulamada, kullanıcı "Kaydedilmiş bir taslağın var" sorusunu cevaplamadan önce arkadaki boş Compose saklı taslağı ezebiliyordu (yeniden açınca taslak yoktu). Soru açıkken kayıt kilitlendi, kaydetme yalnız gerçek bir değişiklikten sonra çalışır; iki regresyon testi eklendi.

**Sınırlar:** Compose'un galeri seçici ve Android sistem davranışı emülatörde doğrulandı; kamera ile çekilen fotoğrafın aynı kopyalama yolundan geçtiği kod ve depolama testiyle kapsanır, ayrıca cihazda denenmedi. Takip (anonim hariç), Harita Notu ve önceki turların davranışları değişmedi.

---

## Sosyal derinlik: Takip, yorum yanıtları, Mektuplarım, yakındaki yeni mektuplar — 14 Kasım 2026 (önceki tur)

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
