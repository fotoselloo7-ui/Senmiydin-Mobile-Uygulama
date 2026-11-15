# SenMiydin? deployment

Public web, ayrı admin oturumu ve mobil API tek Laravel uygulamasıdır. Hedef web adresi https://senmiydin.tr, API adresi https://senmiydin.tr/api/v1 olur. Ayrı bir API alan adı gerekmez. Bu belge sunucu kurulumu içindir; alan adı veya sertifikanın bu bilgisayardan canlıya alındığı anlamına gelmez.

## Sunucu

- PHP 8.2 veya üzeri, Composer 2; PHP CLI ve PHP-FPM aynı sürüm / eklentileri kullanmalı.
- PDO MySQL, OpenSSL, mbstring, tokenizer, XML / DOM, ctype, fileinfo, GD (JPEG / PNG / WebP), curl ve zip; Laravel'in standart PHP gereksinimleri.
- MySQL 8 veya Laravel 12 ile uyumlu, window function (ROW_NUMBER) destekli MariaDB; utf8mb4. Konum SQL sorgularını yayın öncesi seçilen sunucuda doğrula. Bu projede MySQL 8.4 üzerinde temiz migration ve tekrar çalıştırma kontrol edilir.
- Nginx veya Apache, HTTPS sertifikası ve yenilemesi, process supervisor / systemd, cron.
- Android build için Flutter SDK, JDK 17+ ve Android SDK / NDK. Pubspec sürümü tek kaynaktır: şu anda 0.1.0+1. iOS archive için macOS / Xcode gerekir.
- Redis zorunlu değildir. Database cache, queue ve session desteklenir.

Sunucunun belge kökü yalnızca backend/public olmalı. Proje kökü, .env, storage, .git, yedekler ve Firebase / Apple anahtarları webden erişilememeli. storage ve bootstrap/cache yalnızca uygulama kullanıcısına yazılabilir olsun. Private diskleri public/storage sembolik bağlantısıyla yayınlama.

Örnek Nginx uygulama bölümü, sunucu yollarını ve PHP soketini kendi kurulumuna göre ayarlayarak kullanılır:

~~~nginx
server {
    listen 80;
    server_name senmiydin.tr;
    return 308 https://senmiydin.tr$request_uri;
}
server {
    listen 443 ssl;
    server_name senmiydin.tr;
    # ssl_certificate / ssl_certificate_key: gerçek sertifika yolları.
    root /srv/senmiydin/current/backend/public;
    index index.php;
    client_max_body_size 55m;

    location / { try_files $uri $uri/ /index.php?$query_string; }
    location ~ ^/index\.php(/|$) {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }
    location ~ \.php$ { deny all; }
    location ~ /\.(?!well-known).* { deny all; }
    location ^~ /storage/ { deny all; }
}
~~~

Örnekte sertifika satırları doldurulmadan HTTPS sunucusu başlamaz. PHP upload_max_filesize=5M, post_max_size en az 55M; nginx limiti aynı toplamı karşılamalı. PHP display_errors=Off ve zend.exception_ignore_args=On kullan.

## Ortam ve ilk kurulum

backend/.env.example üretim varsayılanlarını içerir. Gerçek değerleri secret manager veya sunucuya özel, erişimi sınırlı .env içinde tut. Anahtarları komut satırı argümanlarına, repository'ye, mobil JSON dosyasına veya loglara yazma.

~~~bash
cd backend
composer install --no-dev --prefer-dist --optimize-autoloader
cp .env.example .env
# Gerçek ortam değerlerini güvenli yöntemle yerleştir.
php artisan key:generate --force
php artisan migrate --force --seed
php artisan admin:create yonetici@gercek-alan-adiniz
php artisan app:check
php artisan config:cache
php artisan route:cache
php artisan view:cache
~~~

key:generate yalnızca ilk kurulumda çalışır. Mevcut APP_KEY'yi yeniden üretme; push ve Apple tokenları, kuyruk verileri ve session kayıtları bu anahtarla şifrelenir. APP_KEY'yi ayrı ve güvenli şekilde yedekle.

Üretimde APP_ENV=production, APP_DEBUG=false, APP_URL ve PUBLIC_SITE_URL=https://senmiydin.tr olmalı. Kod üretimde debug yanıtlarını kapatır. Uygulama kullanıcısına kendi veritabanının gerekli tablo izinlerini ver; global kullanıcı/veritabanı yönetim yetkisi verme. Veritabanını altyapı yöneticisi oluşturur.

app:check secret değerlerini yazdırmadan HTTPS, oturum, kuyruk, özel diskler, SMTP / destek, CORS, push ve demo hesap durumunu kontrol eder. Bu kontrol işlevsel e-posta / push teslimatının yerini tutmaz. Eksik gerçek hizmet bilgilerini tamamlayıp yeniden çalıştır.

