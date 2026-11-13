# Doğrulama raporu — 7–9 Kasım 2026

Mevcut Flutter uygulaması, Laravel 12 API, public web ve admin paneli korunarak üretim hazırlıkları uygulandı. Home tasarımı değiştirilmedi. İlk arayüz raporu `test-history/validation-2026-11-05.md` altında korunur.

## Otomatik kontroller

| Kontrol | Sonuç | Kayıt |
|---|---|---|
| Laravel | 95 test, 1167 assertion geçti | `.local/location-time-backend-all.log` |
| Flutter | 53 test geçti | `.local/location-time-flutter-all.log` |
| Pixel 6a | 8 gerçek API senaryosu geçti | `.local/pixel-release-regression.log` |
| Flutter analyze | Sorun bulunmadı | `.local/location-time-analyze-final.log` |
| Composer audit, production bağımlılıkları | Bilinen güvenlik bildirimi yok | `.local/composer-audit.log` |
| Mevcut MySQL | Yeni migrationlar uygulandı | Yerel migration çıktısı |
| Temiz MySQL 8.4 | Migration, production seed, tekrar migrate, son iki migration rollback / yeniden migrate geçti; yalnızca test için oluşturulan geçici DB kaldırıldı | `.local/location-time-mysql.log` |
| Gerçek admin / web | 8 admin bölümü ve 14 public rota/asset/bağlantı kontrolü geçti | `.local/location-time-admin-live.log`, `.local/location-time-public-web.log` |
| Yerel database queue | Hesap silme medya işleri tamamlandı; bekleyen medya temizliği kalmadı | `.local/location-time-queue.log` |
| Android release derleme | Dart AOT, Android ve R8 başarılı | `.local/location-time-r8.log` |
| İmzalı release AAB / APK | Gerçek keystore eksik olduğu için imzalama aşamasında durur | `.local/location-time-bundle.log`, `.local/location-time-apk.log` |

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

APK: build/app/outputs/flutter-apk/app-debug.apk, 170.798.510 bayt. Paket com.senmiydin.app, versionName 0.1.0, versionCode 1; arm64-v8a / armeabi-v7a / x86_64 içerir. ZIP girdilerinde yinelenme yok, tek kernel_blob.bin var ve Android Debug imzası doğrulandı. SHA-256 ve build bilgileri [apk-checksum.json](apk-checksum.json); yalnızca bu bilgisayarın debug sertifika parmak izleri [android-debug-certificate.txt](android-debug-certificate.txt) içindedir. Bunlar production imzasının yerine kullanılmaz.

Son görüntü: [screenshots/pixel6a-current.png](screenshots/pixel6a-current.png). Masaüstü Computer Use aracının pencereyi öne getirme erişimi zaman aşımına uğradı; kurulum, giriş, ön plandaki Android Activity ve son ekran ADB üzerinden doğrulandı. Pixel 9'a dokunulmadı.

## Son release kontrolü

9 Kasım güncel ana hedefle standart Flutter appbundle / apk release komutları çalıştırıldı. İkisi de yalnızca gerçek key.properties / keystore eksikliğini bildiren korumada durdu; debug anahtarına geri düşülmedi. Aynı üretim API define ile :app:minifyReleaseWithR8 başarılı tamamlandı (285 task, 50 saniye). Dart AOT ve üç Android mimarisi derlendi. İmzalı mağaza AAB / APK'sı üretildiği iddia edilmez. Windows üzerinde iOS archive yapılmadı.

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

## Release araçları turu — 8 Kasım 2026

Önceki 76 Laravel / 923 assertion, 36 Flutter ve beş Pixel senaryosu başarıları korunmuştur; önceki raporun tam kopyası test-history/validation-2026-11-08-before-release-tools.md altında saklanır. Bu turda son toplamlar 80 Laravel / 1025 assertion ve 42 Flutter testidir. Üç Python release-tool testi de geçti.

