# SenMiydin? — Final Release Candidate

Durum tarihi: 15 Kasım 2026. Başlangıç commit'i `2e8690f` (global sosyal sürüm), RC commit'i `Finalize SenMiydin release candidate`.

Bu belge iki şeyi ayırır: **CODE READY** (kodda tamamlanmış ve bu ortamda kanıtlanmış) ve **EXTERNAL REQUIRED** (kod hazır, ama gerçek hesap, alan adı, sunucu, anahtar ya da Mac olmadan doğrulanamayan). Hiçbir gerçek kimlik bilgisi, anahtar ya da operatör bilgisi uydurulmamıştır.

## 1. Doğrulama özeti

| Kontrol | Sonuç |
|---|---|
| Laravel `php artisan test` | **247 test / 5080 assertion geçti** (başlangıç 215 test / 3846 assertion) |
| `flutter analyze` | **No issues found** |
| Flutter `flutter test` | **277 test geçti** (başlangıç 259 test) |
| Pixel 6a entegrasyon (`tool/run_pixel_regression.ps1`) | **9/9 geçti, `clean=true`** |
| Pixel 6a location-time | **3/3 geçti, `clean=true`** |
| `tool/release_check.ps1` | Kod/test/migration/paket/gizli dosya kontrolleri **OK**; yalnız dış bağımlılıklar `MISSING` (production config, Android imzası) |
| `tool/store_readiness_check.ps1` | Kod kaynaklı satırlar **READY**; dış bağımlılıklar `MISSING` / `WAITING` |
| Public web (20 sayfa × 9 genişlik) | yatay taşma 0, kırık bağlantı 0, kırık görsel 0, konsol hatası 0, her sayfada tek H1 |
| Gizli bilgi taraması (10 commit, tüm geçmiş) | Gerçek sır **yok** (yalnız Google'ın yayımlanmış AdMob örnek kimlikleri ve boş şablonlar) |

## 2. Bu turda bulunan ve düzeltilen gerçek hatalar

| # | Hata | Düzeltme |
|---|---|---|
| 1 | Yorum başlığı (zaman etiketi + sil/şikâyet ikonu) 320 dp / 1.5× yazıda taşıyordu; yalnız saat farkı yüzünden testlerde gizli kalmıştı | `comments_sheet.dart`: ad `ellipsis`, zaman etiketi genişliğe oranlı sınır; saatten bağımsız yeni test |
| 2 | 18. doğum gününde PHP yolu (`bandOf`, Eloquent `date` cast = UTC gece yarısı) hesabı **bir gün daha** TEEN sayıyordu; SQL yolu doğruydu (tutarsızlık) ve SQLite'ta `DATE` karşılaştırması yanlıştı | `AgeSafety::band` takvim günüyle çalışır (`Y-m-d`), SQL `DATE(birth_date)`; `Europe/Istanbul` sınır testi |
| 3 | Yaş bandı değişince yazı sahibi, başka banttaki yorumu **silebiliyordu / varlığını 403 ile sızdırıyordu** | `deleteComment` artık `Blocks::exclude` ile 404 |
| 4 | Başka banttaki harita-notu yanıtı için 403 (varlık sızıntısı) | `destroyReply`: görünmeyen yanıt 404 |
| 5 | Engel listesi ve `PUT /blocks/{id}` karşı banttaki hesabı adıyla gösteriyor / kabul ediyordu | liste `AgeSafety::scope`, engelleme 404 |
| 6 | Dil seçilmemiş hesapta uygulama-içi gelen kutusu İngilizce, FCM push'u Türkçe olabiliyordu | `users.last_locale` (uygulamanın son gönderdiği dil); push ve gelen kutusu aynı karar fonksiyonunu (`SetLocale::resolve/forUser`) kullanır |
| 7 | `devices:prune` komutu var olmayan `user_devices.updated_at` sütununu kullanıyordu (üretimde her gün hata verirdi) | `last_seen_at`; komut testi |
| 8 | Aynı bildirim için yinelenen/yeniden denenen iş FCM'e ikinci kez gidebiliyordu | `app_notifications.pushed_at` (yalnız `fcm` sürücüsü); kuyruk/retry/failed_jobs testi |
| 9 | Kamera fotoğrafı EXIF yönüne güveniyor; yeniden kodlama yönü silince dikey fotoğraf **yan** çıkıyordu (mesaj, gönderi, avatar, kapak) | `PrivateImage::orientation/upright` (bağımlılıksız EXIF okuyucu) |
| 10 | İngilizce arayüzde "DELETE yaz" deniyordu ama hesap silme yalnız `SİL` kabul ediyordu (Apple hesap silme akışı) | İstemci iki dili de kabul eder, API `SİL,DELETE` |
| 11 | ~40 parametreli arayüz metni (`$sayı yanıt`, `Yanıtlanıyor: …`, ay adları, "x yaşını doldur…") İngilizceye çevrilmiyordu; tooltip/ipucu metinleri de | `trf()` + 81 katalog girdisi, tooltip/hint/semantic `tr()`, `tool/l10n_audit.py` (CI'da 0 kaplanmamış literal) |
| 12 | iOS `ADMOB_APP_ID_IOS` xcconfig'te `#include? OAuth.xcconfig` **sonrasında** tanımlıydı; gerçek kimlik hiçbir zaman örnek kimliği geçemezdi | Sıra düzeltildi; `configure_mobile.py` AdMob kimliklerini doğrulayıp yazar |
| 13 | iOS: `en/tr.lproj/InfoPlist.strings` Xcode projesine **bağlı değildi** (yerelleştirme pakete girmezdi); uygulama düzeyi `PrivacyInfo.xcprivacy` yoktu | `project.pbxproj` güncellendi (variant group, knownRegions `tr`), `PrivacyInfo.xcprivacy` eklendi (Mac'te Privacy Report ile doğrulanmalı) |
| 14 | Üretim Android sürümü, kimlik verilmediğinde Google'ın örnek AdMob uygulama kimliğiyle paketlenebilirdi | `build_android_release.ps1` gerçek kimlik ister (`-AllowNoAds` bilinçli istisna); `store_readiness` "AdMob production identifiers" satırı |
| 15 | `.env.example` üretim için `PUSH_DRIVER=log` ve yeni özelliklerin ayarlarını içermiyordu | Güncellendi |
| 16 | UMP/consent callback'i hiç dönmezse reklam servisi sonsuza dek "başlıyor" kalırdı; `showPrivacyOptions` hata fırlatabilirdi | 20 sn zaman aşımı, hata yutma |
| 17 | `tool/l10n_audit.py` düzenli ifadesi `n` harfi içeren dizeleri hiç eşleştirmiyordu: "kapsam 0 eksik" yanlıştı; gerçek yürüyüşte ~190 çevrilmemiş Türkçe metin (kimlik/şifre sıfırlama, hata mesajları, Hikâye/Keşfet/Harita notu metinleri, ay adları…) çıktı | Düzenli ifade düzeltildi; 220+ katalog girdisi; araç artık parametreli (`$x`) cümleleri de yakalar ve `release_candidate_test` içinde `--all` ile çalışır |
| 18 | Sunucu genel hata/başarı cümleleri (404 "Aradığın kayıt bulunamadı." …) İngilizce arayüzde Türkçe görünüyordu; 401 mesajı dil middleware'inden önce üretiliyordu | `lang/en/messages.php` (90+ cümle) + `ApiResponse::localize`, hata renderer'ı dili kendisi belirler (`SetLocale::forRequest`) |
| 19 | Canlı dil değişiminde `const Text` ve önbellekli etiketler eski dilde kalıyordu ("HESAP VE PROFİL" başlıkları, "View on Map") | `AppLocale.rebuildEverything()`: gezinme/durum korunarak tüm elementler yeniden kurulur; widget testi |
| 20 | Mevcut konumu gönderirken ilk GPS düzeltmesi 12 sn'ye kadar sürebiliyor ve hiçbir geri bildirim yoktu | "Konum alınıyor…" bilgisi (zaman aşımında hata mesajı zaten vardı) |

## 3. CODE READY

Aşağıdakiler kodda tamamlanmıştır ve ilgili test/E2E ile kanıtlanmıştır (ayrıntı: `docs/VALIDATION.md`).

- **Mobil arayüz:** Home sekme/şehir kontrolleri (320–430 dp), Profil 2×2 bağlantı ızgarası, PostCard, buluşma kartı, bildirim bottom sheet + tam sayfa (Bugün/Dün/Daha Önce), tüm bildirim tiplerinin güvenli yönlendirmesi.
- **Mesajlaşma:** liste, sohbet çubuğu `[+][emoji][alan][gönder]`, emoji (imleç konumu), galeri/kamera fotoğrafı (önizleme, EXIF temizliği, yön düzeltmesi), konum mesajı (yaklaşık ~55 m, "Haritada Aç", ham GPS dönmez), iyimser gönderim/hata/yeniden dene, okundu, silme, şikâyet, engelleme.
- **Yaş güvenliği:** `AgeSafety` TEEN (16–17) / ADULT (18+) sunucuda; tüm sosyal grafik `Blocks` katmanından geçer (feed, post, arama, profil, takip, yakındakiler, buluşma, DM, harita notu, yorum, kaydedilenler, bildirim). 18. doğum günü `Europe/Istanbul` sınırında test edildi; band değişince eski sohbet/takip/buluşma/harita notu/bildirim uçtan uca kapanır (`AgeBandTransitionTest`).
- **Bildirimler:** 19 tip × (DB, uygulama içi görünürlük, tercih, push uygunluğu, hedef erişilebilirlik, engel, kendine bildirim, dil, dokunma rotası) ana matrisi (`NotificationMatrixTest`); `nearby_post` yarıçap/tazelik/şehir/tercih/tekrar/yazar/yaş kuralları; yerel veritabanı kuyruğu, backoff, `failed_jobs`, `queue:retry`, idempotans.
- **Admin:** konum hedefli duyuru (tümü/şehir/yaklaşık nokta + 500 m/1 km/5 km), TR/EN, planlı/bitiş/pasif, denetim günlüğü, 100'den fazla alıcıda `last_user_id` sayfalaması, yarıda kalan batch'te tekrar çalıştırmanın yinelenen bildirim üretmemesi (`AnnouncementBatchTest`).
- **Çok dil:** ARB + katalog + `trf`, cihaz dili varsayılanı, Ayarlar'dan dil, kalıcılık, `preferred_locale`/`last_locale`, yerelleştirilmiş bildirim/FCM/duyuru.
- **Reklam:** AdMob native feed reklamı (ilk 7. organik gönderiden sonra, sonra aralıklı), "Reklam/Ad" etiketi, admin `ads_enabled`/`feed_ad_interval`, UMP, teen `AgeRestrictedTreatment.teen` + `MaxAdContentRating.T` + kişiselleştirilmemiş istek, reklama konum gitmez, kimlik yoksa release'te reklam alanı yok.
- **Public web:** TR/EN site, yeni özellikler, yasal sayfalar (KVKK, Gizlilik, Koşullar, Topluluk, Hesap Silme, İletişim), operatör bilgisi yalnız admin ayarlarından (yoksa `production-check` `MISSING`).
- **Operasyon:** `tool/release_check.ps1`, `tool/store_readiness_check.ps1`, backend ZIP (`.env`, geliştirme DB, fixture, sır içermez) ve checksum manifesti, Android debug APK.

## 4. EXTERNAL REQUIRED

Her madde: neden gerekli → hangi dosya/ayar → nasıl doğrulanır.

| # | Bağımlılık | Neden | Dosya / ayar | Doğrulama |
|---|---|---|---|---|
| 1 | Gerçek alan adı, sunucu, DNS, SSL | Mobil release API `https://senmiydin.tr/api/v1`; yasal URL'ler canlı olmalı | `config/production.json`, `APP_URL`, `docs/DEPLOYMENT.md` | `php artisan app:check --production`, `GET /health`, mağaza URL'leri 200 |
| 2 | Production veritabanı | MySQL/MariaDB, yedek, migration | `.env` `DB_*`, `php artisan migrate --force` (seed **yok**) | `app:check`, `migrate:status` |
| 3 | Firebase Android uygulaması | Push için `google-services` değerleri | `python tool/configure_mobile.py --android google-services.json` → ignore edilen `config/production.local.json` | Gerçek cihazda push alma |
| 4 | FCM servis hesabı | Sunucudan gerçek FCM gönderimi (`PUSH_DRIVER=fcm`) | `.env` `FCM_PROJECT_ID`, `FCM_CREDENTIALS` (web kökü dışında) | Test bildirimi; `failed_jobs` boş |
| 5 | Google OAuth | Google ile giriş audience'ları | `GOOGLE_CLIENT_IDS`, `GOOGLE_WEB_CLIENT_ID` | Gerçek hesapla giriş |
| 6 | SMTP | Parola sıfırlama / iletişim e-postaları | `.env` `MAIL_*` | Gerçek e-posta teslimi |
| 7 | AdMob kimlikleri + UMP konsol mesajı | Gerçek reklam; GDPR/ATT mesajı AdMob konsolunda yapılandırılır | `configure_mobile.py --admob-android-app-id … --admob-ios-app-id … --admob-android-native-unit … --admob-ios-native-unit …`; `app-ads.txt` | `store_readiness` "AdMob production identifiers" WAITING→READY, gerçek cihazda test dışı reklam |
| 8 | Android upload keystore | Release AAB imzası | `android/key.properties` (`create_android_keystore.ps1`) | `build_android_release.ps1`, `bundletool` imza |
| 9 | Google Play Console | Uygulama kaydı, Data Safety, içerik derecelendirme, ads beyanı | `docs/store/GOOGLE_PLAY_*.md`, `docs/store/localization/` | Dahili test yayını |
| 10 | Operatör / hukuk / destek bilgileri | KVKK/Gizlilik'te gerçek işletmeci, adres, MERSİS/vergi, KVKK iletişimi, destek e-postası | Admin → Ayarlar (+ `LEGAL_REVIEWED=true`) | `production-check` "Operator identity and reviewed legal CMS" READY |
| 11 | App Store hesabı, Sign in with Apple | iOS yayın, hesap silme + Apple girişi | Apple Developer, `APPLE_*` | App Store Connect |
| 12 | APNs anahtarı, iOS Firebase plist | iOS push | `GoogleService-Info.plist` → `configure_mobile.py --ios …`, APNs auth key Firebase'e | iOS cihazda push |
| 13 | Mac / Xcode | iOS derleme/arşiv, `Privacy Report`, imzalama | Aşağıdaki Mac listesi | Xcode Organizer, TestFlight |
| 14 | TestFlight / Play iç test | Gerçek cihaz kabulü | Mağaza hesapları | Test kullanıcıları |

### Mac'te yapılacaklar (iOS)

1. `open ios/Runner.xcworkspace`; **Runner target → Info → Localizations** altında English + Turkish'in işaretli olduğunu ve `InfoPlist.strings (en, tr)` ile `PrivacyInfo.xcprivacy`'nin Resources'a girdiğini doğrula (dosyalar `project.pbxproj`'a elle bağlandı; Xcode ilk açılışta sorun bildirirse Add Files ile yeniden ekle).
2. Signing & Capabilities: ekip, **Sign in with Apple**, **Push Notifications** (`aps-environment` Debug=development/Release=production), Background Modes → Remote notifications.
3. `ios/Flutter/OAuth.xcconfig` (ignore edilir) için `python tool/configure_mobile.py --ios GoogleService-Info.plist --admob-ios-app-id …` çalıştır; Info.plist `GADApplicationIdentifier` artık gerçek kimliği okur.
4. `GoogleService-Info.plist`'i Runner'a ekle (repoya girmez).
5. `flutter build ipa --dart-define-from-file=config/production.local.json`; Archive → **Product ▸ Generate Privacy Report** ile `PrivacyInfo.xcprivacy` + SDK manifestlerini `docs/store/APPLE_PRIVACY_LABELS.md` ile karşılaştır.
6. App Store Connect: Yaş derecelendirmesi (16+ kayıt sınırı), App Privacy (tracking = evet, AdMob), hesap silme URL'si, Sign in with Apple, reklam beyanı (IDFA).
7. TestFlight iç test; ATT isteği ve UMP formu davranışını gerçek cihazda dene.

## 5. Bilinen sınırlar (dürüst)

- Gerçek FCM teslimatı, gerçek AdMob reklam yüklemesi ve UMP konsol mesajı **doğrulanamadı** (dış kimlik).
- iOS Windows'ta derlenmedi; iOS maddeleri yalnız statik incelendi.
- İngilizce kapsam: ARB + ~530 girişlik katalog; kullanıcı içeriği, şehir/hobi katalog adları ve sunucudan gelen serbest metin bilerek çevrilmez.
- Yerel geliştirme veritabanındaki eski bir `legal_pages` satırı Türkçe Gizlilik sayfasını gölgeler (admin düzenlemesi yapılandırılmış içeriğe baskın gelir); üretim veritabanında bu satır yoktur, ama operatör yasal sayfaları panelden düzenlerse yapılandırılmış içeriği bilerek geçersiz kılar.