Normal DatabaseSeeder yalnızca şehir ve ilgi alanı kataloglarını yükler. DemoDataSeeder ve DevelopmentAdminSeeder üretimi reddeder. Demo veritabanını üretime kopyalama. Development admin üretimde giriş yapamaz.

## HTTPS, proxy ve oturum

TLS sonlandıran proxy varsa yalnızca gerçek proxy IP / CIDR adreslerini TRUSTED_PROXIES listesine ekle; varsayılan boş listedir. Public origin proxy arkasındaysa doğrudan internete erişimini kapat. X-Forwarded-Proto / For / Port sadece bu adreslerden kabul edilir; Host başlığının production APP_URL ile eşleşmesi gerekir.

HTTP web GET istekleri sabit HTTPS adrese yönlendirilir; HTTP API / yazma istekleri reddedilir. API istemcileri ilk isteği de HTTPS ile göndermeli. APP_URL yanlışlıkla HTTP yapılırsa production servis güvenli biçimde kapanır. HSTS uygulanır; alt alan adları için ayrıca gereksiz zorunluluk eklenmez.

SESSION_DRIVER=database, SESSION_SECURE_COOKIE=true, SESSION_HTTP_ONLY=true, SESSION_ENCRYPT=true ve SESSION_SAME_SITE=lax kullan. Session domain boş kalarak host ile sınırlı olur. Admin CSRF korumalı ayrı guard kullanır. Apple'ın yalnızca /auth/apple/callback POST dönüşü CSRF dışında bırakılır; onun state ve sunucu nonce kontrolleri ayrıdır.

CORS_ALLOWED_ORIGINS sadece gerçek web originlerini içermeli. Mobil bearer token akışı çerezli SPA değildir; CORS supports_credentials=false kalır. SANCTUM_EXPIRATION dakika cinsindendir. Süresiz token kullanmak yerine mevcut 43200 dakika sınırını ve günlük temizliği koru.

## Diskler ve görseller

AVATAR_DISK=local, POST_MEDIA_DISK=local ve FILESYSTEM_DISK=local varsayılan özel disk kullanır. Avatarlar uygulama rotasından; post ve mesaj görselleri yetkili API rotalarından sunulur. Silinen / moderasyonda kaldırılan kayda ait medya erişimi kapanır. Avatar rotası aktif hesap referansı olmadan dosya sunmaz ve cache tutmaz.

Yüklemelerde MIME, uzantı, gerçek görsel, 5 MB ve 2048 piksel sınırı vardır. JPEG yeniden kodlaması özgün EXIF / gömülü ek verileri taşımaz. Gereksiz ek medya işleme servisi kurulmadı.

S3 gibi özel disk için Laravel Flysystem adaptörünü ve sunucu IAM izinlerini ayrıca kur; bucket / nesneler public olmamalı. Mevcut verisi olan bir sistemde disk değiştirirken avatarları ve mesaj dosyalarını yeni diske kopyala, doğrula, sonra config'i değiştir. Post medya satırları kendi disk bilgisini tutar; bunları kontrollü migration ile güncelle. Eski public kopyaları ve public/storage erişimini geçiş tamamlanınca kapat. Yerel çalışan örneklerin diskini körlemesine değiştirme.

## Queue ve scheduler

Üretimde QUEUE_CONNECTION=database ve CACHE_STORE=database yeterlidir. Redis alternatif olabilir. Push teslimatı ve hesap silme medya işi mevcut database kuyruğunu kullanır. Mail işleri varsayılan kuyruğa gönderilir; kuyruk payload'ları şifrelenir.

Supervisor / systemd üzerinden yeniden başlatılan worker:

~~~bash
php artisan queue:work database --sleep=3 --tries=3 --timeout=90 --max-time=3600
~~~

QUEUE_CONNECTION=redis seçilirse mail için ayrıca redis worker çalıştır. Worker ve PHP aynı APP_KEY / .env / release dizinini kullanmalı. DB queue retry_after değeri timeout'tan büyük olmalı; örnek yapılandırmada DB_QUEUE_RETRY_AFTER=120, worker timeout=90 kullanılır.

Dakikada bir cron:

~~~cron
* * * * * cd /srv/senmiydin/current/backend && php artisan schedule:run >> /dev/null 2>&1
~~~

Zamanlayıcı Sanctum token temizliği, konum geçmişi saklama, eski silinmiş post dosyaları, duyurular, hesap silme medya temizliği ve Apple yetki iptalini yürütür. media:cleanup ve oauth:revoke-deleted başarısız kayıtları sonraki çalıştırmaya bırakır. posts:purge-deleted normal kullanıcı silmelerinden 30 gün sonra fiziksel temizlik yapar; moderasyonla tutulan postları otomatik silmez.

