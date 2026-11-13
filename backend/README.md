# SenMiydin? API

Laravel 12 ve Sanctum ile çalışan sürümlü mobil API. PHP 8.2+, Composer, MySQL veya MariaDB ve PHP'nin PDO MySQL ile GD eklentileri gerekir. Yerel özellik testleri PDO SQLite kullanır.

## Yerel kurulum

MySQL'de `senmiydin` veritabanını ve bu veritabanına erişen bir uygulama kullanıcısı oluştur. Proje kökünden şu komutları çalıştır.

```powershell
Set-Location backend
composer install
Copy-Item .env.example .env
```

Yerel `.env` dosyasında `APP_ENV=local`, `APP_URL=http://127.0.0.1:8000`, `MAIL_MAILER=log` ve `LOG_LEVEL=debug` kullan. `DB_*` alanlarına geliştirme veritabanını yaz.

```powershell
php artisan key:generate
php artisan migrate --seed
Set-Location ..
powershell -ExecutionPolicy Bypass -File .\tool\start_api.ps1
```

Bu bilgisayardaki proje için `backend/.env` hazırdır. Ayrı MySQL örneği `127.0.0.1:33076` üzerinde çalışır. Composer PATH üzerinde yoksa `composer` yerine `php ../.local/composer.phar` kullanılabilir.

Bu bilgisayarda proje MySQL örneği kapalıysa, proje kökünden aşağıdaki komutla yeniden başlat.

```powershell
$mysqlData = (Resolve-Path .local/mysql).Path
& 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqld.exe' --no-defaults --bind-address=127.0.0.1 --port=33076 --mysqlx=OFF "--datadir=$mysqlData"
```

Katalog sağlığını `GET /api/v1/cities` ve `GET /api/v1/interests` ile kontrol et. Şifre sıfırlama kodu yerelde `storage/logs/laravel.log` dosyasına yazılır.

## Doğrulama

```powershell
composer test
```

Boş geliştirme veritabanını yeniden kurmak için `php artisan migrate:fresh --seed` komutu tüm tabloları silip yeniden oluşturur. Seeder yalnızca şehir ve ilgi alanı kataloglarını doldurur.

## Yayın yapılandırması

Web sunucusu belge kökü `backend/public` ve API adresi HTTPS olmalıdır. `.env.example` üzerinden yeni bir uygulama anahtarı üret, MySQL ve SMTP değerlerini ortamda tanımla ve `php artisan migrate --force --seed` çalıştır. Avatarlar `AVATAR_DISK` ile seçilen Laravel diskinde saklanır ve API üzerinden sunulur. Süresi dolan Sanctum tokenlarının temizlenmesi için Laravel zamanlayıcısını çalıştır.


## Paylaşımlar ve medya

Akış, arama, yorumlar, kaydedilenler ve profil listelerinde API, `data.items` ve `data.next_page` alanlarını döndürür. Akış kayıtlı şehri kullanır ve `city_id` ile değiştirilebilir. Şehir görünürlüğü kapatılan paylaşımı sahibi kendi profilinde görür. Paylaşım oluşturma isteğinde `request_id` değerini yeniden denemelerde koru.

Bir paylaşım için en fazla 10 JPEG, PNG veya WebP dosyası kabul edilir. Dosya başına sınır 5 MB ve 2048 pikseldir. API görselleri JPEG olarak yeniden kodlar ve `POST_MEDIA_DISK` ile seçilen özel diskte saklar. Web sunucusunun yükleme sınırını ve PHP `post_max_size` değerini en az 55 MB, `upload_max_filesize` değerini en az 5 MB olarak ayarla.

Silinen paylaşımların medyası erişime kapatılır. Laravel zamanlayıcısındaki `posts:purge-deleted` komutu 30 gün sonra dosyaları ve ilişkili kayıtları temizler.


## Konum ve saklama

`php artisan migrate` komutu konum tablolarını mevcut hesap ve paylaşımlar korunarak ekler. `php artisan db:seed --class=DemoDataSeeder` komutu yalnızca `local` ve `development` ortamlarında çalışır. Normal katalog seeder'ı yalnızca şehirleri ve ilgi alanlarını yükler.

Yakınlık sorguları MySQL veya MariaDB üzerinde önce şehir ve koordinat aralığıyla, ardından gerçek mesafeyle filtrelenir. Aktif şehir için `CityResolver` sınırı vardır. Varsayılan çözümleyici yerel geoBoundaries/OSM sınır verisini kullanır; profil şehrini cihaz şehri olarak atamaz. Belirsiz durumda koordinat korunur ve manuel aktif şehir seçilir. LOCATION_CITY_PROVIDER=none ile manuel seçim kullanılabilir; arayüz başka provider ile değiştirilebilir. Kaynak/lisans resources/geography/README.md içindedir.

