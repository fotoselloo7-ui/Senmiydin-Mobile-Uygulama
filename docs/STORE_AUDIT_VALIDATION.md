# Store submission denetimi — 9 Kasım 2026

Bu tur credential gerektirmeyen mağaza belgeleri ve gerçek kaynak/SDK denetimi tamamlandı. [Paket dizini](store/README.md), [gerçek bilgi listesi](store/REQUIRED_REAL_INFORMATION.md) ve [makine raporu](store/STORE_READINESS_REPORT.md) birlikte okunur. Mağazaya gönderim veya onay yapılmadı. Paket kimlikleri com.senmiydin.app ve sürüm/build 0.1.0+1 korundu.

## Değişiklik kapsamı

- Mevcut onboarding izin açıklaması cihaz konumu eyleminden önce görünür: sunucuya iletim, kullanım amacı, varsayılan kapalı geçmiş, ayrı bildirim tercihi, Android arka plan servisi ve iOS foreground-only sınırı açıklanır.
- Mevcut Geçtiğim Yerler açma onayı aynı ayrıntıları içerir; uzun metnin küçük ekranda okunabilmesi için confirmAction'a varsayılan kapalı scrollable seçeneği eklendi. Yeni ekran veya izin eklenmedi.
- Admin store URL doğrulaması HTTPS/host yanında doğru mağaza path/paket ve URL içinde kullanıcı/parola bulunmaması koşullarını uygular. Boş ayar ve Yakında davranışı korunur.
- Salt okunur tool/store_readiness_check.ps1, Python denetimi ve PHP veri/settings özeti eklendi. Mevcut release_check.ps1 değiştirilmedi. Denetim ortam ayarı, seed, reset, hesap oluşturma, gerçek credential veya store submission işlemi yapmaz.

Home, karşılaşma, mesajlaşma, konum-zaman ve Yolculuk motorları değiştirilmedi. Final logo, branding çıktısı, screenshot, video veya review hesabı üretilmedi.

## Doğrulama

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| Backend tam composer test | **104 geçti, 1271 assertion** | .local/store-composer-test.log |
| Flutter tam test | **60 geçti** | .local/store-flutter-test.log |
| Flutter analyze | **No issues found** | .local/store-flutter-analyze.log |
| Yeni uzun açıklama testi | 320×568, 2× yazı, scroll ve onay başarılı; son biçem düzeltmesinden sonra ayrıca geçti | test/location_disclosure_test.dart |
| Store URL yeni backend testi | Yanlış path/paket/embedded credential reddi; geçerli syntax ve boş Yakında korunur; 31 assertion | AdministrationTest |
| Store denetim mantığı | **5 Python testi geçti** | tool/test_store_readiness.py |
| Denetim syntax | Python compile, PHP lint ve PowerShell parser geçti | tool/store_readiness.py / store_backend_audit.php / store_readiness_check.ps1 |
| Android gerçek native audit | releaseRuntimeClasspath + processReleaseMainManifest: **BUILD SUCCESSFUL** | .local/store-android-dependencies.log |
| Yerel public GET | /gizlilik, /kvkk, /kullanim-kosullari, /topluluk-kurallari, /hesap-silme, /iletisim: **6/6 HTTP 200**; form gönderilmedi | Store readiness raporu |
| Boş store CTA | Render edilen sayfada boş href yok; Yakında span doğrulandı | Store readiness raporu |
| iOS kaynak manifest | **8 iOS/Darwin SDK manifesti**; tracking=false kaynak beyanları incelendi | SDK_AUDIT.md ve rapor envanteri |

Önceki 103/59 tabanı korunmuş, bir Laravel ve bir Flutter regresyon testi eklenmiştir. Son tam Flutter turundan sonra yalnız yeni testte string interpolation biçemi düzeltildi; ardından analyze ve o test tekrar geçti.

## Bulgular ve açık yayın kapıları

Denetim sonucu **MISSING: 56 READY, 6 WAITING, 29 MISSING, 0 FAIL**; script exit 2 beklenen dış yayın eksikleri sonucudur. Sayılar sonraki gerçek ortam değişikliklerinde yeniden üretilir.

- Hassas GPS cihazdan sunucuya iletilir; yaklaşık kullanıcı arayüzü yalnız coarse toplama beyanını haklı çıkarmaz. İki privacy matrisi precise/approximate kapsamını açıklar.
- Android background permission bulunmasa da kullanıcı açtığında foreground service arka planda sürebilir. iOS yalnız foreground örnekler. Yeni açıklama kodda vardır; final disclosure/video policy değerlendirmesi WAITING.
- Reklam/Ads ID, analytics engine, Crashlytics veya billing bulunmadı. Firebase measurement connector, Analytics motoru gibi raporlanmadı. FCM/Installations koşullu teknik verileri beyanlardan çıkarılmadı.
- Kaynak SDK manifesti archive doğrulaması değildir. Windows üzerinde iOS native dependency çözümlemesi, archive, SDK signatures veya Xcode Privacy Report yapılmadı; Mac doğrulaması WAITING.
- Legal route'lar çalışır; varsayılan/eksik legal CMS, gerçek support/privacy/işletmeci iletişimi, yayımlanmış CSAE standardı, gerçek çocuk güvenliği ihbar/yanıt operasyonu ve boş moderasyon listeleri MISSING kalır.
- Production log/query/yedek/support/audit saklama ve işlemci ilişkileri bilinmediği için silme ve privacy cevaplarının koşullu alanları açık kalır. Mesajlar E2EE değildir; admin yalnız şikâyetli hedef mesaj/görsele erişir; çevre sohbet penceresi veya görsel zararlı içerik sınıflandırıcısı var denmedi.
- Signing, provider/OAuth/SMTP, gerçek production sunucu ve admin, mağaza hesapları ve canlı URL doğrulamaları tamamlanmış sayılmaz. Yerel Demo kayıtları gerçek production verisi diye sunulmaz.
- Mevcut medya türevlerinde EXIF/GPS temizliği, kullanıcının orijinal yüklemesinin backend'e hiç iletilmediği anlamına gelmez.

## Önceki cihaz kanıtının sınırı

Pixel 6a'daki 9 gerçek API senaryosu ve otomatik disposable veri temizliği **önceki ürün/medya turunun kanıtıdır**; bu mağaza denetimi turunda yeniden çalıştırılmadı. Önceki APK hash'i ve normal Demo Home önizlemesi yeni izin metinlerini içeren bir APK kanıtı olarak kullanılmaz. Bu tur yeni APK kurulumu veya store screenshot çekimi yapılmadı. Önceki rapor [arşivde](test-history/validation-2026-11-09-before-store-audit.md) korunur.

Resmî politika kaynakları ilgili store belgelerinde her iddianın yanında bağlantılıdır. Gerçek form cevabı, son yayımlanacak build ve gerçek işletmeci/provider yapılandırması ile son kez karşılaştırılmalıdır.