Worker ve scheduler durumunu, failed_jobs tablosunu, media_deletions ve oauth_revocations birikimini izle. Hatalarda secret/token içeren response body yazdırma. İş bitince queue:restart ile worker'ları yeni sürüme geçir.

## Hesap silme ve veri politikası

Mobil Profil → Ayarlar → Hesabımı Sil, mevcut şifre ve SİL onayı ister. DELETE /api/v1/auth/account aktif Sanctum oturumu ve hız sınırı kullanır.

İşlemde profil anonimleştirilir; tüm auth tokenları, cihaz kayıtları, konum ve geçmiş, takip/ilgi/kişisel bildirim kayıtları temizlenir. Kullanıcının post, yorum ve mesaj metinleri boşaltılır; medya referansları erişime kapanır. Ortak karşılaşmanın onayı ve sohbet erişimi kapanır. Yabancı anahtarları bozmamak için anonim kullanıcı ve ilişki kimlikleri kalır. Silinen hesabı admin yeniden açamaz.

Fiziksel dosya silme DB outbox + queue ile yeniden denenir; worker yoksa scheduler en geç bir sonraki 10 dakikalık çalışmada dener. Altyapı hatası varsa bu süre uzar; operator birikimi izlemelidir. Apple refresh tokenları şifreli iptal kuyruğuna aktarılır ve provider tarafından iptal edildikten sonra bu kayıt da kaldırılır.

Başka kullanıcıların kendi metinleri, sınırlı admin denetim notları ve şikâyetlerin durum/hedef kimlikleri toplu olarak silinmez. Silen kullanıcının şikâyet açıklamaları temizlenir. Destek kayıtları ve yedekler ayrı yönetilir. Bu teknik davranışı gerçek hukuki dayanak, sorumlu kişi, destek kayıtları / yedek / moderasyon saklama süreleriyle hukuk metinlerinde tamamla; hukuki zorunluluk veya şirket bilgisi uydurulmadı.

Public /hesap-silme formu hesap silmez; destek kaydı oluşturur. Ekip kimliği doğrulayarak talebi yürütür. Mobil ve public hukuk metinleri aynı legal CMS içeriğinden okunur.

## SMTP

MAIL_MAILER=smtp, gerçek MAIL_HOST, MAIL_PORT, MAIL_SCHEME, kullanıcı/parola ve MAIL_FROM_ADDRESS tanımla. 465 için smtps; sağlayıcının STARTTLS ayarlarını kendi belgesine göre kullan. SPF / DKIM / DMARC ve gönderici adresi doğrulamasını sağlayıcıda tamamla.

Şifre sıfırlama, şifre değişikliği güvenlik mesajları ve iletişim formunun destek bildirimi kuyruk üzerinden gider. İletişim mailinde özel form metni yerine yalnızca talep numarası ve admin bağlantısı yer alır. Admin Ayarlar → Destek e-postasını gerçek adresle doldur.

Üretimde şifre sıfırlama kodu log / array mailer'a gönderilmez. Local MAIL_MAILER=log akışı korunur. Gerçek SMTP gelince gerçek posta kutusuna teslimat ve spam klasörü kontrolü gerekir.

## Firebase ve push

Sunucu: PUSH_DRIVER=fcm, FCM_PROJECT_ID, FCM_CREDENTIALS=/secret/absolute/service-account.json. Hizmet hesabını web kökü ve repository dışında tut. HTTP v1 API ve en az gerekli gönderim yetkisini Google Cloud'da etkinleştir. Erişim tokenı şifreli cache'de, cihaz tokenları şifreli DB alanlarında tutulur. Geçersiz FCM tokenı pasifleştirilir; geçerli oturumu kalmayan cihaza gönderilmez.

Credential yokken PUSH_DRIVER=log veya null kullanılır; uygulama içi bildirimler çalışır. Log sürücüsü cihaz tokenı, mesaj metni veya kesin konum yazmaz. Canlı push'un çalıştığı bu modda iddia edilmez.

Gerçek Android google-services.json ve iOS GoogleService-Info.plist gelince mobil define dosyasını üret:

~~~powershell
python tool/configure_mobile.py --android C:/secret/google-services.json --ios C:/secret/GoogleService-Info.plist
~~~

Çıktı config/production.local.json gitignore içindedir. Bu dosya Firebase'in mobil public uygulama kimliklerini içerir; sunucu hizmet hesabını içermez. Android native receiver kaynakları Gradle tarafından bu define'larla oluşturulur. Firebase FlutterOptions kullanıldığı için sahte GoogleServices dosyası veya kontrolsüz native otomatik init gerekmez.

