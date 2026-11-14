# Store readiness — 9 Kasım 2026

> **Güncel ek — 15 Kasım 2026.** Minimum yaş **16** (teen / adult ayrımı sunucuda uygulandı, bkz. [AGE_AND_STORE_READINESS.md](AGE_AND_STORE_READINESS.md)). **Google AdMob eklendi:** Play *Contains ads = YES*, Data Safety / App Privacy / SDK audit / izin matrisi güncellendi (`docs/store/`). Mağaza metni **Türkçe + İngilizce** için `docs/store/localization/{tr-TR,en-US}/` altındadır; Android (`values/`, `values-tr/`) ve iOS (`en.lproj`, `tr.lproj` InfoPlist.strings, `CFBundleLocalizations`) yerelleştirmesi hazırdır — **iOS lproj dosyalarının Xcode projesine eklenmesi Mac'te yapılmalıdır** (pbxproj Windows'ta düzenlenmedi). Gerçek AdMob kimlikleri: `--dart-define=ADMOB_APP_ID_ANDROID=…`, `ADMOB_NATIVE_AD_UNIT_ANDROID=…`, `ADMOB_NATIVE_AD_UNIT_IOS=…`, iOS `ADMOB_APP_ID_IOS` (xcconfig); kimlik yoksa release'te reklam alanı hiç çizilmez, debug'da Google test birimleri kullanılır.

Bu belge mevcut kodu esas alır. Mağaza onayı veya canlı hizmet teslimatı iddiası değildir. Android applicationId ve iOS bundle id: **com.senmiydin.app**. Sürüm/build **0.1.0+1**. Onaylı Home ve mevcut geçici marka korunur.

## Store submission hazırlığı

Credential gerektirmeyen alanlar [store paketinde](store/README.md) hazırdır: iki platformun metadata metinleri, Data Safety/App Privacy matrisleri, permission/SDK audit, background declaration/video planı, UGC, silme/rating, screenshot/graphic planları ve review hesabı süreci. Bunlar doldurulmuş gerçek mağaza kaydı veya onay anlamına gelmez.

Yeni güvenli kontrol: `powershell -ExecutionPolicy Bypass -File tool/store_readiness_check.ps1`. [Son rapor](store/STORE_READINESS_REPORT.md) gerçek legal/operasyon/provider/signing eksiklerini MISSING; Mac, final görsel ve manuel inceleme işlerini WAITING tutar. [Toplu gerçek bilgi listesi](store/REQUIRED_REAL_INFORMATION.md), [branding master gereksinimleri](BRANDING_REQUIREMENTS.md) ve [bu turun doğrulaması](STORE_AUDIT_VALIDATION.md) birlikte kullanılmalıdır. Eski release_check.ps1 korunur. Final logo/screenshot/video, production review hesabı ve credential üretilmedi.

## Android