Geçtiğim Yerler varsayılan olarak kapalıdır. Açıkken yaklaşık bölgeler varsayılan yedi gün saklanır. Süre `LOCATION_HISTORY_DAYS` ile ayarlanır. Ayar kapatıldığında o hesaba ait geçmiş ve bekleyen eşleşmeler silinir. Süresi dolan kayıtların otomatik temizliği için Laravel zamanlayıcısı `location:purge` komutunu saatlik çalıştırır.

Kullanıcıların koordinatları yakın kişi yanıtında bulunmaz. Harita uç noktası yalnızca şehir görünürlüklü gönderilerin yaklaşık noktalarını döndürür. Geçmiş ve eşleşmeler mobil API'den okunamaz.

## Karşılaşmalar

`php artisan migrate` karşılaşma isteklerini, doğrulanan karşılaşmaları ve mevcut gönderilerde ortak hikâye alanlarını ekler. Yerel hesaplar için `php artisan db:seed --class=DemoDataSeeder` çalıştır.

- `GET /api/v1/search?type=users&encounter=1&q=elif` etiketlemeye uygun hesapları sıralar.
- `POST /api/v1/posts` isteğindeki `encounter_target_id`, karşılaşma paylaşımıyla birlikte bir istek oluşturur. Aynı `request_id` ile tekrar gönderilen istek mevcut kaydı döndürür.
- `GET /api/v1/encounter-requests` katılımcıya ait istekleri, `pending-count` işlem bekleyen istek ve yayın onaylarının toplamını verir. İstek detayı üzerinden alıcı `accept` veya `reject` kullanır. Gönderen bekleyen isteği `DELETE` ile iptal eder.
- Ortak hikâye `POST /api/v1/posts` ile `encounter_id`, `story_title`, `body` ve isteğe bağlı `media` alanlarıyla oluşturulur. `/api/v1/encounters/{id}/story` altındaki `approve` ve `reject` uçları diğer katılımcıdan güncel `revision` değerini ister.
- Yayınlanan hikâyeler şehir akışında, `/api/v1/encounters/featured` ve `/api/v1/users/{username}/encounters` listelerinde görünür.

## Mesajlaşma ve bildirimler

`php artisan migrate` sohbet, mesaj, bildirim, cihaz, engel ve şikâyet tablolarını ekler. Mesajlaşma mevcut Sanctum oturumunu kullanır. İlk mesaj bir istek açar. Reddedilen veya engel nedeniyle iptal edilen bir isteğin yeniden gönderilmesi için 24 saat geçmelidir.

- `GET /api/v1/conversations` sohbetleri sayfalar. `requests=1` bekleyen istekleri getirir.
- `POST /api/v1/users/{id}/messages` metin veya tek fotoğraf gönderir. Yeniden denemede aynı `request_id` kullanılır. Fotoğraf, isteğin `image` multipart alanına eklenir.
- `GET /api/v1/conversations/{id}/messages` mesajları `before` veya `after` imleciyle getirir. Okuma işlemi alınmış bir mesajın kimliğini `through` olarak kullanır.
- `GET /api/v1/notifications` ve `GET /api/v1/unread-counts` uygulama içi bildirimleri ve gerçek sayaçları sunar. `PUT /api/v1/profile` mesaj ve cihaz bildirimi tercihlerini kaydeder.
- `GET /api/v1/blocks`, `PUT/DELETE /api/v1/blocks/{id}` ve `POST /api/v1/reports` güvenlik akışlarını sunar.

Flutter, açık sohbeti 4 saniyede bir ve genel sayaçları 8 saniyede bir yeniler. Arka planda bu yenilemeler durur.

### Cihaz bildirimi

Yerelde `PUSH_DRIVER=log` kayıtlı cihaz için yalnızca tür, hedef, bildirim ve alıcı kimliklerini günlüğe yazar. `PUT /api/v1/push-device` kayıt yapar. Çıkış sırasında o oturuma bağlı cihaz kaydı pasifleştirilir.

Canlı teslimat için `PUSH_DRIVER=fcm`, `FCM_PROJECT_ID` ve sunucunun erişebildiği bir hizmet hesabı JSON dosyasının mutlak yolu olarak `FCM_CREDENTIALS` tanımlanır. Firebase Cloud Messaging HTTP v1 API’si etkin olmalı ve hizmet hesabına gönderim yetkisi verilmelidir. `php artisan queue:work database` işçisi push teslimatını yürütür.

