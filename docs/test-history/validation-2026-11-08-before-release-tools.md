# Doğrulama raporu — 7–8 Kasım 2026

Mevcut Flutter uygulaması, Laravel 12 API, public web ve admin paneli korunarak üretim hazırlıkları uygulandı. Home tasarımı değiştirilmedi. İlk arayüz raporu `test-history/validation-2026-11-05.md` altında korunur.

## Otomatik kontroller

| Kontrol | Sonuç | Kayıt |
|---|---|---|
| Laravel | 76 test, 923 assertion geçti | `.local/hardening-php.log` |
| Flutter | 36 test geçti | `.local/hardening-flutter.log` |
| Flutter analyze | Sorun bulunmadı | `.local/hardening-analyze.log` |
| Composer audit, production bağımlılıkları | Bilinen güvenlik bildirimi yok | `.local/composer-audit.log` |
| Mevcut MySQL | Yeni migrationlar uygulandı | Yerel migration çıktısı |
| Temiz MySQL 8.4 | Migration, production seed, tekrar migrate, son iki migration rollback / yeniden migrate geçti; yalnızca test için oluşturulan geçici DB kaldırıldı | `.local/mysql-migration-check.log` |
| Gerçek admin / web | Admin oturumu, moderasyon, şikâyet, sıralama, ayarlar, audit ve 12 public rota geçti | `.local/admin-live-check.log` |
| Yerel database queue | Hesap silme medya işleri tamamlandı; bekleyen medya temizliği kalmadı | `.local/local-queue-check.log` |
| Android release derleme | Dart AOT, Android ve R8 başarılı | `.local/release-compile.log` |
| İmzalı release AAB / APK | Gerçek keystore eksik olduğu için imzalama aşamasında durur | `.local/release-bundle.log`, `.local/release-apk.log` |

Yeni kontroller; HTTPS / proxy / CORS ve hata gizleme, production demo engeli, maintenance / sürüm politikası, gerçek parola ile hesap silme ve tekrar etkinleştirme engeli, dosya temizleme tekrarları, kilitli güncel parola kontrolü, Google / Apple JWT imzası ve audience doğrulaması, Apple nonce / kod değişimi / iptal kuyruğu, şifreli mail kuyruğu ve FCM oturum / tercih filtresini kapsar. OAuth testleri geçici test anahtarları ve sahte HTTP yanıtları kullanır; gerçek sağlayıcı hesabıyla giriş yapıldığı anlamına gelmez.

Flutter testleri mevcut küçük ekran / klavye / metin ölçeği kontrollerine ek olarak güvenli API adresi, hesap silme isteği, sürüm kapısı, bakım / güncelleme sırasında taslağın korunması, kayıt sonrası güncel profil görünümü, oturum bitince korumalı gezinme geçmişinin kaldırılması ve farklı gönderilerde fotoğraf sayfasının birbirine taşınmamasını kapsar.

## Pixel 6a

Pixel 6a (emulator-5558 / Pixel_6a) üzerinde integration_test/regression_test.dart içindeki beş gerçek API senaryosu aynı APK ile geçti. Kayıt: .local/pixel-full-regression.log, sonuç: +5 All tests passed.

1. Ekranlardan kayıt, profil / ilgi alanları, profil adı güncellemesi, güvenli oturum geri yükleme, çıkış / yeniden giriş ve yalnızca yeni test hesabının parola + SİL ile silinmesi; silinen hesabın yeniden girişi 401.
2. Akış, anonimlik, çoklu fotoğraf yükleme / kaydırma, beğeni / yorum / kaydet / takip / arama ve yeniden açılışta kalıcılık.
3. Android cihaz konumu, gerçek mesafe sıralaması, yakın akış, 5 / 10 km harita filtreleri, görünürlük ve konum geçmişi açma / kapatma.
4. Demo / Elif ile iki karşılaşma isteği, onay / red, yinelenen onayın aynı kaydı kullanması, iki fotoğraflı ortak hikâye, karşı taraf yayın onayı, öne çıkan kart ve akış görünümü.
5. Mevcut gerçek sohbet / fotoğraf / okundu geçmişi, engelleme, aramada / yakında gizleme, mesajın engellenmesi, engeli kaldırma, sohbeti sürdürme ve şikâyet.