iOS plist'i ayrıca Xcode Runner target'ına gerçek dosya olarak ekle; APNs yetkili profil ve Firebase'de gerçek APNs .p8 / Key ID / Team ID gerekir. Bunları mobil JSON içine koyma. İlk izin, ön plan / arka plan / kapalı uygulama açılışı ve yanlış hesaba ait bildirimin açılmaması gerçek cihazda kontrol edilmelidir.

Yönlendirme sunucudaki yetkili notification kaydını yeniden okuyarak yapılır. Mesaj / istek sohbeti, karşılaşma istek/onay/hikâye ekranı, beğeni postu, yorumlar, takip profili, yakın aktivite postu ve sistem duyuruları mevcut rotaları kullanır.

## Google OAuth

Google Cloud'da Android OAuth istemcisi için com.senmiydin.app ve gerçek Play App Signing SHA-1 / SHA-256 parmak izlerini kaydet. Yerel debug ve release upload anahtarı gerekiyorsa ayrı doğrula. Mobil GOOGLE_WEB_CLIENT_ID backend ID token audience'ıdır. iOS için gerçek GOOGLE_IOS_CLIENT_ID ve onun reverse client ID URL scheme'i gerekir; ios/Flutter/OAuth.xcconfig.example bunun yeridir.

Backend GOOGLE_CLIENT_IDS virgülle ayrılmış gerçek kabul edilen audience listesidir. Mobil config'e gerçek Google istemci kimliklerini ekle. Tokenın RSA imzası, issuer, audience, zamanı ve subject'i sunucuda doğrulanır. Sadece eşleşen e-posta nedeniyle mevcut parola hesabı otomatik bağlanmaz. Yeni sosyal hesap aynı yaş, koşul, kullanıcı adı ve yedek parola doğrulamasından geçer; bu parola hesap silme için de kullanılır.

Gerçek OAuth istemcileri yokken düğmeler e-posta ile giriş seçeneğine yönlendirir. Hesap seçimi ve canlı sağlayıcı girişi credentials gelmeden doğrulanmış sayılmaz.

## Apple Sign In

Apple Developer'da com.senmiydin.app App ID, Sign in with Apple capability ve doğru Team / provisioning profili gerekir. Backend APPLE_CLIENT_IDS kabul edilen App ID ve gerekiyorsa Service ID listesidir. APPLE_TEAM_ID, APPLE_KEY_ID ve APPLE_PRIVATE_KEY_PATH gerçek .p8 anahtarını gösterir.

Mobil APPLE_SIGN_IN_ENABLED=true yalnızca gerçek yapılandırma tamamlanınca eklenir. Android web akışı için ayrıca gerçek APPLE_SERVICE_ID ve APPLE_REDIRECT_URI=https://senmiydin.tr/auth/apple/callback gerekir. Bu HTTPS dönüş adresini Apple portalında Service ID'ye kaydet. Android paketli intent dönüşü hazırdır; keyfi bir dönüş adresi kabul edilmez. Callback state sunucu nonce kaydına bağlıdır; uygulama hem state hem kimlik tokenını kontrol eder.

iOS native akışında Service ID gerekmez. Apple authorization code sunucuda gerçek istemci kimliğiyle değiştirilir, JWT / nonce yeniden doğrulanır, refresh token şifrelenir. Hesap silinince auth/revoke çağrısı yeniden denenebilir. Apple private relay adreslerine mail için gönderici domainini Apple'da da yapılandır.

Windows üzerinde Apple portalı, gerçek hesap girişi, APNs ve iOS archive doğrulanamaz. Bunlar gerçek Apple kimlikleri ve Mac üzerinde son kontrol gerektirir.

## Android build ve imzalama

Android applicationId / namespace: com.senmiydin.app. Görünen ad SenMiydin?. Android release HTTP'yi yasaklar; debug yerel emülatör API'sine bağlanabilir. Merkezi API adresi config/production.json / API_BASE_URL ile seçilir.

android/key.properties.example dosyasını android/key.properties olarak kopyalayıp gerçek upload keystore yolunu ve parolalarını güvenli şekilde doldur. Keystore ve key.properties version control dışında kalır. Release yapılandırması hiçbir zaman debug anahtarına düşmez; anahtar eksikse açıklayıcı hata verir. Mevcut anahtar bulunmadığından burada yeni bir gerçek yayın anahtarı üretilmedi.

~~~powershell
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --dart-define-from-file=config/production.json
flutter build apk --release --dart-define-from-file=config/production.json
~~~

Bu bilgisayarın doğrulanmış debug sertifika SHA-1 / SHA-256 değerleri docs/android-debug-certificate.txt içindedir; Google Cloud debug istemci kaydında kullanılabilir. Production için gerçek upload ve Play App Signing sertifikalarının parmak izlerini ayrıca al.