- [x] Paket kimliği / versionCode 1 / versionName 0.1.0; minSdk 24, targetSdk 36, compileSdk 36.
- [x] Release HTTPS; debug 10.0.2.2 ve ADB reverse ile 127.0.0.1 geliştirmesi.
- [x] R8 derleme altyapısı; gerçek signing yokken açık hata ve debug signing'e geri düşmeme.
- [x] Adaptive / legacy ikon, Android 12 ve önceki splash üretim hattı; mevcut işaret geçicidir.
- [x] Modern photo picker; geniş depolama, kamera, biyometrik veya ACCESS_BACKGROUND_LOCATION izni yok.
- [x] Parola + SİL ile gerçek hesap silme; public hesap silme başvuru rotası.
- [ ] Gerçek upload keystore / alias / parolalar; Play Console ve Play App Signing.
- [ ] Gerçek mağaza URL'si, destek e-postası, veri sorumlusu / hukuk / saklama bilgileri.
- [ ] Final logo, onaylı gerçek store screenshots ve feature graphic. Ürün açıklaması taslağı store paketinde hazır; son işletmeci onayı beklenir.
- [ ] Firebase Android config / server FCM service account; gerçek bildirim teslimatı.
- [ ] Google OAuth kullanılacaksa gerçek Android / web istemcileri ve debug, upload, Play signing SHA kayıtları.
- [ ] Play Console Data safety, içerik derecelendirme, UGC / moderasyon, uygulama erişimi ve inceleme hesabı.
- [ ] Geçtiğim Yerler opt-in location foreground service kullanır. Manifestte background permission olmaması, mağazanın arka plan konum değerlendirmesini tek başına kaldırmaz. Gerçek kullanım, belirgin açıklama, FGS / konum beyanı ve gerekirse inceleme videosu işletmeci tarafından tamamlanmalı. [Google konum politikası](https://support.google.com/googleplay/android-developer/answer/9799150).
- [ ] Gerçek domain üzerinde gizlilik ve hesap silme URL'lerinin erişilebilirliği. [Google hesap silme gereksinimleri](https://support.google.com/googleplay/android-developer/answer/13327111).

Konum geçmişi varsayılan kapalıdır; kullanıcı açmadan background örnekleri gönderilmez. Konum izni reddedildiğinde hesap / feed / mesajlaşma çalışmaya devam eder. Android bildirimi ve foreground service izni, background location izniyle aynı değildir. Yeni izin ekleyerek checklist tamamlanmış sayılmamalı.

## iOS

- [x] Bundle id, merkezi Flutter version/build, amaç açıklamaları, Sign in with Apple entitlement, debug/development ve release/production APS yapılandırma noktaları.
- [x] 19 opak RGB app icon boyutu ve native splash hattı.
- [x] Silme ve yetki iptali entegrasyon noktaları; gerçek Apple anahtarı yokken sahte giriş yok.
- [ ] Apple Developer / App Store Connect hesapları; gerçek Team ID, distribution certificate ve provisioning profile.
- [ ] APNs key / Key ID / Team ID; Firebase iOS plist ve gerçek bildirim kontrolü.
- [ ] Sign in with Apple capability, gerçek Apple key ve gerekiyorsa Android akışı için Service ID / HTTPS callback.
- [ ] Google kullanılacaksa gerçek iOS client id / reverse URL scheme.
- [ ] Gerçek Mac / desteklenen Xcode ile pod install, archive, signing, cihaz testi ve TestFlight.
- [ ] Archive'da Flutter ve bütün SDK privacy manifestlerinin birleştiği Xcode Privacy Report; kullanılan required-reason API'leri ve gerçek veri toplama beyanları. App Store privacy yanıtları işletmeci tarafından gerçek uygulama ve SDK davranışıyla eşleştirilmeli; varsayılan olarak “veri toplanmıyor” denmemeli. [Apple privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [SDK gereksinimleri](https://developer.apple.com/support/third-party-SDK-requirements/).
- [ ] Store screenshots / metadata / support / privacy URL / hesap silme bilgileri / yaş derecelendirmesi.
- [ ] iOS'ta Android tipi sürekli background tracking destekleniyormuş gibi beyan verme. Mevcut LocationDevice iOS'ta background desteğini kapalı tutar; gerçek konum amaçları ve izin reddi cihazda doğrulanmalı.
- [ ] Final logo ve gerçek App Store URL'si.

## Gerçek hizmet dosyaları

Firebase mobile JSON/plist, FCM service-account, Apple .p8, Android keystore ve key.properties kaynak deposuna / release ZIP'ine girmez. Mobile public tanımlayıcılar tool/configure_mobile.py ile ignored config/production.local.json dosyasına alınır. Server sırları mobil define içine konmaz. Ayrıntılı kurulum [DEPLOYMENT.md](DEPLOYMENT.md) içindedir.

Bu Windows çalışmasında gerçek mağaza upload'u, Apple archive, gerçek OAuth hesabıyla giriş, SMTP teslimatı veya gerçek FCM/APNs cihaz teslimatı tamamlandı denmez.

## Konum-zaman / Yolculuk veri beyanı

Güncel ürün, kullanıcı açarsa 7 günlük varsayılan yaklaşık konum geçmişi ve bundan türeyen süreli eşleşme kaydı işler. Geçmiş kaydı ve eşleşme bildirimi ayrı tercihlerdir. Kullanıcının seçtiği olay saati ile şehir ve isteğe bağlı public Yolculuk (firma/sefer/araç tanımlayıcısı dahil) gönderi içeriğidir; kullanıcıya açık paylaşım tercihi sunulur. Canlı araç takibi veya zorunlu yolculuk grubu yoktur. EXIF/GPS upload türevlerinden temizlenir. Varsayılan şehir tespiti yereldir; üçüncü taraf reverse geocoding çağrısı yapılmaz. Store privacy / Data safety formları işletmecinin gerçek kullanımına göre bu davranışları da kapsamalıdır. Ayrıntılar LOCATION_TIME_TRAVEL.md.

## 15 Kasım 2026 RC eki

- **AdMob kimlikleri:** `tool/store_readiness.py` artık "AdMob production identifiers" satırını üretir (yok → `MISSING`, Google örnek yayıncısı `3940256099942544` → `FAIL`, dört gerçek kimlik → `WAITING`). `tool/build_android_release.ps1` gerçek `ADMOB_APP_ID_ANDROID` ve `ADMOB_NATIVE_AD_UNIT_ANDROID` olmadan store AAB'si üretmez (`-AllowNoAds` bilinçli istisna). Kimlikler `python tool/configure_mobile.py --admob-… ` ile ignore edilen `config/production.local.json` / `ios/Flutter/OAuth.xcconfig` dosyalarına yazılır.
- **Android manifest:** `ACCESS_ADSERVICES_ATTRIBUTION` ve `ACCESS_ADSERVICES_TOPICS` kaldırıldı (Privacy Sandbox kullanılmıyor); `AD_ID` reklam entegrasyonu nedeniyle kalır ve Play Data Safety "reklam kimliği" beyanıyla uyumlu olmalıdır. Debug manifest'inde `usesCleartextTraffic` yalnız debug kaynak setindedir; ana manifest `false`.
- **iOS statik:** `InfoPlist.strings (en, tr)` ve `PrivacyInfo.xcprivacy` Xcode projesine bağlandı; `ADMOB_APP_ID_IOS` artık `OAuth.xcconfig` ile geçersiz kılınabilir. Windows'ta Xcode arşivi alınmadı; Mac adımları `docs/FINAL_RELEASE_CANDIDATE.md` içindedir.