Test bağlantısı bu bilgisayardaki emülatör ağında görülen zaman aşımını ayırmak için adb reverse tcp:8000 tcp:8000 ve API_BASE_URL=http://127.0.0.1:8000/api/v1 build define ile kullanıldı. Uygulamanın debug varsayılan adresi değişmedi. Yeniden kurulum sonrası yalnızca Pixel 6a'nın konum izinleri açıldı ve tool/set_demo_location.ps1 ile sentetik Alanya GPS kaydı tazelendi. Diğer açık Pixel 9'a dokunulmadı.

Bu turda galeri seçimi test adaptörüyle yerel gerçek JPEG dosyaları sağladı; dosyalar gerçek API'ye yüklendi. Native sistem galeri penceresi, arka planda hareket senaryosu, gerçek SMTP / FCM teslimatı ve gerçek Google / Apple hesabıyla giriş bu turun başarı kapsamına dahil değildir.

Cihaz testleri sırasında üç davranış hatası giderildi ve ayrı Flutter regresyonları eklendi: profil düzenledikten sonra eski adın görünmesi, çıkışta önceki Navigator geçmişinin korunması, galerinin başka gönderinin fotoğraf sayfasını geri yüklemesi. Home tasarımı korunur.

## Normal Android önizlemesi

Release kontrolünden sonra normal lib/main.dart hedefi debug olarak derlendi, Pixel 6a'ya yeniden kuruldu ve Demo hesabıyla gerçek API'ye giriş yapıldı. Debug varsayılanı http://10.0.2.2:8000/api/v1 ile çalışır. Ana sayfa, gerçek akış / ortak hikâyeler ve yakındaki kişiler (Ahmet 400 m dahil) yüklendi; uygulama cihazda açık bırakıldı. Tek seferlik emülatör test konumu yeniden istenirken GPS kaydı tazelendi.

APK: build/app/outputs/flutter-apk/app-debug.apk, 170.770.070 bayt. Paket com.senmiydin.app, versionName 0.1.0, versionCode 1; arm64-v8a / armeabi-v7a / x86_64 içerir. ZIP girdilerinde yinelenme yok, tek kernel_blob.bin var ve Android Debug imzası doğrulandı. SHA-256 ve build bilgileri [apk-checksum.json](apk-checksum.json); yalnızca bu bilgisayarın debug sertifika parmak izleri [android-debug-certificate.txt](android-debug-certificate.txt) içindedir. Bunlar production imzasının yerine kullanılmaz.

Son görüntü: [screenshots/pixel6a-current.png](screenshots/pixel6a-current.png). Masaüstü Computer Use aracının pencereyi öne getirme erişimi zaman aşımına uğradı; kurulum, giriş, ön plandaki Android Activity ve son ekran ADB üzerinden doğrulandı. Pixel 9'a dokunulmadı.

## Son release kontrolü

8 Kasım güncel ana hedefle standart Flutter appbundle / apk release komutları çalıştırıldı. İkisi de yalnızca gerçek key.properties / keystore eksikliğini bildiren korumada durdu; debug anahtarına geri düşülmedi. Aynı üretim API define ile :app:minifyReleaseWithR8 başarılı tamamlandı (285 task, 43 saniye). Dart AOT ve üç Android mimarisi derlendi. İmzalı mağaza AAB / APK'sı üretildiği iddia edilmez. Windows üzerinde iOS archive yapılmadı.

Güncel release manifesti com.senmiydin.app / 0.1.0 / 1 ve usesCleartextTraffic=false olarak doğrulandı. Kamera, geniş medya / depolama, ACCESS_BACKGROUND_LOCATION, biyometri veya parmak izi izni yok. Kayıt: .local/release-manifest-audit.json.

## Admin ve public web

Gerçek yerel MySQL üzerinde admin girişi, dashboard, kullanıcı askıya alma ve token iptali, geri açma, yalnızca yeni test paylaşımını kaldırma / geri açma, yeni şikâyeti sonuçlandırma, öne çıkan sıralaması, web CTA ayarı ve audit kaydı doğrulandı. Geçici ayarlar geri alındı ve yalnızca bu kontrolün oluşturduğu hesaplar gerçek silme servisiyle temizlendi.

Ana sayfa, nasıl çalışır, özellikler, güvenlik, iletişim, gizlilik, KVKK, kullanım koşulları, topluluk kuralları, hesap silme, sitemap ve robots çalışır. Tarayıcıda ana sayfa ve hesap silme sayfası 390 CSS piksel genişliğinde yatay taşma olmadan kontrol edildi. Markalı 404, admin dashboard ve yeni sürüm ayarları görüntülendi. 500 sayfası veritabanına bağımlı olmadan otomatik testte doğrulandı.