- app:check / senmiydin:production-check, credential değerleri olmadan 32 kontrol ve kategori üretir. Yerel geliştirme ortamında production env/HTTPS/session/servis/mağaza/hukuk/demo/sunucu kurulum bilgileri için MISSING beklenir. Bu bir kod testi hatası değildir.
- tool/release_check.ps1 tam olarak çalıştırıldı: Flutter environment/pub/analyze/test, Composer install/platform/test, migration, kimlik/HTTPS, demo guard, secret/ignore kontrolleri geçti. Çıkış 2: production configuration ve gerçek Android signing MISSING; teknik FAIL yok. Son 401 testi ayrıca tam Flutter paketinde 42/42 geçti.
- Composer lock metadata hash tutarsızlığı composer update --lock --no-install --no-scripts ile düzeltildi; paket sürümleri değiştirilmedi. Composer validate, platform ve install dry-run geçti.
- reports(status,id) ve users(account_status,city_id,id) yeni migration ile eklendi. Mevcut MySQL ve temiz MySQL production seed / migrate / rollback-reapply denemesi geçti. Sadece yeni oluşturulan geçici doğrulama DB'si kaldırıldı. Schema/EXPLAIN: .local/release-schema-audit.json.
- Polling artık route örtülünce ve foreground dışına çıkınca timer'ı iptal eder, dönüşte yeniler, duplicate request üretmez ve ağ hatasında 120 saniyeye kadar backoff uygular. POST için kör retry yok. Background history kapatma ve 401 token temizliği regresyonları korundu.
- Yalnızca public kataloglar kısa cache kullanır; admin değişikliği cache'i invalid eder. Özel kullanıcı verisi shared cache'e alınmaz.
- /health yalnızca küçük durum yanıtı üretir; veritabanı/cache bilgisi, host/path/credential açığa çıkarmaz. Stale cihaz temizliği ve scheduler overlap korumaları eklendi.
- Secret scanner gerçek ignore kurallarını izole Git deposunda doğrular; kaynakta .git bulunmadığından tracked-file denetimi false olarak açıkça raporlanır. Source/ZIP içinde credential değeri çıktısı yok. ZIP sızıntısı reddi ve path kontrolleri için Python testleri geçti.
- Ana vendor'sız ve alternatif izole --no-dev vendor ZIP'leri üretildi. İkisi de allowlist/secret denetimini geçti. Vendor ZIP .env veya kullanıcı verisi taşımadan geçici alanda Laravel bootstrap yaptı ve 103 rota yüklendi. Arşiv SHA-256 / boyut bilgileri dist içindeki ayrı audit JSON dosyalarındadır.
- Final branding helper gerçek kare ve yatay SVG verilmeden REFUSE etti; mevcut markanın hash'i değişmedi. Gerçek keystore oluşturulmadı; signing helper'ın eksik anahtarda güvenli durduğu doğrulandı.
- Admin sekiz bölüm, dashboard, kullanıcı suspend/restore ve token iptali, post ve yorum kaldırma/geri açma, report, featured, system settings, aynı legal CMS içeriğini kaydetme ve audit gerçek yerel DB ile geçti. Sadece yeni disposable test hesapları silindi; ayarlar/sıralama geri alındı.
- Public crawler 14 rota/asset/iç bağlantı ve health kontrolünü geçti. Native tasarım ve public CSS korunur; fake store link/count/rating eklenmedi.
- tool/run_pixel_regression.ps1 mevcut beş gerçek API senaryosunu Pixel_6a üzerinde çalıştırdı: +5 All tests passed, 4 dakika 44 saniye. Konum/izin hazırlığı script tarafından yapıldı; Pixel 9'a dokunulmadı. Galeri dosyaları yine test adaptörüyle gerçek API'ye yüklendi; canlı provider teslimatı iddiası yok.
- İlk cihaz derlemesi makinede yaklaşık 306 MB boş RAM varken JVM native-memory hatasıyla durdu. Projeye özel Gradle 4 GB heap / 1 GB metaspace / 2 worker sınırı sonrası build ve beş cihaz testi geçti. Başka projelerin süreçleri kapatılmadı.
- Son disposable silmelerin database queue işleri çalıştırıldı; bekleyen medya temizliği 0.

