# Yayın operasyonu durumu — 15 Kasım 2026

Bu belge gerçek hesaplarda (kullanıcının oturum açık Chrome'u üzerinden) ne yapıldığını, neyin kanıtlandığını ve neyin **yalnızca insan müdahalesiyle** ilerleyebileceğini söyler. Hiçbir gizli değer (API anahtarı, servis hesabı, keystore parolası) bu repoda yoktur: hepsi ignored dosyalarda veya repo dışındadır.

## Yapıldı ve doğrulandı

| Alan | Durum | Kanıt |
|---|---|---|
| Firebase projesi | **Oluşturuldu** (hesaptaki kullanılmayan varsayılan bir Cloud projesine Firebase eklendi, adı "SenMiydin" yapıldı; proje limiti dolu olduğu için yeni proje açılamadı). Analytics **kapalı** (mağaza beyanlarıyla uyumlu) | Firebase konsolu |
| Firebase Android uygulaması | `com.senmiydin.app` kayıtlı; debug + upload SHA-1/SHA-256 parmak izleri eklendi | konsol |
| Google ile giriş | Firebase Authentication'da Google sağlayıcı **açık**; web OAuth istemcisi oluştu (`GOOGLE_WEB_CLIENT_ID`) | `google-services.json` (ignored) |
| FCM HTTP v1 | Servis hesabı anahtarı üretildi, **repo dışında** (`C:\Users\pc\SenMiydin-keys\firebase-adminsdk.json`); yerel backend `PUSH_DRIVER=fcm` ile bağlandı | `php artisan app:check` → FCM OK |
| **Gerçek Android push (Pixel 6a)** | Mesaj: **arka plan, süreç kapalı (öldürülmüş), ön plan**; beğeni, yorum, mesaj isteği; bildirime dokununca **sohbete yönlendirme** (kapalı uygulamadan) doğrulandı. Ön planda uygulama içi "Gör" çubuğu çıkar | cihazda `dumpsys notification` + ekran görüntüleri |
| Gerçek push'ta bulunan hata | `PushDelivery::accessToken` closure'ı `$project`'i `use` etmiyordu → gerçek FCM yolu hiç çalışmıyordu (testler sahte sürücüyle geçiyordu). Düzeltildi; sahte Google uç noktalarıyla gerçek JWT → token → gönderim yolunu çalıştıran `FcmDeliveryTest` eklendi | backend testleri |
| AdMob | **Android** uygulaması "SenMiydin?" + native reklam birimi "SenMiydin Feed Native Android"; **iOS** uygulaması "SenMiydin? iOS" + "SenMiydin Feed Native iOS" oluşturuldu. Kimlikler ignored `config/production.local.json` ve `ios/Flutter/OAuth.xcconfig` içinde | `tool/configure_mobile.py` (AdMob argümanları artık işleniyor — önceden yok sayılıyordu) |
| app-ads.txt | Backend `/app-ads.txt` yayıncı kimliği (`ADMOB_PUBLISHER_ID`) ayarlanınca sunar; yerelde doğrulandı | `PublicShareTest` |
| Upload keystore | Üretildi, **repo dışında** (`C:\Users\pc\SenMiydin-keys\senmiydin-upload.jks`); `android/key.properties` ignored. **Yedeğini al** | — |
| İmzalı AAB | `flutter build appbundle --release --dart-define-from-file=config/production.local.json`: 81,3 MB, `com.senmiydin.app`, 0.1.0+1, upload sertifikasıyla imzalı (SHA-256 eşleşti), gerçek AdMob kimliği, örnek kimlik / `10.0.2.2` / `localhost` yok, cleartext kapalı, birleşik manifest kontrolü **OK (MISSING yok)** | `tool/platform_manifest_check.py android` |

AAB SHA-256: `c4ceae11a057de43492e3f80baa56e55f7657fbe7f11e8dafcd1ae8f990ea60c` (`build/app/outputs/bundle/release/app-release.aab`, ignored).

## HUMAN ACTION REQUIRED (yalnızca sen yapabilirsin)

1. **Üretim alan adı.** `senmiydin.com` DNS'te **çözülmüyor** (kayıtlı/yönlendirilmiş değil). Alan adını kaydet/yönlendir, HTTPS kur. Gizlilik, KVKK, hesap silme, `app-ads.txt` ve paylaşım bağlantıları buna bağlı. Release AAB `https://senmiydin.com/api/v1` adresini kullanır; farklı alan için `API_BASE_URL` ve `APP_LINK_HOST` değiştirilip yeniden derlenir.
2. **Üretim sunucusu.** Sunucu/barındırma erişimi yok: `APP_ENV=production`, `APP_DEBUG=false`, üretim DB, kuyruk işçisi (`queue:work database` — `DeliverPush` `database` bağlantısını kullanır), zamanlayıcı cron'u, özel depolama, sağlık ucu `docs/DEPLOYMENT.md` adımlarıyla kurulacak. `.env` içine: `PUSH_DRIVER=fcm`, `FCM_PROJECT_ID`, `FCM_CREDENTIALS` (sunucudaki servis hesabı dosyası), `GOOGLE_CLIENT_IDS`, `ADMOB_PUBLISHER_ID`, `ANDROID_APP_LINK_SHA256` (Play App Signing + upload SHA-256), `APPLE_TEAM_ID`.
3. **SMTP.** host, port, kullanıcı adı, parola, gönderen adresi. Şifre sıfırlama e-postası gerçek teslim testi bundan sonra.
4. **Google Play Console — "Uygulama oluştur" beyanları.** Geliştirici hesabı ("Netvera Teknoloji Yazılım") açık ve oturumun var; uygulama oluşturma formu iki hukuki beyan istiyor (Developer Program Politikaları + ABD ihracat yasaları). Bunları **senin** onaylaman gerekir. Sonra: Uygulama adı `SenMiydin?`, varsayılan dil English (United States), Uygulama, Ücretsiz → Oluştur.
   Ardından hazır olanlar: imzalı AAB, `docs/store/localization/` TR/EN metinleri, ekran görüntüleri (`docs/screenshots/`), `docs/store/GOOGLE_PLAY_DATA_SAFETY.md` (ses kaydı dahil), `docs/store/PERMISSIONS.md`, `docs/store/REVIEW_ACCOUNT.md`.
5. **Closed test tester e-postaları** (liste yok) ve Play'in 12 tester / 14 gün şartı durumu (kurumsal hesapta geçerli olmayabilir; Console'dan doğrulanacak).
6. **AdMob.** UMP (Gizlilik ve Mesajlaşma → Avrupa tüzükleri) mesajı **yayınlanmadı**: oluşturma sihirbazı Chrome'da askıda kaldı. Uygulama listesinden iki SenMiydin uygulamasını seç, gizlilik politikası URL'sini (gerçek alan adı hazır olunca) ekle, yayınla. Ayrıca uygulamalar mağazada yayınlanınca AdMob'da "Mağaza ekle" ve app-ads.txt doğrulaması.
7. **Google ile giriş testi** (gerçek Google hesabı parolası/2FA): yapılandırma tamam; emülatörde/cihazda gerçek hesapla `Google ile devam et` denenmeli (release imzalı derlemeyle upload + Play App Signing SHA-1'leri Firebase'e eklenmiş olmalı; Play App Signing parmak izi uygulama Play'e yüklenince Console'dan alınır).
8. **Apple tarafı.** App Store Connect, Apple Developer üyeliği, Sign in with Apple anahtarı (.p8), APNs anahtarı, Team ID: Apple hesabı oturumu/2FA gerekir. **Mac/Xcode archive** gerekli (`docs/IOS_MAC_HANDOFF.md`). iOS Firebase uygulaması (`GoogleService-Info.plist`) için Bundle ID `com.senmiydin.app` ile kayıt Firebase konsolunda yapılabilir; Mac'te kullanılacak.
9. **Instagram Story doğrudan paylaşımı** için Meta'dan bir Facebook App ID (gizli değil) alıp `--dart-define=INSTAGRAM_FACEBOOK_APP_ID=` verilmeli; verilmezse paylaşım normal Android paylaşım sayfasından (Instagram orada Story hedefi olarak çıkar) yapılır.

## Yapılmadı / iddia edilmiyor

- Play Console'da uygulama kaydı, mağaza girişi, bildirimler (App Access, Data Safety, içerik derecesi), Closed Testing sürümü ve rollout **yapılmadı** (madde 4).
- App Store Connect kaydı/metadata/gizlilik/yaş derecesi **yapılmadı** (madde 8); iOS archive iddia edilmez.
- Üretim backend dağıtımı, SMTP teslim testi, canlı HTTPS web doğrulaması (madde 1–3).
- Release-imzalı derlemede Google giriş turu, resmî In-App Review'in gerçek Play'de görünmesi, AdMob'dan gerçek doluluk (yeni reklam birimleri ~1 saat içinde aktifleşir; reklam gelmezse yerleşim boşluk bırakmaz — test ve kodda doğrulanmıştı).
- Firebase projesi, kullanılmayan bir Cloud projesine eklendi (hesabın proje kotası dolu); istersen yeni bir proje kotası artışıyla taşınabilir. Proje adı "SenMiydin", `com.senmiydin.app` dışında uygulama yok.
