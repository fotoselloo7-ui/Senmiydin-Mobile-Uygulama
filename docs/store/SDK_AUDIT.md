# SDK ve privacy manifest audit — 9 Kasım 2026

Kaynaklar: pubspec.yaml / pubspec.lock, .dart_tool/package_config.json, .flutter-plugins-dependencies; gerçek Gradle releaseRuntimeClasspath ve processReleaseMainManifest çıktısı. Paketler güncellenmedi. Ağ kimliği, provider hesabı veya final görsel oluşturulmadı.

## Android gerçek release bağımlılıkları

Gradle komutu: `android/gradlew.bat :app:dependencies --configuration releaseRuntimeClasspath :app:processReleaseMainManifest --console=plain`. Sonuç BUILD SUCCESSFUL; signing/mağaza paketi gerektirmez. Ham kayıt ignored .local/store-android-dependencies.log içindedir. “x → y” satırlarında seçilen sürüm y’dir.

| Bileşen | Kilitli / seçilen sürüm | Kullanım / veri etkisi |
|---|---|---|
| firebase_core | Flutter 4.0.0; Firebase BOM 34.0.0, firebase-common 22.0.0 | Gerçek public tanımlar varsa Firebase başlatma |
| firebase_messaging | Flutter 16.0.0; native firebase-messaging 25.0.0 | İsteğe bağlı push; device token / app sürümü / notification metadata |
| Firebase Installations / transport | installations 19.0.0; datatransport 18.2.0 | FCM’nin transitive kurulum kimliği/teknik iletimi |
| google_sign_in | 7.2.0; android 7.2.18; play-services-auth 21.6.0 | Yalnız gerçek OAuth IDs varsa giriş; provider subject/email/name |
| geolocator | 14.1.2; android 5.2.1; play-services-location 21.2.0 bağımlılığı | Uygulama Android’de forceLocationManager=true ile OS LocationManager yolunu seçer; high accuracy mümkün, opt-in history FGS |
| image_picker | 1.2.4; android 0.8.13+25 | Seçilen fotoğraf / dış kamera intent’i; geniş medya veya CAMERA manifest izni yok |
| flutter_map / latlong2 | 8.3.2 / 0.10.1 | HTTPS tile ve attribution; bağımsız sağlayıcı IP/tile bölgesini alır |
| http | 1.6.0 | API ve medya; release HTTPS guard |
| flutter_secure_storage | 11.2.0 | Oturum/device tercihlerinin yerel güvenli saklanması; biyometri izinleri çıkarılmış |
| share_plus | 13.3.1 | Kullanıcının başlattığı paylaşım ve OS share sheet |
| url_launcher | 6.3.3; android 6.3.33 | Harici attribution/store/destek bağlantıları |
| package_info_plus | 10.2.2 | App sürüm kontrolü ve isteğe bağlı device kayıt sürümü |
| sign_in_with_apple | 8.2.0 | Gerçek servis/callback kurulumuyla alternatif giriş |

Reklam SDK’sı (AdMob/Google Mobile Ads, Meta Audience Network vb.), billing, Analytics engine, Crashlytics, Sentry, AppsFlyer veya Adjust bağımlılığı bulunmadı. Native **firebase-measurement-connector 19.0.0** vardır; bu bağlayıcının varlığı firebase-analytics ölçüm motorunun kurulu olduğu anlamına gelmez. Özel analytics event çağrısı yoktur. Firebase Messaging/Installations teknik SDK verileri yine gizlilik tablosundan çıkarılmaz.

Birleşik release manifestte AD_ID, AD_SERVICES_*, BILLING, CAMERA, geniş storage/media, ACCESS_BACKGROUND_LOCATION, mikrofon, rehber veya biyometri izni yoktur. FCM’den WAKE_LOCK, ACCESS_NETWORK_STATE ve c2dm.RECEIVE gelir. Mevcut gereksiz biyometri remove kuralları korunur; kaldırılacak ek reklam izni bulunmadı. Tam matris PERMISSIONS.md.

Firebase auto-init Android ve iOS’ta kapalıdır. PushClient gerçek yapılandırma ve kullanıcı izin/tercihiyle etkinleşir. Varsayılan config/production.json yalnız HTTPS API adresini içerir; canlı FCM/OAuth verisi icat edilmedi. SDK kaynakları ve son etkin release define’ları birlikte değerlendirilmelidir.

## iOS kaynak privacy manifest envanteri

Bu Windows denetiminde erişilebilen, gerçekten kilitli plugin kaynakları:

| iOS/Darwin paket | Manifest durumu / declaration |
|---|---|
| firebase_messaging 16.0.0 | ios/.../Resources/PrivacyInfo.xcprivacy var; tracking=false; UserDefaults / CA92.1 |
| flutter_secure_storage_darwin 0.4.3 | Manifest var; tracking=false; empty accessed-API/collected-data arrays (wrapper) |
| geolocator_apple 2.4.3 | darwin/.../PrivacyInfo.xcprivacy var; tracking=false |
| google_sign_in_ios 6.4.0 | Manifest var; tracking=false (wrapper) |
| image_picker_ios 0.8.13+14 | Manifest var; tracking=false |
| package_info_plus 10.2.2 | iOS manifest var; tracking=false |
| share_plus 13.3.1 | iOS manifest var; tracking=false |
| url_launcher_ios 6.4.2 | iOS manifest var; tracking=false |
| firebase_core 4.0.0 | Wrapper’da ayrı manifest bulunmadı; podspec Firebase/CoreOnly native SDK’sına bağımlı, sdk_version=12.0.0. Native framework manifesti Mac’te denetlenecek |
| sign_in_with_apple 8.2.0 | Ayrı kaynak manifest bulunmadı; native AuthenticationServices wrapper. Kullanmadığı API için sahte reason eklenmedi |
| path_provider_foundation 2.6.0 | Dart/FFI objective_c implementation; native Pod/Swift plugin olmayan yapı. Ayrı xcprivacy bulunmadı; dosya yolu erişimini file timestamp/disk-space API kullanımı diye varsayma |
| Flutter engine, Firebase native frameworks, GoogleSignIn native framework ve transitives | Gerçek Mac çözümlemesi/çıktısı yok; binary manifest/signature ve aggregate report **WAITING** |

GoogleSignIn podspec aralığı >=9.0,<11.0’dır; gerçek native seçilmiş sürüm Podfile.lock/Package.resolved olmadan sabitlenmiş gibi raporlanmaz. Wrapper boş collected array’i uygulamanın hesap/konum/mesaj toplamadığı anlamına gelmez.

## App-level PrivacyInfo.xcprivacy kararı

Runner’da app-level PrivacyInfo.xcprivacy yoktur. Runner AppDelegate/SceneDelegate uygulama kodunda doğrudan UserDefaults, dosya timestamp, disk space veya system boot-time required-reason çağrısı tespit edilmedi; işlevler ilgili Flutter/plugin tarafındadır. Kanıtlanmamış reason code veya yanlış “no data collected” beyanı eklenmedi. Mevcut firebase_messaging UserDefaults gerekçesi kendi paket manifestinde bulunur.

SDK bağımlılıklarında required-reason API kullanımı varsa onların manifestleri final app bundle’a gerçekten dahil olmalıdır. Bu, yalnız kaynak dosyanın varlığına bakılarak tamamlandı sayılamaz.

## Mac’te kalan zorunlu doğrulama

Mevcut Windows-generated iOS kayıtları SPM disabled gösteriyor; GeneratedPluginSwiftPackage boş, Podfile/Podfile.lock ve tamamlanmış native dependency resolution yok. Bu geçici dosyalar iOS entegrasyonunun tamam olduğuna kanıt değildir. Mac’te desteklenen Flutter/Xcode ortamında plugin/CocoaPods veya ilgili SPM çözümlemesi ve generated wiring yeniden doğrulanmalı; generated dosyalar elle sahte dependency listesiyle doldurulmaz.

Gerçek native bağımlılıkları çöz, release archive oluştur; archive’daki PrivacyInfo.xcprivacy dosyalarını ve listed SDK imzalarını kontrol et. Xcode Privacy Report’u GOOGLE_PLAY_DATA_SAFETY / APPLE_PRIVACY_LABELS ve gerçek provider kullanımına karşılaştır. Eğer app/native ek API kullanımı ortaya çıkarsa yalnız doğru ve kanıtlanan reason’lar eklenir. Gerçek iOS izin/ret/limited photos, background-free location, APNs ve OAuth cihaz testleri yapılır. Windows’ta Xcode build/Privacy Report veya SDK signature validation yapıldı denmez.

Kaynaklar: [Apple SDK listesi](https://developer.apple.com/support/third-party-SDK-requirements/), [required-reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [Firebase Android](https://firebase.google.com/docs/android/play-data-disclosure), [Firebase Apple](https://firebase.google.com/docs/ios/app-store-data-collection), [Google Sign-In native release notes](https://developers.google.com/identity/sign-in/ios/release).