Firebase / OAuth için gerçek define'lar hazırlandığında son iki komutta config/production.local.json kullan. Parola / service account / .p8 / SMTP credential'ı Flutter define'larına koyma.

Google Play App Signing kaydı, upload key saklama, store form bilgileri ve gerçek cihaz release kontrolü yayın hesabında tamamlanır. Bildirim izni, kamera intent'i ve sistem fotoğraf seçici için gereksiz depolama / kamera izinleri eklenmedi. Güvenli depolama paketinin eklediği, uygulamada kullanılmayan biyometri / parmak izi izinleri manifest birleşiminden çıkarıldı. Android geçmiş kaydı yalnızca opt-in, görünür foreground konum servisiyle sürer; ACCESS_BACKGROUND_LOCATION talep edilmez.

## iOS build

Bundle ID com.senmiydin.app, ad SenMiydin?, sürüm / build pubspec'ten gelir. Info.plist konum, fotoğraf ve kamera kullanım amaçlarını açıklar. iOS background location eklenmedi; APNs remote-notification ve Sign in with Apple entitlement hazırlanmıştır.

Mac üzerinde gerçek Team ve yetkili profille Xcode Signing & Capabilities'i tamamla:

~~~bash
flutter pub get
flutter build ios --release --no-codesign --dart-define-from-file=config/production.local.json
flutter build ipa --release --dart-define-from-file=config/production.local.json
~~~

Bu komutların Windows üzerinde başarılı çalıştığı iddia edilmez. App Store Connect privacy, konum / UGC moderasyonu, destek ve hesap silme bilgilerini gerçek veri politikasıyla doldur.

## Branding ve web

Final logo ayrıca sağlanmadı. Mevcut geçici işaret assets/brand/mark.svg altında tek kaynaktır. Flutter header / uygulama splash aynı kaynağı okur; Android adaptive icon, native splash, iOS boyutları, favicon ve OG exportları bu kaynaktan üretilir.

~~~powershell
python -m pip install Pillow resvg-py
python tool/export_brand_icons.py
~~~

Final sembol geldiğinde SVG'yi değiştirip export et; kritik detaylar export kenar boşlukları içinde kalır. Yeni bir görsel kimlik üretilmedi. Web assetleri backend/public/web altındadır; ayrı frontend build gerekmez.

Canonical, title / açıklama, OG, Twitter cards, sitemap, robots ve SoftwareApplication schema hazırdır; puan veya indirme sayısı uydurulmaz. Store CTA'ları admin'deki gerçek app_store_url / play_store_url değerlerini kullanır. Adres yoksa sahte link yerine bilgi gösterilir. Minimum / güncel Android ve iOS sürümleri admin'den yönetilir; zorunlu minimum için gerçek mağaza bağlantısı gerekir.

Veri sorumlusunun unvanı / adresi, iletişim / KVKK başvuru yöntemi, hukuki dayanaklar, alıcılar / aktarımlar, fiili saklama süreleri ve gerçek destek adresi yayın öncesi tamamlanmalıdır. Legal CMS varlığı bu bilgilerin hukuken tamam olduğu anlamına gelmez.

## Harita sağlayıcısı

Mevcut harita MAP_TILE_URL ve MAP_ATTRIBUTION build define değerleriyle sağlayıcı değiştirmeyi destekler. Varsayılan HTTPS OpenStreetMap tile adresi, com.senmiydin.app User-Agent kimliği ve görünür katkı bildirimi kullanılır; panBuffer=0 ile geniş ön yükleme yapılmaz.

