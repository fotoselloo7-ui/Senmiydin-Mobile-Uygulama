# Android / iOS izin matrisi

Denetim: 9 Kasım 2026. Kanıt yalnız source manifest değildir: Gradle :app:processReleaseMainManifest birleşik release manifesti de üretildi. İmzalı APK/AAB veya iOS archive üretilmedi.

## Android

| Teknik izin | Release manifest | Amaç / tetikleyen özellik | Zorunluluk / ekran | Ret ve fallback |
|---|---|---|---|---|
| INTERNET | Var, normal | API, özel medya, HTTPS harita tile, yapılandırılmış auth/push | Ağ özellikleri için normal install izni; runtime prompt yok | Ağ yoksa hata/tekrar dene; sahte başarı yok |
| ACCESS_COARSE_LOCATION | Var, dangerous | Şehir çözümleme, yakın kişiler, harita/konum, opt-in geçmiş | İsteğe bağlı; onboarding “Cihaz konumu”, Home yakınlık retry, Gizlilik ve Konum, konum seçimleri | Manuel şehir ve temel feed/mesaj kullanımı; OS approximate seçiminde yaklaşık durum |
| ACCESS_FINE_LOCATION | Var, dangerous | Aynı özelliklerde kullanıcı izin verirse hassas GPS | İsteğe bağlı; coarse/fine Android sistem penceresi | Precise reddi/approximate seçimi desteklenir; hiç izin yoksa manuel şehir |
| ACCESS_BACKGROUND_LOCATION | **Yok** | İstenen “Always” izni yok | Talep edilmez | Opt-in Android location FGS ayrı mekanizmadır; background policy muafiyeti iddiası yok |
| FOREGROUND_SERVICE | Var, normal | Geçtiğim Yerler devam eden konum servisi | Kullanıcı özelliği açarsa; runtime permission diyaloğu değil | History kapatılır; temel uygulama devam eder |
| FOREGROUND_SERVICE_LOCATION | Var, normal | Android 14+ location tipindeki FGS | Aynı opt-in akış; while-in-use konum grant gerekir | Servis başlatılamazsa kayıt çalışıyor gibi gösterilmez; gerçek OS testi gerekli |
| POST_NOTIFICATIONS | Var, Android 13+ runtime | Gerçek yapılandırılmış FCM bildirimleri; FGS görünürlüğü OS kurallarına tabidir | İsteğe bağlı; onboarding Bildirim veya Bildirim Ayarları, PushClient::setEnabled | Push kapalı; in-app bildirim merkezi çalışır. FGS konum izniyle aynı değildir |
| CAMERA | **Yok** | image_picker dış kamera uygulaması/intent | Kamera eylemi isteğe bağlı | Kamera app yoksa/iptalde hata veya seçili mevcut metin; yeni kamera izni eklenmez |
| READ_MEDIA_IMAGES / READ_MEDIA_VIDEO / READ_EXTERNAL_STORAGE / WRITE_EXTERNAL_STORAGE | **Yok** | Sistem photo picker, kullanıcı seçimi ve URI erişimi | Fotoğraf ekle, profil/mesaj seçimi isteğe bağlı | İptal/ret durumunda metinle devam; geniş galeri taraması yok |
| RECORD_AUDIO / READ_CONTACTS / ACTIVITY_RECOGNITION | **Yok** | Ses, rehber tarama veya aktivite SDK özelliği yok | Talep edilmez | — |
| com.google.android.gms.permission.AD_ID / AD_SERVICES_* / BILLING | **Yok** | Reklam / IAP yok | Talep edilmez | — |
| USE_BIOMETRIC / USE_FINGERPRINT | **Yok**, source merger remove | Güvenli depolamanın kullanılmayan biyometri izni çıkarılmış | Talep edilmez | Parola/secure-storage akışı |
| WAKE_LOCK / ACCESS_NETWORK_STATE | Birleşik manifestte var | Firebase/transport altyapı bağımlılıkları | Normal izin; runtime prompt yok | Yapılandırılmamış push başarılı sayılmaz |
| com.google.android.c2dm.permission.RECEIVE | Birleşik manifestte var | FCM receiver | Normal Google altyapı izni | Push isteğe bağlı |
| com.senmiydin.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION | Birleşik manifestte var, signature | AndroidX özel dinamik receiver koruması | Kullanıcı runtime izni değil | — |

GeolocatorLocationService location tipindedir. Foreground service yalnız uygulamada başlatılmış history tercihiyle background sürer; detached/force-stop/OS sonlandırmasına dayanıklılık garantisi yoktur.

## iOS

| Yetki / Info.plist anahtarı | Mevcut durum | Amaç / ekran | Zorunluluk | Ret ve fallback |
|---|---|---|---|---|
| NSLocationWhenInUseUsageDescription | Var | Şehir, yakındaki kişiler, uygulama açıkken history; cihaz konumu/onboarding/ayarlar | İsteğe bağlı | Manuel şehir, temel akış; Precise kapalıysa reduced accuracy |
| NSLocationAlwaysAndWhenInUseUsageDescription / NSLocationAlwaysUsageDescription | **Yok** | Always istenmez | Talep edilmez | iOS history yalnız foreground |
| UIBackgroundModes=location | **Yok** | Sürekli iOS background location etkin değil | Talep edilmez | Android davranışı iOS’a kopyalanmaz |
| NSPhotoLibraryUsageDescription | Var | Seçilen profil/gönderi/mesaj fotoğrafı | İsteğe bağlı; picker/OS sürümüne göre izin/selected-photo erişimi | İptalde metinle devam; tüm galeri okunuyor iddiası yok |
| NSPhotoLibraryAddUsageDescription | Yok | Fotoğraf arşivine kaydetme ürünü yok | Talep edilmez | — |
| NSCameraUsageDescription | Var | Paylaşım oluştur → Kamera | İsteğe bağlı | Seçim/ret/hata halinde yükleme yapılmaz |
| Notifications / UNUserNotificationCenter | Gerçek push kurulumu varsa runtime | Onboarding veya Bildirim Ayarları | İsteğe bağlı | In-app inbox devam eder |
| aps-environment | $(PUSH_APS_ENVIRONMENT) | APNs capability; gerçek provisioning gerekli | Canlı push için gerekli dış kurulum | Gerçek teslimat WAITING |
| UIBackgroundModes=remote-notification | Var | APNs/push bildirimi | Konum yetkisi değildir | Background location diye beyan edilmez |
| NSMicrophoneUsageDescription / NSContactsUsageDescription / NSUserTrackingUsageDescription | Yok | Ses/rehber/ATT tracking özelliği yok | Talep edilmez | — |
| com.apple.developer.applesignin | Var | Gerçek Apple Sign In etkinleştirilirse | Alternatif giriş; parola girişi mevcut | Gerçek Team/key/capability yokken başarı iddiası yok |

Windows denetimi source plist/entitlement ve plugin kaynaklarıyla sınırlıdır. Mac’te archive, birleşik privacy report ve gerçek iOS cihaz izin/ret/limited-photo testleri beklenir.

Kanıt: android/app/src/main/AndroidManifest.xml, build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml, ios/Runner/Info.plist, ios/Runner/Runner.entitlements, lib/data/location_service.dart, lib/data/push_client.dart, lib/screens/auth.dart, lib/screens/settings.dart, lib/screens/compose.dart.
