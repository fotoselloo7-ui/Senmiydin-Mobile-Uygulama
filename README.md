# SenMiydin?

Flutter mobil uygulaması hesap, profil, katalog ve sosyal paylaşım verilerini `backend` klasöründeki Laravel API'den alır. Ürün tanımı ve `Ekran Görüntüleri` klasöründeki iki referans pano bu köktedir.

## Üretim ve mağaza yapılandırması

Sunucu kurulumu, HTTPS, private storage, queue / scheduler, yedekleme, Firebase, OAuth ve yayın imzası için tek yönerge [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) dosyasındadır. Debug emülatör adresi yerel API'yi, release varsayılanı `https://senmiydin.com/api/v1` adresini kullanır. Release derlemeleri `config/production.json` üzerinden yapılandırılır; gerçek kimlikler için ignore edilen `config/production.local.json` hazırlanabilir.

Gerçek hesap silme, şifre ve SİL onayıyla çalışır. Mobil hukuk metinleri backend CMS'den okunur. Mağaza bağlantıları ve Android / iOS minimum-güncel sürümleri admin ayarlarında yönetilir. Release signing eksikse debug anahtarı kullanılmaz.

Mevcut geçici marka işareti `assets/brand/mark.svg` altındadır; platform ve web exportları `tool/export_brand_icons.py` ile üretilir. Final logo ayrıca sağlanmalıdır.

## Yerelde çalıştırma

MySQL/MariaDB ve Laravel kurulumu için [backend yönergesini](backend/README.md) kullan. Bu bilgisayarda Laravel'i bir PowerShell penceresinde çalıştır.

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\start_api.ps1
```

Başka bir PowerShell penceresinde, proje kökünden Pixel 6a'yı başlat.

```powershell
& 'C:\src\flutter\bin\flutter.bat' pub get
powershell -ExecutionPolicy Bypass -File .\tool\run_pixel6a.ps1
```

Android emülatörü varsayılan olarak `http://10.0.2.2:8000/api/v1` adresini kullanır. Farklı bir sunucu için `-ApiBaseUrl` ya da Flutter'ın `--dart-define=API_BASE_URL=...` seçeneğini kullan. Yayın derlemesi HTTPS gerektirir.

## Gezilebilir ekranlar

| Ekran | Ulaşım / route |
|---|---|
| 1. Splash | Normal uygulama açılışı, `/` |
| 2. Karşılama / onboarding | Açılış veya yan menü → Karşılama ekranları, `/welcome` |
| 3. Giriş | Karşılama → Giriş Yap, `/login` |
| 4. Kayıt | Onboarding son adım veya Giriş → Kayıt Ol, `/register` |
| 5. Profil tamamlama | Kayıt → Devam Et, `/complete` |
| 6. Hobiler / ilgi alanları | Profil tamamlama veya profil / menü, `/interests` |
| 7. Konum ve bildirim izinleri | İlgi alanlarında en az 5 seçim → Devam Et, `/permissions` |
| 8. Ana sayfa | Alt navigasyon, `/home` |
| 9. Harita | Alt navigasyon veya banner, `/map` |
| 10. Filtreler | Yan menü veya harita filtre ikonu, `/filters` |
| 11. Arama | Header arama ikonu, `/search` |
| 12. Paylaşım oluştur | Ortadaki + veya hızlı paylaşım, `/compose` |
| 13. Kişi etiketle | Paylaşım türü → Karşılaşma → Etiketle, `/tag` |
| 14. Karşılaşma onayı / red | Etiketli paylaşım sonrası veya bildirimler / karşılaşmalar, `/encounter` |
| 15. Paylaşım detayı | Gönderi metnine dokun, `/post` |
| 16. Yorumlar | Gönderi yorum ikonu, `/comments` |
| 17. Diğer kullanıcı profili | Avatar / arama / yakınındaki kişiler, `/profile` |
| 18. Kendi profilim | Alt navigasyon → Profil |
| 19. Profil düzenle | Profil → Düzenle veya Ayarlar, `/edit-profile` |
| 20. Karşılaşmalarım | Profil veya yan menü, `/encounters` |
| 21. Kaydedilenler | Profil veya yan menü, `/saved` |
| 22. Bildirimler | Header zil ikonu veya yan menü, `/notifications` |
| 23. Mesajlar | Alt navigasyon, `/messages` |
| 24. Sohbet | Mesaj satırı veya profil → Mesaj, `/chat` |
| 25. Ayarlar | Profil veya yan menü, `/settings` |
| 26. Gizlilik / konum / bildirim ayarları | Ayarlar, `/preferences` |
| 27. Engellenen kullanıcılar | Ayarlar, `/blocked` |
| 28. Şikâyet | Gönderi / profil / sohbet menüsü veya Ayarlar, `/report` |
| 29. Hesap silme | Ayarlar → Hesabımı Sil, `/delete-account` |

Ek ekranlar: şifre sıfırlama, şifre değiştirme, Google / Apple giriş durumu, örnek kamera, çoklu fotoğraf seçici, gönderi önizlemesi, mesajla paylaşma, takip listeleri, öne çıkan karşılaşmalar, hukuki metinler ve fotoğraf büyütme.