Belgeler: DEPLOYMENT.md, RELEASE_AUDIT.md, STORE_READINESS.md, PRODUCTION_CHECKLIST.md. Dış credential / final brand / gerçek sunucu / Mac bağımlılıkları bu belgelerde ayrı tutulur.

Son normal önizleme yeniden doğrulandı: lib/main.dart debug APK, 170.798.510 bayt; SHA-256 E8B49EDF389D234099ADFE224B6AD172ECD170FF81E649E8D9A5F0C0F8F50DFC. Android Debug imzası ve tek kernel_blob.bin kontrolü geçti. Pixel_6a üzerinde Demo Ana Sayfa, akış ve 100 m / 400 m yakın kullanıcılar yüklendi; son ekran docs/screenshots/pixel6a-current.png olarak yenilendi. Normal uygulama açık bırakıldı. Son release manifesti tekrar denetlendi; cleartext false, gereksiz geniş medya/kamera/background-location izinleri yok. Vendor arşivinin son sürümü de izole bootstrap kontrolünde 103 rotayla geçti.

## Aktif şehir, konum-zaman ve Yolculuk — 8–9 Kasım 2026

Önceki rapor docs/test-history/validation-2026-11-08-before-location-time.md altında korunur. Mevcut 80 Laravel / 42 Flutter testi korunarak toplam 95 Laravel / 1167 assertion ve 53 Flutter testine ulaşıldı. Son Flutter analyze temizdir. PHP testleri Composer test ile çalıştırıldı; kayıtlar üst tablodadır.