Yayın öncesi trafik ve sağlayıcı koşullarını doğrula. OSM public tile hizmeti SLA sunmaz; uygulama kimliği, görünür attribution ve HTTP cache kurallarına uyulmasını ister. Toplu indirme / offline bölge indirme eklenmemelidir. Daha yüksek trafik için kendi tile sunucun veya buna uygun bir hizmet seçip gerçek URL / attribution değerlerini yapılandır. [OSMF tile kullanım politikası](https://operations.osmfoundation.org/policies/tiles/).

## Deploy, backup ve rollback

1. DB ve private upload storage'ın tutarlı, şifreli yedeğini al; APP_KEY / diğer secret yedeğini ayrı tut.
2. Yeni release dizininde bağımlılıkları kur. Ortak storage ve secret config'i bağla; hedef staging ortamında test et.
3. Gerekirse Laravel down kullan; erişimi sınırlı bakım bypass yöntemini yalnızca operator bilir. Bu framework bakımı, admin'deki mobil bakım ayarından ayrıdır.
4. migrate --force çalıştır. app:check ve HTTPS / auth / medya / admin smoke kontrollerini yap.
5. Atomik current bağlantısını geçir; config / route / view cache'lerini yenile, queue:restart ve up çalıştır.
6. Scheduler, worker, destek maili, push ve hata oranlarını kontrol et.

Yedekleme için mysqldump --single-transaction veya altyapının tutarlı snapshot mekanizmasını kullan; parola komut satırında görünmesin. Upload storage da aynı kurtarma noktasıyla yedeklenmeli. Şifreli, erişimi sınırlı, sunucu dışı kopyaları ve restore denemesini planla. Gerçek yedek saklama süresini politika ve operasyonla belirle.

Kod rollback'inde önceki release'e dönüp onun cache'lerini yenile ve worker'ları yeniden başlat. Veri silen migration veya hesap silmeyi rollback'in geri getireceğini varsayma. DB restore gerekiyorsa geri yüklemeden sonraki hesap silme / token iptal taleplerini tekrar uygula; silinmiş hesapların yedekten canlanmasına izin verme. Yeni migrationlar veri kaybı olmadan ileri yönde uygulanır; mevcut migration dosyaları yeniden yazılmaz.

Local veri dizini .local/mysql, build, .dart_tool, android/.gradle, vendor, private credential dosyaları ve aktif upload dizinlerini dosya eşitleme aracının dışında tut. Çalışan MySQL veri dosyalarını senkronize etmek yedek değildir. Bu bilgisayarda çakışma kopyaları ayrı .local/mysql-recovered-sync dizinine korunarak taşındı; primary tablo dosyaları silinmedi.

## Referanslar

[Laravel proxy yapılandırması](https://laravel.com/docs/12.x/requests#configuring-trusted-proxies), [Flutter Android yayınlama](https://docs.flutter.dev/deployment/android), [Google sunucu kimlik doğrulaması](https://developers.google.com/identity/sign-in/android/backend-auth), [Apple kullanıcı doğrulaması](https://developer.apple.com/documentation/signinwithapple/verifying-a-user), [Apple Flutter plugin kurulumu](https://pub.dev/packages/sign_in_with_apple).


## Windows release araçları ve paket

Proje kökünde tool/release_check.ps1 çalıştır. Flutter environment/pub/analyze/test, Composer install/platform/test, app:check, migrate:status, paket kimlikleri, HTTPS/debug ayrımı, demo seeder guard ve secret/gitignore denetlenir. Alt kontrol logları .local/release-check altındadır. Exit 0 tümü hazır, 1 teknik FAIL, 2 dış/deployment bilgileri MISSING anlamındadır. -SkipTests yalnızca daha önce aynı kodla test edilmiş hızlı kontroller içindir. app:check --json ve senmiydin:production-check aynı güvenli komuttur; hiçbir credential değeri göstermez. Yerel .env'yi production gibi gösterip kontrolleri yeşile çevirmeye çalışma.

Gerçek sunucuda OPERATOR_NAME, OPERATOR_CONTACT, LEGAL_REVIEWED, SCHEDULER_CONFIGURED, QUEUE_WORKER_CONFIGURED ve BRAND_FINAL yalnızca ilgili gerçek bilgi / kurulum tamamlandığında ayarlanır. LEGAL_REVIEWED tek başına yeterli değildir; CMS'deki varsayılan hukuk metinleri işletmeciye uygun içerikle tamamlanmalıdır. SMTP relay kimlik doğrulamasızsa bunu açıkça MAIL_ALLOW_UNAUTHENTICATED_RELAY ile belirt; varsayılan kimlik doğrulaması beklenir.

Ana paketleme yöntemi tool/build_backend_release.ps1 komutudur. dist/senmiydin-backend-release.zip uygulama / public web kaynakları ve composer.lock içerir, vendor içermez. Sunucuda Composer 2 ile composer install --no-dev --prefer-dist --optimize-autoloader çalıştırılır. Böylece platform gereksinimleri gerçek sunucuda doğrulanır. .env, secret, kullanıcı upload, cache/log/session, sqlite, .local, test, Android çıktısı, Git metadata veya demo seeder pakete girmez. Var olan production .env / APP_KEY / upload klasörünü ZIP'le değiştirme.

Alternatif -WithVendor seçeneği dist/senmiydin-backend-release-vendor.zip üretir ve Composer'ı izole geçici staging içinde --no-dev --no-scripts ile çalıştırır. Ana projenin vendor klasörünü veya geliştirme paketlerini kopyalamaz. PHP sürümü/eklentileri hedef sunucuyla uyumlu olmalı; sunucuda php artisan package:discover --ansi ve config/cache adımları yapılır. ZIP sonrasında release_safety.py arşiv içeriğini tekrar denetler ve SHA-256 / boyut / vendor bilgisi audit JSON'una yazılır. Composer sistem PATH'inde yoksa bu projede bulunan doğrulanmış .local/composer.phar kullanılabilir; sunucuda normal Composer kurulumu tercih edilir.

tool/create_android_keystore.ps1 gerçek anahtar sahibi tarafından interaktif çalıştırılır; yeni dosya yolu / alias / gizli parola / gerçek sahip bilgisi ister. Mevcut keystore veya key.properties üzerine yazmayı reddeder. Bu çalışma sırasında gerçek anahtar veya sabit parola üretilmez. Keystore yedeği ve parolalar ayrı güvenli yerde saklanır. tool/build_android_release.ps1 signing yoksa ilk adımda açıkça durur; gerçek signing geldikten sonra -Config config/production.local.json -RunTests -Apk seçenekleri kullanılabilir. -Clean hedef değişiminde gereklidir.

tool/run_pixel_regression.ps1 yalnızca tek açık Pixel_6a cihazını seçer; diğer emülatörlere dokunmaz. Her koşuda dokuz disposable rol hesabı hazırlanır; kayıt senaryosunun onuncu hesabı da ID ile sahiplik defterine eklenir. Sohbet her zaman yeni test hesapları arasındadır; -FreshChat eski çağrılar için korunur. Sonunda ve hata yolunda yalnız deftere ait kayıtlar temizlenir; normal Demo/Elif'e test içeriği yazılmaz. Script yerel fixture zamanlarını güvenli geliştirme komutuyla tazeler, ADB reverse kurar, kurulum sonrası konum izinlerini verir ve test sırasında sentetik GPS tazeler. Normal ana hedefe geri dönmeden önce integration test APK'sı ile lib/main.dart hedefini karıştırma.

## Final marka master dosyaları

Gerçek final kaynaklar: transparan, kare viewBox'lı icon SVG ve full yatay wordmark SVG. Açık zemin için doğru renkli master gerekir; koyu zemin varyantı varsa ayrıca saklanabilir. Mevcut onaylı beyaz tasarım değiştirilmez. PNG tek kaynak gelirse orijinal boyut ve transparan arka planı koruyarak tasarım ekibinden uygun SVG master istenir; rastgele vektör/AI logo üretilmez.

Önce python -m pip install -r tool/branding-requirements.txt ile renderer kur. Ardından tool/apply_branding.ps1 -SquareSvg gerçek-kare.svg -HorizontalSvg gerçek-yatay.svg çalıştır. Dosyalar yoksa, SVG aktif/dış içerik içeriyorsa veya mevcut geçici markanın aynısı final diye verilirse REFUSE eder. Gerçek master uygulandığında Flutter brand, Android/iOS ikon/splash, public/admin header, favicon ve OG tek işlemde güncellenir. Önceki dosyalar ignored .local/branding-backup altında saklanır. Sonra Flutter/native/web görsel QA ve yeniden build gerekir. Bu çalışmada final asset verilmediği için bu işlem uygulanmadı.

## Güvenli health ve operasyon

HTTPS GET /health yalnızca status=ok veya status=unavailable döndürür; DB SELECT 1 ve kısa cache probe kontrol edilir. Host, DB kullanıcı adı, dosya yolu, environment veya secret dönmez. HTTP 503 başarısızlığı izleme sisteminde alarm üretmeli. Her istek için kısa süreli rastgele cache anahtarı temizlenir; endpoint rate limited ve no-store'dur. Queue worker ve scheduler'ın gerçekten canlı olduğu ayrıca supervisor/cron izleme ve failed_jobs ile takip edilir; health bunların çalıştığını iddia etmez.

## MySQL / medya backup ve restore

Yayın öncesi DB ve private upload yedeğini aynı tutarlı zaman aralığında al. İşletim sistemindeki güvenli MySQL login-path veya yalnızca backup kullanıcısının okuyabildiği credential dosyası kullan; parolayı komut satırına yazma. Aşağıdakiler gerçek sunucuda gerçek yollar/DB adıyla uyarlanır:

~~~sh
mysqldump --login-path=senmiydin --single-transaction --routines --triggers --events --no-tablespaces senmiydin | gzip > /backups/senmiydin-before-deploy.sql.gz
tar -C /srv/senmiydin/shared -czf /backups/senmiydin-private-media.tgz storage/app/private
~~~

APP_KEY, private service credentials ve encryption anahtarlarının yedeği ayrı şifreli kasada olmalı. Kullanıcı DB dump'ı veya .env release ZIP'ine / Git'e eklenmez. Erişim, şifreleme, saklama süresi ve silme politikası gerçek işletmeciye göre belirlenir.

Restore bakım penceresinde yapılır: trafiği kapat, worker'ları durdur, doğru snapshot ve private medya yedeğini doğrula, staging'de restore prova et; sonra DB'yi ve karşılık gelen medyayı geri yükle. Yeni / ilgisiz veritabanını yanlışlıkla üzerine yazma. Örnek veri geri yükleme:

~~~sh
gunzip -c /backups/senmiydin-before-deploy.sql.gz | mysql --login-path=senmiydin senmiydin
~~~

Medya arşivini önce boş doğrulama dizinine açıp dosya/yol bütünlüğünü kontrol et; production private storage'a kontrollü kopyala. APP_KEY eski şifreli token/mail/outbox verileriyle uyumlu olmalı. Backup'tan sonra gerçekleşen hesap silme ve token iptallerini tekrar uygula; silinmiş hesabı geri canlandırma. Migration durumunu, app:check, health, private medya yetkisini ve silinmiş kullanıcı erişimini doğrulayıp queue/cron'u ve trafiği yeniden aç.

Kod rollback'inde önceki release'e dön; otomatik veri kaybettiren migrate:rollback çalıştırma. Yeni indeks migration'ı down destekler ama production rollback tercihi DBA tarafından schema/veri uyumluluğuyla verilir. İlk kurulumdan önce ve düzenli olarak gerçek backup/restore provası yapılır.

Yeni audit ve mağaza listeleri: RELEASE_AUDIT.md, PRODUCTION_CHECKLIST.md, STORE_READINESS.md.

Vendor paketi ek kontrolü: python tool/verify_backend_archive.py kendi ürettiğin ve audit edilmiş vendor ZIP'ini ignored geçici dizinde açıp .env kopyalamadan Laravel route bootstrap'ını doğrular. Güvenilmeyen üçüncü taraf arşivleri bu kod çalıştırma aracına verme. Her iki ZIP için dist içinde ayrı audit JSON / SHA-256 kaydı oluşur.

Bu bilgisayardaki 16 GB RAM ve başka açık uygulamalarla 8 GB heap / 4 GB metaspace ayarı JVM native-memory hatasına yol açtı. Projeye özel Gradle bütçesi 4 GB heap / 1 GB metaspace ve en fazla 2 worker olarak sınırlandı. Başka projelerin daemon / emülatörleri kapatılmadı. Daha büyük build sunucusunda kaynakları ölçerek ayarla; release signing korumasını veya testleri kapatma.

## Aktif şehir ve konum-zaman

Production-check veritabanında yeni tabloları/alanları ve ROW_NUMBER desteğini de doğrular. Yeni migration posts.occurred_at, post_travel_details, aktif şehir ve match skor/notification alanlarını ekler. Eski istemci alanları korunur. Varsayılan LOCATION_CITY_PROVIDER=boundaries yerel lisanslı sınır verisini kullanır; resources/geography klasörü ve atıf dosyası dağıtımda tutulmalıdır. Harici geocoding credential gerekmez. Production worker MatchLocationPost işini de işler (60 saniye timeout, 3 deneme); mevcut database queue/cron kurulumu korunur. Yeni bildirimin location_match tercihi history kaydetme izninden ayrıdır ve varsayılan kapalıdır. Operatör, mevcut admin Sistem Ayarları üzerinden moderasyon listesi/eşiklerini düzenleyebilir. Araç/plaka bilgisinin public olması açık kullanıcı seçimidir; hassas değerleri loglara taşımayın. API, privacy ve senaryo ayrıntıları LOCATION_TIME_TRAVEL.md içindedir.


## Store submission paketi — 9 Kasım 2026

Credential gerektirmeyen mağaza hazırlığı [docs/store/README.md](store/README.md) içindedir. Deployment öncesi mevcut release_check.ps1 yanında `powershell -ExecutionPolicy Bypass -File tool/store_readiness_check.ps1` çalıştırılır. Native Android girdileri değiştiyse `-RefreshAndroidAudit` seçeneği gerçek release dependency ağacı ve merged manifest kanıtını yeniler; bunu Flutter analyze/test ile eşzamanlı çalıştırmayın. Signing veya store upload yapmaz.

[Gerçek bilgi listesi](store/REQUIRED_REAL_INFORMATION.md), [legal audit](store/PUBLIC_LEGAL_AUDIT.md), [SDK / iOS manifest sınırları](store/SDK_AUDIT.md), [final branding gereksinimleri](BRANDING_REQUIREMENTS.md) ve [son doğrulama](STORE_AUDIT_VALIDATION.md) okunur. HTTP 200 olan yerel legal sayfa, gerçek işletmeci/hukuk metni ve canlı HTTPS erişimi yerine geçmez. Çocuk güvenliği standardı/sorumlusu, log/yedek retention ve gerçek alıcı sözleşmeleri tamamlanmadan ilgili kapılar MISSING kalır. Windows kaynak denetimi iOS archive/Privacy Report yerine geçmez.