## İki hesapla karşılaşma testi

Yerel API’de `php artisan migrate` ve `php artisan db:seed --class=DemoDataSeeder` çalıştır. Demo hesaplarının ikisinde de parola `Demo1234!`.

1. `demo@senmiydin.local` (`demo`) hesabıyla **Karşılaşma** paylaşımı yaz ve `@elifdemo` hesabını etiketle.
2. `elif@senmiydin.local` (`elifdemo`) hesabına geç. **Bildirimler** veya **Karşılaşmalarım** üzerinden isteği aç ve onayla.
3. **Karşılaşmayı Paylaş** ile başlık, açıklama ve en fazla 10 fotoğraf ekle. **Yayın Onayına Gönder** düğmesine dokun.
4. `demo` hesabına dön, bildirimden hikâyeyi aç ve **Yayınlamayı Onayla** düğmesine dokun. Hikâye şehir akışında, **Öne Çıkan Karşılaşmalar** bölümünde ve her iki katılımcının karşılaşma listesinde görünür.

Bekleyen istekleri yalnızca katılımcılar görebilir. İsteği gönderen iptal edebilir, alan reddedebilir. Anonim ve özel paylaşımlarda kişi etiketi kullanılamaz.

## Yönetim paneli ve public web

Aynı Laravel uygulaması public siteyi `http://127.0.0.1:8000/`, ayrı yönetim oturumunu `http://127.0.0.1:8000/admin/login` adresinde sunar. Yerel yönetici `admin@senmiydin.local`, parola `Admin1234!`. Bu hesap yalnızca local / development seeder'ı ile oluşturulur.

Kurulum, üretim ayarları ve yönetici oluşturma komutu [backend/README.md](backend/README.md) içindedir. Güncel doğrulama durumu [docs/VALIDATION.md](docs/VALIDATION.md) dosyasındadır. Web üzerinden hesap silme başvurusu destek talebi oluşturur; otomatik hesap silmez.

## Yapı

- `lib/core`: tema tokenları, gezinme ve ortak geri bildirim yardımcıları.
- `lib/data/models.dart`: kullanıcı, paylaşım, karşılaşma, yorum, sohbet, bildirim ve filtre modelleri.
- `lib/data/mock_data.dart`: 12 kullanıcı, 18 paylaşım, tüm içerik türleri, 5 karşılaşma, yorumlar, 5 sohbet ve 9 bildirim.
- `lib/data/account_api.dart`: oturum, profil ve katalog servisleri.
- `backend`: Laravel REST API, migration, seeder ve özellik testleri.
- `lib/data/app_store.dart`: tek `ChangeNotifier` + `InheritedNotifier` üzerinden oturum içi ortak durum. Filtre, takip, engel, beğeni, kayıt, yorum, mesaj ve karşılaşma kararları aynı veri kaynağını günceller.
- `lib/widgets`: marka/header, butonlar, form alanı, avatar, kullanıcı satırı, bölüm başlığı, banner, not, seçim/ilgi chipleri, tercihler, boş durum, gönderi/karşılaşma kartları ve görsel carousel.
- `lib/screens`: auth, keşif, akış, paylaşım, karşılaşma, profil, mesaj, bildirim ve güvenlik ekranları.
- `assets`: uygulamaya gömülü örnek fotoğraflar ve Nunito Sans.
- Android / iOS uygulama kimliği: `com.senmiydin.app`.

## Kontroller

```powershell
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
flutter test integration_test/account_test.dart -d emulator-5558
flutter test integration_test/social_test.dart -d emulator-5558
flutter drive -d emulator-5558 --driver test_driver/integration_test.dart --target integration_test/app_test.dart
flutter drive -d emulator-5558 --driver test_driver/integration_test.dart --target integration_test/media_test.dart
```

Widget testleri 320×568, 412×915 ve 891×411 boyutlarında ekranları ve geri gezinmeyi kontrol eder. Küçük ekranda 250 piksel klavye alanı ve 1.3 yazı ölçeğiyle formlar / sohbet de kontrol edilir. Durum testleri görünürlük, şehir / mesafe / içerik / ilgi filtreleri, anonimlik, onay / red, engelleme ve sosyal etkileşimleri doğrular. Entegrasyon testi gerçek Pixel 6a'da ekran görüntüleri ve tam karşılaşma senaryosu üretir. Görseller `docs/screenshots`, son çıktılar `docs` altındadır.

## Sınırlar

Akış, paylaşım, yorum, kayıt ve takip verileri Laravel API üzerinden saklanır. Karşılaşma istekleri ve ortak hikâyeler API üzerinden çalışır. Mesajlar, mesaj istekleri, bildirimler, engeller ve şikâyetler yerel Laravel API’sine bağlanır. Şifre sıfırlama kodu yerelde Laravel günlüğüne yazılır. Yayın e-postası için SMTP, sosyal giriş için Google ve Apple yapılandırması gerekir. Hukuki metinler gerçek veri sorumlusu, başvuru kanalları ve saklama süreleriyle tamamlanmalıdır. iOS derlemesi macOS ve Xcode gerektirir.