- Profil şehri ile aktif şehir users.active_city_id / active_city_source ile ayrıldı. Offline CityResolver, 81 il ve Alanya sınırını mevcut 82 şehir kataloğuna eşler. Belirsiz sonuçta koordinat korunur; manuel şehir fallback sunulur. Harici geocoding credential veya çağrı gerekmez. Kaynak/lisans: backend/resources/geography/README.md.
- Manuel şehir, GPS izni olmayan oturum geri yüklemesinde korunur; cihaz şehri güvenilir şekilde çözüldüğünde aktif şehir yenilenir, profil şehri değişmez. Bu son durum ayrı Flutter ve backend regresyonlarıyla doğrulandı.
- Yeni migration occurred_at, güvenli bölge etiketi, post_travel_details ve match score/time difference/notification state alanlarını ekledi. Eski migrationlar korunur. Mevcut MySQL'e uygulandı; ayrı temiz MySQL'de production seed, rollback ve yeniden migrate geçti. Yeni hash indeksi rollback sırasında gereken foreign-key lookup indeksini korur. Kayıt: .local/location-time-mysql.log.
- Gülhane backend senaryosu: Elif 14:15–14:30, olay 14:20, yayın 20:00 (Europe/Istanbul). Kendi geçmiş yerinden oluşturulan post doğru UTC occurred_at ve yaklaşık bölgeyle kaydoldu; güçlü location_matches kaydı, feed boost ve tek in-app bildirim oluştu. Aynı job tekrarında match/bildirim çoğalmadı. Exact history koordinatı, ham GPS ve eşleşen geçmiş saati public response'a eklenmedi.
- Zayıf/orta/güçlü eşikler merkezi config'tedir. SQL şehir/zaman/bounding-box filtresi ve ROW_NUMBER ile kullanıcı başına en iyi geçmiş örneğini seçer; tüm history PHP belleğine alınmaz. History kapalı/engelli/silinmiş/private durumları elenir. Eşleşme şehir görünürlüğünü kısıtlamaz ve otomatik Karşılaşıldı işareti üretmez.
- History toplama izni ile location_match bildirimi ayrı tercihlerdir; nearby_activity ayrı kalır. History açık/bildirim kapalı durumda öneri kullanılabilir, yeni in-app/push oluşmaz. Push eksikken gerçek Inbox kaydı ve bildirime dokunarak gönderiye geçiş doğrulandı; canlı FCM teslimatı iddiası yoktur.
- Pamukkale backend senaryosu Ankara → Erzincan, Otobüs, 19:30 ve 07 NM 365 alanlarıyla geçti. Kalkış/varış şehri ve zaman örtüşmesi orta öneri üretir; mesafe bilinmediğinde null tutulur. Katılım/grup/havuz yoktur. Private travel detayları sahibi/yetkili admin dışına çıkmaz; public olması açık kullanıcı tercihidir.
- EXIF/GPS içeren sentetik JPEG fixture post/avatar/message/ortak hikâye upload akışlarında decode/re-encode edildi. Dört final medya yanıtında EXIF/private marker kalmadı ve JPEG decode geçti. Orijinal cihaz dosya adı URL'ye taşınmadı. Bozuk JPEG, executable, SVG ve double extension reddi testleri geçti.
- ContentGuard normalleştirilmiş tekrar hash'i, tekrar penceresi, aşırı mention/link, admin kelime/domain listesi ve subdomain kontrolü uygular. Idempotent request_id tekrarları yeni post oluşturmaz. Masum uzun sözcükler ve farklı domainler yanlış substring eşleşmesiyle reddedilmez. Mevcut admin tasarımı içinde listeler/eşikler ve travel moderasyon detayı bulunur.
- Ağ kapanışında aktif istek tamamlanmadan native HTTP transport kapatılmaz; dispose edilmiş store'a gelen unread/config/location yanıtları state'i güncellemez. İki ayrı regresyon bu kapanış durumlarını doğrular.
- Pixel_6a tam tekrar: mevcut beş senaryo + üç özel senaryo = +8 All tests passed, 6 dakika 17 saniye. Kayıt: .local/pixel-release-regression.log; helper: .local/location-time-pixel-final-script.log. Diğer emülatör değiştirilmedi.
- Pixel A: gerçek Android konum API'sine emülatör GPS'iyle Ankara noktası verildi; aktif şehir Ankara, profil Alanya kaldı; GPS Alanya'ya alınınca aktif şehir geri döndü.
- Pixel B: sahipliği doğrulanmış disposable geçmiş fixture'ından İstanbul bölgesi ve geçmiş saat seçilerek gerçek compose/API postu oluşturuldu; match, boost ve tek bildirim doğrulandı, bildirim doğru gönderiyi açtı. Sabit 14:20 doğrulaması backend testindedir; cihazda göreli geçmiş saat kullanıldı.
- Pixel C: Pamukkale Ankara → Erzincan / 07 NM 365 gerçek API ile kaydedildi, ikinci test kullanıcısında öneri sinyali ve kartın firma/güzergâh/araç bilgisi görüldü. Cihazda fixture'ın güncel yaklaşık kalkış saati kullanıldı; sabit 19:30 backend testindedir.
- İlk özel cihaz denemesinde testin korumalı başlangıç rotasını atlaması düzeltildi; normal Ana Sayfa gezinmesi kullanıldı. Bağlantı kapanış regresyonu da giderildikten sonra sekiz senaryo birlikte geçti. İlk denemenin hata kaydı .local/location-time-pixel-first-attempt.log altında saklanır.
- tool/location_scenarios.php yalnızca bu projenin local/development MySQL'inde çalışır; production'da reddeder. Parolalar rastgele ve ignored .local içinde kalır. Test sonunda yalnızca bu araca ait doğrulanmış iki hesap ve travel/history verisi gerçek silme servisiyle temizlendi; Demo hesabı silinmedi. Son medya cleanup kuyruğunda kalan kayıt 0.
- Gerçek admin sekiz bölüm/ayarlarda ve public crawler 14 rota/asset/bağlantıda geçti. Health OK. Kayıtlar: .local/location-time-admin-live.log, .local/location-time-public-web.log. Onaylı Home ve mavi/lacivert/beyaz tasarım korunur.
- Release helper tam çalıştırıldı: teknik FAIL yok, gerçek production ayarları ve Android signing MISSING / çıkış 2. Son manuel şehir regresyonundan önce helper 52 Flutter / 95 Laravel testini geçti; son tam Flutter paketi ayrıca 53/53, Composer 95/95 geçti. Yeni DB tablo/alan ve ROW_NUMBER desteği production-check tarafından da doğrulanır.
- Secretsiz ana ve vendor alternatif backend ZIP'leri yenilendi; yeni migration, kaynak/lisans atfıyla offline sınır verisi, queue işi ve LOCATION_TIME_TRAVEL.md dahildir. Vendor ZIP izole bootstrap'ta 105 rota yükledi; .env veya kullanıcı verisi kopyalanmadı. Güncel SHA-256/byte bilgileri dist audit JSON dosyalarındadır. Python release-tool testleri 3/3 geçti.

