# Production checklist — 9 Kasım 2026

Durumlar kod çalışması ile dış yayın bağımlılıklarını ayırır. Yerel environment'ın production-check sonucunun MISSING olması, testlerin başarısız olduğu anlamına gelmez.

| İş | Durum | Kanıt / sonraki işlem |
|---|---|---|
| Mevcut UI, Home ve son profil/navigation/galeri düzeltmelerini koruma | DONE | Flutter / Pixel regresyonları |
| HTTPS / proxy / hata gizleme / session / CORS / özel medya | DONE | API ve production testleri |
| Hesap silme, token / location / medya / anonimleştirme | DONE | Backend ve disposable Pixel hesabı |
| Polling route / foreground / backoff / dispose | DONE | Ortak RoutePolling + regresyonlar |
| Profil / aktif şehir ayrımı, offline reverse geocoding ve manuel fallback | DONE | LocationTimeTravelTest, post_context_test; LOCATION_TIME_TRAVEL.md |
| Geçmiş yer / occurred_at / location_matches / tek bildirim / feed boost | DONE | SQL aday filtresi, merkezi skor, ayrı bildirim tercihi |
| Yolculuk metadata ve gönüllü public detaylar, grup gerektirmeyen öneri | DONE | Pamukkale senaryosu; mevcut moderasyon ve silme kapsamı |
| EXIF/GPS temizliği ve temel UGC ayarları | DONE | Dört upload akışı, bozuk/SVG/double-extension, tekrar/URL/kelime testleri |
| Rate limit, pagination, sorgu / index denetimi | DONE | RELEASE_AUDIT.md |
| Katalog cache, admin invalidation | DONE | ReleaseOperationsTest |
| Database queue, şifreli mail, push / cleanup outbox | DONE | Queue / teslimat birim testleri |
| Scheduler overlap ve stale device temizliği | DONE | routes/console.php |
| Güvenli production-check / health | DONE | app:check --json; /health |
| Windows release check, paketleme, signing / Android build helper | DONE | tool/*.ps1 |
| Secret / ignore / ZIP audit | DONE | release_safety.py; dist audit |
| Varsayılan backend ZIP, vendor'sız server Composer yöntemi | DONE | dist/senmiydin-backend-release.zip |
| Final artwork uygulama hattı | DONE | apply_branding.ps1; final dosya olmadan REFUSE |
| Final yatay logo ve kare master | WAITING FOR BRAND | Gerçek onaylı SVG dosyaları |
| Android upload keystore / alias / parola | WAITING FOR CREDENTIAL | Gerçek anahtar sahibi interaktif helper'ı çalıştırır veya mevcut anahtarı sağlar |
| Firebase / FCM / Google OAuth | WAITING FOR CREDENTIAL | Gerçek provider dosyaları ve istemci kayıtları |
| Production SMTP | WAITING FOR CREDENTIAL | Host / port / kullanıcı / parola / gönderen, gerçek teslimat |
| Apple Developer / APNs / Sign in with Apple | WAITING FOR CREDENTIAL | Team / key / provisioning / capability |
| Gerçek domain / DNS / SSL / server | WAITING FOR EXTERNAL INFO | Canlı ortam kurulumu; yerel URL production değildir |
| Server cron / worker kurulumu ve izleme | WAITING FOR EXTERNAL INFO | Gerçek sunucu erişiminden sonra DEPLOYMENT.md |
| Support / işletmeci / hukuk / saklama süresi | WAITING FOR EXTERNAL INFO | OPERATOR_* / LEGAL_REVIEWED ve gerçek legal CMS |
| Store metadata / privacy matrisleri / permission / SDK audit / review planları | DONE (doküman) | [Store paketi](store/README.md), [doğrulama](STORE_AUDIT_VALIDATION.md); gerçek submission değil |
| Store hesapları / URL / review erişimi / final privacy cevapları | WAITING FOR EXTERNAL INFO | [Gerçek bilgi listesi](store/REQUIRED_REAL_INFORMATION.md); etkin servis ve log politikasıyla son form onayı |
| Legal CMS / destek / yayımlanmış CSAE standardı ve gerçek safety operasyonu | MISSING | Varsayılan metin ve boş iletişim alanı production-ready sayılamaz |
| Store check otomasyonu | DONE (araç) | tool/store_readiness_check.ps1; [güncel sonuç](store/STORE_READINESS_REPORT.md) MISSING; önceki release helper korunur |
| Gerçek iOS archive / cihaz / privacy report | WAITING FOR MAC | Mac / Xcode ve gerçek signing |

Production'da development seed veya mevcut yerel kullanıcı DB'si kullanılmaz. Yayın kontrolünü gerçek production .env, boş/gerçek production DB ve gerçek operatör ayarlarıyla yeniden çalıştır. Bilgiler gelmeden sahte credential, uydurma işletmeci veya final logo oluşturulmadı.

## 15 Kasım 2026 ekleri — küresel sosyal sürüm

| İş | Durum | Kanıt / sonraki işlem |
|---|---|---|
| Minimum yaş 16 + sunucu tarafı teen / adult ayrımı | DONE | `AgeSafetyTest` (14 test); `MINIMUM_AGE=16` |
| Bildirim hızlı paneli, tam sayfa, tarih grupları; tüm türlerin yönlendirmesi | DONE | `test/global_release_test.dart`; Pixel regresyon |
| FCM zinciri (DB → tercih → DeliverPush → FCM → tıklama) kod ve testle doğrulandı | DONE (kod) | `GlobalReleaseTest` push matrisi; **gerçek FCM teslimatı EXTERNAL CREDENTIAL** |
| Yakındaki yeni paylaşım bildirimi (`nearby_post`, 1000 m / 30 dk, tek bildirim) | DONE | `GlobalReleaseTest`; `config/location.php` |
| Admin konum hedefli duyuru (500 m / 1 km / 5 km), TR/EN içerik, "Haritada Gör" | DONE | `GlobalReleaseTest`, tarayıcı E2E |
| Konum mesajı (yaklaşık ~55 m ızgara), fotoğraf / emoji / kamera mesajı | DONE | `GlobalReleaseTest`, `global_release_test.dart`, Pixel |
| AdMob native feed reklamı, UMP onayı, teen yaş kısıtı, admin anahtarı (`ads_enabled`, `feed_ad_interval`) | DONE (kod, debug test reklamı Pixel'de görüldü) | **Gerçek App ID / ad unit ID: WAITING FOR CREDENTIAL**; AdMob konsolunda UMP mesajı: EXTERNAL |
| Türkçe / İngilizce (uygulama, API, bildirim, push, duyuru, web) | DONE | gen_l10n ARB + sözlük; Pixel dil testi |
| Public web `/en`, yasal sayfalar yeni tasarımda | DONE | `WebsiteLocalizationTest`; tarayıcı QA (8 genişlik, 0 taşma) |
| Operatör kimliği (unvan / adres / sicil / KVKK e-postası) | WAITING FOR EXTERNAL INFO | Yönetim → Ayarlar; eksikse production-check MISSING |
| Mağaza metni TR / EN, native yerelleştirme | DONE (doküman) | `docs/store/localization/` |

## 15 Kasım 2026 RC eki

| Madde | Durum |
|---|---|
| Kuyruk işçisi: `php artisan queue:work database --sleep=3 --tries=3 --timeout=90 --max-time=3600` (DeliverPush backoff 10/60/300 sn, MatchLocationPost 60 sn) | WAITING FOR EXTERNAL INFO (sunucu) |
| Cron: `* * * * * php artisan schedule:run` — tüm zamanlanmış komutlar `withoutOverlapping` (test: `QueueSchedulerTest`) | WAITING FOR EXTERNAL INFO (sunucu) |
| `failed_jobs` izleme + `php artisan queue:retry all` (push yeniden denemesi çift bildirim üretmez: `app_notifications.pushed_at`) | Kod hazır |
| Yeni migration'lar: `2026_11_16_090000_add_last_locale_to_users`, `2026_11_16_100000_add_pushed_at_to_notifications` (sıfırdan MySQL, rollback ve yeniden migrate denendi; seed yalnız şehir/ilgi alanı) | Kod hazır |
| `.env`: `PUSH_DRIVER=fcm`, `MINIMUM_AGE=16`, `NEARBY_POST_*`, `MESSAGE_LOCATION_GRID`, operatör bilgisi Admin → Ayarlar | `.env.example` güncel |
| AdMob kimlikleri, UMP mesajı, `app-ads.txt` | EXTERNAL REQUIRED |