## Kimlik ve platform

- Android applicationId ve iOS bundle identifier: `com.senmiydin.app`.
- Sürüm: `0.1.0+1`; mevcut sürüm korunur.
- Release API varsayılanı: `https://senmiydin.com/api/v1`.
- Debug API varsayılanı: `http://10.0.2.2:8000/api/v1`; test için ayrı build define kullanılabilir.
- Release HTTP kapalı; debug yerel HTTP açık. Release signing debug anahtarına geri düşmez.
- Geniş medya, kamera, arka plan konum veya kullanılmayan biyometrik izin eklenmedi. Galeri sistem seçicisini, konum yalnızca mevcut akışın izinlerini kullanır.
- Mevcut geçici kalp işareti `assets/brand/mark.svg` altında tek kaynaktan kullanılır. Android legacy / adaptive ikon, native splash, 19 iOS ikon boyutu ve web görselleri üretildi; iOS ikonları opak RGB ve doğru boyutlarda kontrol edildi. Bu işaret resmî final logo olarak sunulmaz.
- iOS izin açıklamaları, Apple sign-in capability ve gerçek Google reverse-client-id için yerel yapılandırma hazır. Windows üzerinde iOS archive yapılmadı.

## Hesap silme

Mobil ayarlardaki işlem parola ve tam `SİL` onayı ister. Tüm tokenlar ve cihaz kayıtları iptal edilir; profil, konum, ilişkiler ve kişisel içerik temizlenir / anonimleştirilir. Dosya temizliği kalıcı outbox ve queue / scheduler ile tekrar denenir. Anonim ilişki kimlikleri ve moderasyon durumları korunur; silinen hesap admin tarafından geri açılamaz. Apple yetki iptali gerçek yapılandırma varsa iptal kuyruğuyla yürütülür.

Public hesap silme formu destek kaydı oluşturur; kimlik doğrulaması olmadan hesap silmez. Hukuk / KVKK içeriği ve saklama politikası işletmeci tarafından gerçek süreçlere göre tamamlanmalıdır.

## Yerel erişim

| Bileşen | Adres |
|---|---|
| Public web | http://127.0.0.1:8000/ |
| Admin girişi | http://127.0.0.1:8000/admin/login |
| MySQL | 127.0.0.1:33076 |

Yalnızca development ortamı için admin `admin@senmiydin.local / Admin1234!`; demo kullanıcılar `demo` ve `elifdemo`, parola `Demo1234!`. Production seed bu hesapları oluşturmaz ve yerel admin üretimde giriş yapamaz.

Yerel MySQL ilk açılışta Syncthing tarafından oluşturulmuş 196 çakışma kopyasının duplicate tablespace hatasıyla duruyordu. Sunucu kapalıyken yalnızca `*.sync-conflict-*` kopyaları doğrulanmış proje içi `.local/mysql-recovered-sync/20261107-144404` klasörüne taşındı. Asıl veritabanı dosyaları korunarak servis yeniden açıldı. Çalışan veritabanı ve üretilen build klasörleri dosya eşitlemesine alınmamalıdır.

## Gerçek yayın için eksik dış bilgiler

Kod ve kurulum hazırlığı, canlı sunucuya yayın yapıldığı veya dış servis teslimatının doğrulandığı anlamına gelmez.

- Android gerçek release keystore, alias ve parolaları; mağaza hesapları ve gerçek mağaza URL'leri.
- Firebase Android JSON / iOS plist, sunucu service account, FCM project; iOS için APNs ve Apple capability.
- SMTP host / port / kullanıcı / parola / gönderen ve gerçek destek adresi; DNS posta doğrulamaları.
- Google gerçek web / Android / iOS OAuth client ID'leri ve debug / release SHA kayıtları.
- Apple Team ID, Key ID, .p8, bundle / Service ID ve HTTPS callback kaydı.
- Gerçek sunucu erişimi, DNS, HTTPS sertifikası; queue worker, scheduler, yedekleme ve gözlem.
- İşletmeciye ait hukuk / gizlilik / saklama bilgileri ve onaylı final logo.

Tek kurulum belgesi: [DEPLOYMENT.md](DEPLOYMENT.md). Gerçek kimlik bilgisi, sertifika veya mağaza bağlantısı uydurulmadı.