Dosya eşitleme aracının ürettiği çakışma kopyaları `docs/recovered_sync` altında `.txt` olarak saklanır; ürün tanımı ve referanslar değiştirilmemiştir.

Android test hedefleri arasında geçişte `kernel_blob.bin` için yinelenen ZIP girdisi hatası görülürse `flutter clean` ve `flutter pub get` sonrasında komutu yeniden çalıştır. `build`, `.dart_tool` ve `android/.gradle` klasörlerinin dosya eşitleme dışında tutulması önerilir.


## Pixel 6a konum denemesi

Yerel API ve MySQL açıkken proje kökünden demo verilerini yükle ve emülatöre Alanya konumu gönder.

```powershell
Push-Location .\backend
php artisan migrate
php artisan db:seed --class=DemoDataSeeder
Pop-Location
powershell -ExecutionPolicy Bypass -File .\tool\set_demo_location.ps1
powershell -ExecutionPolicy Bypass -File .\tool\run_pixel6a.ps1
```

Demo girişinde `demo@senmiydin.local` veya `demo` ile `Demo1234!` kullan. Yakın örnek konumlar 30 dakika sonra listeden çıkar. Yeni deneme için demo seeder konum zamanlarını yeniler. Konum scripti yalnızca Pixel 6a emülatörüne test konumu verir. Varsayılan sağlayıcıya dönmek için `set_demo_location.ps1 -Reset` kullan.

Konum iznini kayıt sonundaki Cihaz Konumu satırından, Ana Sayfa'daki yakınlık kartından veya gizlilik ayarlarından verebilirsin. Geçtiğim Yerler açıkken Android, uygulama görünürken konum servisini başlatır ve uygulama arka plana geçtiğinde konum kaydı sürer. Bu kayıt, Android’in görünür konum servisine bağlıdır. iOS yapılandırması uygulama açıkken konum kullanımı içindir.

Harita için `MAP_TILE_URL`, `MAP_ATTRIBUTION` ve `MAP_ATTRIBUTION_URL` Flutter derleme ayarları kullanılabilir. Varsayılan harita OpenStreetMap kullanır. [Karo kullanım kuralları](https://operations.osmfoundation.org/policies/tiles/)

## Mesajlaşma ve güvenlik doğrulaması

Demo hesabıyla Elif’in profilindeki **Mesaj** düğmesinden ilk mesajı yaz. Elif hesabına geçip **Bildirimler** veya **Mesajlar → İstekler** üzerinden kabul et ve yanıtla. Demo hesabında okunmamış rozeti görünür. Sohbette bir fotoğraf ekleyebilir, sohbet menüsünden kullanıcıyı engelleyebilir ve **Ayarlar → Engellenen Kullanıcılar** ekranından engeli kaldırabilirsin.

Yerel bildirim günlüğü ve Firebase yapılandırması `backend/README.md` içinde anlatılır.

Pixel 6a tam entegrasyonu için `tool/run_pixel_regression.ps1` kullanılır. İletişim testi her çalıştırmada yalnız o koşunun iki disposable hesabıyla yeni bir sohbet oluşturur. Normal Demo/Elif hesabı kullanılmaz. Script sahiplik defteri ve Dart tanımlarını ignored `.local` altında tutar; tamamlanınca veya hata yolunda yalnız kendi kayıtlarını temizler. Medya/suffix kuralları ve temizleme sınırları: [docs/DEMO_DATA_QUALITY.md](docs/DEMO_DATA_QUALITY.md).


## Release otomasyonu

- tool/release_check.ps1: test/analiz/config/migration/secret kontrolü; exit 1 teknik hata, exit 2 dış yayın eksikleri.
- tool/build_backend_release.ps1: güvenli vendor'sız production ZIP; -WithVendor izole Composer kurulumu seçeneği.
- tool/build_android_release.ps1: gerçek signing geldikten sonra AAB, isteğe bağlı APK.
- tool/create_android_keystore.ps1: yalnızca anahtar sahibinin interaktif çalıştıracağı yardımcı.
- tool/apply_branding.ps1: gerçek final master dosyalar gelmeden REFUSE.
- tool/run_pixel_regression.ps1: yalnızca Pixel 6a, gerçek API ve sentetik GPS ile tam regresyon.

[Deployment](docs/DEPLOYMENT.md), [production checklist](docs/PRODUCTION_CHECKLIST.md), [store readiness](docs/STORE_READINESS.md) ve [release audit](docs/RELEASE_AUDIT.md) güncel üretim belgeleridir. Sahte credential veya final logo oluşturulmaz.

Aktif şehir, geçmiş yer ve olay zamanı, konum-zaman eşleşmesi, Yolculuk detayları ile ilgili güncel API/izin/test davranışı [LOCATION_TIME_TRAVEL.md](docs/LOCATION_TIME_TRAVEL.md) içinde açıklanır. Tam Pixel helper mevcut beş senaryoya üç özel SenMiydin senaryosunu da ekler; yalnızca kendi disposable fixture verisini temizler.