Güncel ürün davranışı SENMIYDIN_URUN_TANIMI.md ve docs/LOCATION_TIME_TRAVEL.md ile eşleşir. Store/production belgeleri güncellendi; mevcut release, HTTPS, signing, admin ve public web altyapısı korundu.

9 Kasım son Android kontrolü: güncel lib/main.dart ile standart appbundle/apk release akışları yalnızca gerçek imza eksikliğinde durdu; aynı üretim API adresiyle :app:minifyReleaseWithR8 285 task / 50 saniyede başarılı oldu. İmzalı mağaza paketi üretilmedi. Kayıtlar .local/location-time-bundle.log, .local/location-time-apk.log, .local/location-time-r8.log.

Son normal önizleme 9 Kasım'da yenilendi: lib/main.dart debug APK 170.798.510 bayt, SHA-256 E8B49EDF389D234099ADFE224B6AD172ECD170FF81E649E8D9A5F0C0F8F50DFC. ZIP girdilerinde duplicate yok, tek kernel_blob.bin var; Android Debug imzası ve com.senmiydin.app / 0.1.0+1 / minSdk24 / targetSdk36 doğrulandı. Release manifestinde cleartext false; kamera, geniş depolama ve background-location izni eklenmedi. Normal debug varsayılanı 10.0.2.2 üzerinden Demo oturumu, Alanya akışı, ortak hikâyeler ve 100 m / 400 m yakın kullanıcılar yüklendi. Normal uygulama Pixel_6a'da Ana Sayfa açık bırakıldı; docs/screenshots/pixel6a-current.png, docs/apk-checksum.json ve docs/android-debug-certificate.txt günceldir. Yanıt vermeyen eski yerel PHP süreci yalnızca bu projeye ait olduğu doğrulanarak yeniden başlatıldı; health OK.

Son production-check: 32 kontrol, 12 OK / 20 MISSING / 0 ERROR; gerçek production ayarları ve dış credential sağlanmadığından ready=false beklenir. Kaynak secret/ignore denetimi OK; tracked-file kontrolü .git olmadığı için false olarak raporlanır. Backend ana ZIP 983.370 bayt (SHA-256 8b0cf4b54dcbf15f5c5862bf4213e16888f885b80a37690c786617c262c8e695), vendor ZIP 8.787.307 bayt (b96a4f9fa2f2f3f07f6c08fbcc7d1f79a962b7eb3b84aa44d22a1b0bb8a31144); ikisinin audit sonucu OK ve vendor bootstrap 105 rotadır.