Flutter derlemesine `FCM_PROJECT_ID`, `FCM_SENDER_ID` ve hedefe göre `FCM_ANDROID_APP_ID` ile `FCM_ANDROID_API_KEY` veya `FCM_IOS_APP_ID` ile `FCM_IOS_API_KEY` Dart define olarak verilir. iOS ayrıca Push Notifications yetkili Apple provisioning profili ve Firebase'e yüklenmiş APNs `.p8` anahtarı, Key ID ve Team ID gerektirir. Sunucuya ait hizmet hesabı anahtarını mobil derlemeye ekleme.

## Yönetim ve public web

Laravel sunucusunun belge kökü `backend/public` olmalıdır. Yerelde aşağıdaki komutları `backend` içinde çalıştır.

~~~powershell
php artisan migrate
php artisan db:seed --class=DevelopmentAdminSeeder
php artisan serve --host=127.0.0.1 --port=8000
~~~

- Yerel yönetim girişi `http://127.0.0.1:8000/admin/login`.
- Development yönetici hesabı `admin@senmiydin.local`, parola `Admin1234!`. Seeder yalnızca local ve development ortamlarında çalışır.
- Yerel public site `http://127.0.0.1:8000/`. Üretim canonical adresi `PUBLIC_SITE_URL` ile ayarlanır.
- Üretimde yönetici hesabını `php artisan admin:create eposta@ornek.com` ile oluştur. `--moderator` sınırlı moderasyon rolünü seçer. Parola terminalde gizli girilir. HTTPS ve güvenli oturum çerezi (`SESSION_SECURE_COOKIE=true`) kullan. Yerel HTTP için bu değişkeni `false` yap.
- Zamanlanmış duyurular için Laravel zamanlayıcısını çalıştır. Push teslimatı önceki bölümdeki Firebase ve kuyruk ayarlarını kullanır. Varsayılan log sürücüsü yerelde harici servis kullanmaz.
- İletişim ve hesap silme formları yönetim panelindeki **Destek talepleri** bölümüne kayıt açar. Hesap silme taleplerinde destek ekibi kimliği doğrular ve silme sürecini yürütür. İşaretleme hesabı veya verilerini silmez.
- Üretim öncesinde veri sorumlusu, başvuru kanalları, gerçek saklama ve silme süreçleriyle hukuk metinlerini tamamla. Destek e-postası ve resmî mağaza bağlantıları **Ayarlar** bölümünden yönetilir.
- CSS ve site görselleri `public/web` altından doğrudan sunulur. Bunlar için ayrı bir frontend derlemesi gerekmez.

## Production kurulumu

Tek deployment yönergesi [../docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md) içindedir. Üretim ortamında migrate ve admin oluşturma sonrasında `php artisan app:check` kullan. Bu komut secret değerlerini yazdırmaz. Yeni hesap silme API'si `DELETE /api/v1/auth/account` mevcut şifre ve SİL onayıyla çalışır. Medya temizliği ve Apple token iptali outbox / scheduler ile yeniden denenir. Mobil hukuk metinleri `GET /api/v1/legal/{slug}` üzerinden aynı CMS'den alınır.

Üretim queue ve mail işleri için varsayılan `.env.example` database kuyruğudur. Worker timeout 90, DB_QUEUE_RETRY_AFTER=120 olarak örneklendirilmiştir. Alan adı `https://senmiydin.com` altında web + API birlikte çalışır. Local çalışmada mevcut `.env` değerlerini üretim örneğiyle körlemesine değiştirme.


Release preflight: php artisan senmiydin:production-check --json (app:check alias). OK/WARNING/MISSING/ERROR durumları ve kategori döndürür; credential değerleri çıkmaz. Dış bilgi eksikliği exit 2, kod testi hatası değildir. Güvenli GET /health DB/cache erişimini yalnızca status ile gösterir.

Proje kökündeki tool/build_backend_release.ps1 uygulamayı allowlist ile paketler; ana öneri vendor'sız ZIP + sunucuda Composer install'dır. -WithVendor ana geliştirme vendor klasörünü kopyalamadan izole --no-dev kurulum yapar. .env, user media, secret, demo seeder veya yerel DB pakete girmez. Ayrıntılar ../docs/DEPLOYMENT.md ve ../docs/PRODUCTION_CHECKLIST.md içinde.

Aktif şehir, geçmiş yer/occurred_at, gerçek location_matches, Yolculuk metadata, ayrı location_match bildirimi, EXIF ve moderasyon ayrıntıları ../docs/LOCATION_TIME_TRAVEL.md içindedir. Production queue worker yeni MatchLocationPost işini de çalıştırır.
