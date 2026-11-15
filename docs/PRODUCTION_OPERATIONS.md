# Yayın operasyonu durumu — 15 Kasım 2026

Bu belge gerçek hesaplarda (kullanıcının oturum açık Chrome'u üzerinden) ne yapıldığını, neyin kanıtlandığını ve neyin **yalnızca insan müdahalesiyle** ilerleyebileceğini söyler. Hiçbir gizli değer (API anahtarı, servis hesabı, keystore parolası) bu repoda yoktur: hepsi ignored dosyalarda veya repo dışındadır.

## 2. tur durum özeti (en güncel) — 15 Kasım 2026

**Alan adı:** gerçek production alan adı `senmiydin.tr` (kodda ve mağaza metinlerinde `senmiydin.com` yerine kullanıldı). **WAITING:** DNS `31.186.11.254`'e çözülüyor ama bu adres TürkTicaret.Net "park" sayfası (Apache/2.2 CentOS), **HTTPS (443) kapalı**, `/api/v1/health` ve `/app-ads.txt` 404. Barındırma / sunucu / SSL yok; bu yüzden üretim backend dağıtımı, SMTP teslim testi, web sayfaları, `app-ads.txt`, App Links doğrulaması ve Data Safety / Gizlilik URL'si bekliyor.

**Mağaza adları:** Google Play / App Store İngilizce: `Was It You? Reconnect`, Türkçe: `SenMiydin? Tekrar Karşılaş` (`docs/store/localization/`, ASO metinleri yeniden yazıldı; paket/bundle `com.senmiydin.app` değişmedi).

**Release çökmesi düzeltildi.** R8, WorkManager'ın Room veritabanını siliyordu; release derlemesi açılışta çöküyordu (`Failed to create an instance of androidx.work.impl.WorkDatabase`). `android/app/proguard-rules.pro` ile düzeltildi. Önceki yüklemeler (sürüm 1–4) geçersiz sayılmalı; güncel paket **sürüm 6 (0.1.0+6)**, kapalı test sürümüne yüklendi (imzalı AAB, 85,6 MB). Sürüm 6 ayrıca **konum ön plan hizmetini kaldırır**: "Geçtiğim Yerler" yalnızca uygulama açıkken kaydedilir; `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` ve `ACCESS_BACKGROUND_LOCATION` izinleri manifestten çıkarıldı, bu yüzden Play'in ön plan hizmeti demo videosu şartı geçersiz.

| Alan | Durum |
|---|---|
| Google Play uygulaması | `SenMiydin?` / `com.senmiydin.app`; İngilizce (en-US) giriş **Was It You? Reconnect**, Türkçe (tr-TR) giriş **SenMiydin? Tekrar Karşılaş**; kısa/tam açıklama TR+EN taslak olarak kaydedildi; kategori **Sosyal** |
| Play beyanları | Reklam, Reklam Kimliği, Finans, Sağlık, Resmi kurum, **İçerik derecelendirme (IARC, kullanıcı onayıyla)** tamam. **WAITING:** Gizlilik URL'si, Oturum açma bilgileri (App Access), Hedef kitle, Veri güvenliği, Satıcı (tüccar) durumu, mağaza iletişim e-postası. (Ön plan hizmeti beyanı/videosu artık gerekmiyor: hizmet kaldırıldı.) **Veri güvenliği formu CSV içe aktarma ile dolduruldu** (`PSL_*` sorularının tümü; gönderim Hedef kitle'ye bağlı) |
| Kapalı test | Kanal "Alpha" oluşturuldu: ülke **Türkiye**, tester listesi mevcut **Guncel Gundem** listesi (46 kullanıcı; üyelere dokunulmadı), geri bildirim e-postası hesap adresi. Sürüm taslağı + TR/EN notlar hazır; Console kurulum görevleri (yukarıdaki WAITING) bitmeden gönderim/rollout engelli. Hesapta 12 tester / 14 gün şartı görünüyor |
| Play App Signing | SHA-256 `23:18:38:73:AB:3E:65:57:7D:C0:B7:AE:65:E5:4F:22:B4:93:16:F4:00:E1:35:D3:8A:2C:C1:B6:DA:A8:78:E8`, SHA-1 `F9:CE:9E:FF:E8:2C:9C:57:C2:F8:2B:B8:14:13:80:97:26:07:64:10`; Firebase'e eklendi |
| Firebase | Proje `pelagic-core-448613-p0` ("SenMiydin"); Android uygulaması debug/upload/Play SHA'larıyla; **iOS uygulaması `com.senmiydin.app` eklendi**, `GoogleService-Info.plist` ignored `ios/Runner/` içinde (Mac'e aktarılacak) |
| AdMob | Android + iOS uygulamaları ve native birimleri (önceki tur); **UMP (AB/UK/İsviçre) mesajı yayında** (2 uygulama, EN + TR, gizlilik URL'si `https://senmiydin.tr/gizlilik`); app-ads.txt doğrulaması alan adı bekliyor |
| Apple | Team ID `7YH3522U6V`; **App ID `com.senmiydin.app`** kayıtlı (Sign in with Apple, Push Notifications, Associated Domains; In-App Purchase varsayılan olarak açık, kullanılmıyor) |
| App Store Connect | Uygulama kaydı **`Was It You? Reconnect`** (id 6835031308), birincil dil English (U.S.), SKU `senmiydin-ios-1`; Türkçe yerelleştirme **`SenMiydin? Tekrar Karşılaş`**; EN + TR alt başlık, tanıtım metni, açıklama, anahtar kelimeler, destek/pazarlama URL'si, inceleme notları kaydedildi; kategori **Social Networking**; **yaş derecelendirme anketi tamam (hesaplanan 13+, 16+ olarak yükseltildi)**. **WAITING:** App Privacy, telif hakkı, inceleme hesabı, gizlilik URL'si canlılığı, build (**WAITING FOR MAC / TestFlight**), APNs / Sign in with Apple anahtarları |
| Mağaza görselleri (15 Kasım 2026) | ChatGPT ile tasarlandı (8 ekran × EN/TR + feature graphic arka planı); `tool/make_store_graphics.py` ile kesin ölçülere çıkarıldı (Play 1080×2160 + 1024×500 + 512 ikon; App Store 1179×2556 / 1320×2868). **Play** varsayılan (en-US) ve tr-TR girişlerine yüklendi (taslak), **App Store Connect** English (U.S.) ve Turkish Dynamic Island (medium) yuvasına yüklendi. iOS hedefi yalnız iPhone yapıldı (iPad ekran görüntüsü gerekmez). Görseller repo dışında: `C:/Users/pc/store-screenshots/final/` |
| iOS build / TestFlight | **WAITING FOR APPLE SIGNING SECRETS** — `.github/workflows/ios-testflight.yml` + `docs/IOS_TESTFLIGHT_CI.md`; hiç çalıştırılmadı (Mac yok) |

**Yaş.** Kayıt ekranındaki yaş değeri tek kaynaktan gelir (`AppStore.minimumAge`, sunucu `MINIMUM_AGE`). Kullanıcının isteğiyle varsayılan ve `.env.example` **18** yapıldı. Üretim `.env` içinde `MINIMUM_AGE=18` olmalı. **Karar bekliyor (EXTERNAL):** Mağaza metinleri / Data Safety / App Store derecesi hâlâ "16+" ve genç (16–17) grubu anlatıyor: kayıt yaşı kalıcı olarak 18 olacaksa bu metinler ve yaş derecesi (App Store 18+) birlikte güncellenmelidir.

## Önceki tur: yapıldı ve doğrulandı (tarihsel)

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

AAB SHA-256: `c4ceae11a057de43492e3f80baa56e55f7657fbe7f11e8dafcd1ae8f990ea60c` (`build/app/outputs/bundle/release/app-release.aab`, ignored). Aynı girdilerle yeniden derlenince aynı özet çıktı.

### Google Play Console (15 Kasım 2026, gerçek hesapta)

| Alan | Durum |
|---|---|
| Uygulama kaydı | **Oluşturuldu**: `SenMiydin?`, `com.senmiydin.app`, varsayılan dil en-US, Uygulama, Ücretsiz. İki hukuki beyan (Developer Program Politikaları + ABD ihracat yasaları) kullanıcının sohbette verdiği açık onayla işaretlendi |
| Paket yükleme | İmzalı AAB **Dahili test** taslağına yüklendi ve Play tarafından kabul edildi: sürüm 1 (0.1.0), API 24+, hedef SDK 36. TR/EN sürüm notları girildi. **Taslak olarak kaydedildi, yayına (rollout) alınmadı** |
| Play App Signing | Etkin. SHA-256 `23:18:38:73:AB:3E:65:57:7D:C0:B7:AE:65:E5:4F:22:B4:93:16:F4:00:E1:35:D3:8A:2C:C1:B6:DA:A8:78:E8`, SHA-1 `F9:CE:9E:FF:E8:2C:9C:57:C2:F8:2B:B8:14:13:80:97:26:07:64:10`. İkisi de Firebase Android uygulamasına eklendi (Google ile giriş) |
| Beyanlar | **Kaydedildi:** Reklam (içeriyor), Reklam Kimliği (kullanıyor; amaç reklam), Finans (özellik yok), Sağlık (özellik yok), Resmi kurum (hayır) |
| İçerik derecelendirme | **Tamamlandı** (IARC şartları kullanıcının sohbette verdiği açık onayla kabul edildi; iletişim e-postası kullanıcının seçimiyle Play hesap adresi). Kategori Sosyal; arkadaşlık amaçlı değil, çıplaklık/şiddet/tam konum/dijital satın alma yok, engelleme ve bildirme var, sohbet proaktif denetlenmiyor, etkileşim yalnız davetlilerle sınırlı değil. Sonuç 12+ / Teen düzeyi (ESRB Teen, PEGI 12 vb.). 16+ ürün kuralı Hedef kitle beyanında ayrıca girilecek |
| Beyan bekleyen | Gizlilik politikası URL'si, Oturum açma bilgileri, Hedef kitle (oturum açma bilgilerine bağlı), Veri güvenliği, Satıcı durumu |

Uygulama imzalama SHA-256 değeri, backend'de `ANDROID_APP_LINK_SHA256` içine **upload** SHA-256 (`2F:19:26:8B:…:BC:C9`) ile birlikte virgülle girilmelidir (assetlinks.json iki sertifikayı da sunar).

## HUMAN ACTION REQUIRED (yalnızca sen yapabilirsin)

1. **Üretim alan adı.** `senmiydin.tr` DNS'te **çözülmüyor** (kayıtlı/yönlendirilmiş değil). Alan adını kaydet/yönlendir, HTTPS kur. Gizlilik, KVKK, hesap silme, `app-ads.txt` ve paylaşım bağlantıları buna bağlı. Release AAB `https://senmiydin.tr/api/v1` adresini kullanır; farklı alan için `API_BASE_URL` ve `APP_LINK_HOST` değiştirilip yeniden derlenir.
2. **Üretim sunucusu.** Sunucu/barındırma erişimi yok: `APP_ENV=production`, `APP_DEBUG=false`, üretim DB, kuyruk işçisi (`queue:work database` — `DeliverPush` `database` bağlantısını kullanır), zamanlayıcı cron'u, özel depolama, sağlık ucu `docs/DEPLOYMENT.md` adımlarıyla kurulacak. `.env` içine: `PUSH_DRIVER=fcm`, `FCM_PROJECT_ID`, `FCM_CREDENTIALS` (sunucudaki servis hesabı dosyası), `GOOGLE_CLIENT_IDS`, `ADMOB_PUBLISHER_ID`, `ANDROID_APP_LINK_SHA256` (Play App Signing + upload SHA-256), `APPLE_TEAM_ID`.
3. **SMTP.** host, port, kullanıcı adı, parola, gönderen adresi. Şifre sıfırlama e-postası gerçek teslim testi bundan sonra.
4. **Google Play Console — kalan beyanlar (uygulama oluşturuldu, yukarıdaki tablo).** Senin yapman gerekenler:
   - **Gizlilik politikası URL'si** (alan adı canlı olunca) ve **Oturum açma bilgileri**: gerçek bir inceleme hesabı (kullanıcı adı/parola) gerekir; üretim backend'i olmadan oluşturulamaz, uydurulmadı (`docs/store/REVIEW_ACCOUNT.md`).
   - **Hedef kitle** (16+; oturum açma bilgileri bitmeden açılmıyor), **Veri güvenliği** (`docs/store/GOOGLE_PLAY_DATA_SAFETY.md`; canlı HTTPS/aktarım şifrelemesi doğrulanmadan gönderilmez), **Satıcı durumu** (tüzel kişilik beyanı).
   - **Ana mağaza girişi**: metinler `docs/store/localization/`'da hazır; öznitelik görselleri (512 simge, 1024×500 öne çıkan grafik, ekran görüntüleri) ve iletişim/web/gizlilik/hesap silme URL'leri girilecek.
5. **Closed test.** Console, kurulum görevleri bitmeden Kapalı testi kilitli tutuyor. Tester e-posta listesi yok (**HUMAN ACTION REQUIRED: tester e-postaları**) ve Console bu hesapta üretime başvuru için "en az 12 tester, en az 14 gün" şartını gösteriyor (şart geçerli). Dahili test taslağı hazır; kurulum görevleri bitince aynı AAB Kapalı teste de yüklenir.
6. **AdMob.** UMP (Gizlilik ve Mesajlaşma → Avrupa tüzükleri) mesajı **yayınlanmadı**: oluşturma sihirbazı Chrome'da askıda kaldı. Uygulama listesinden iki SenMiydin uygulamasını seç, gizlilik politikası URL'sini (gerçek alan adı hazır olunca) ekle, yayınla. Ayrıca uygulamalar mağazada yayınlanınca AdMob'da "Mağaza ekle" ve app-ads.txt doğrulaması.
7. **Google ile giriş testi** (gerçek Google hesabı parolası/2FA): yapılandırma tamam; emülatörde/cihazda gerçek hesapla `Google ile devam et` denenmeli (release imzalı derlemeyle upload + Play App Signing SHA-1'leri Firebase'e eklenmiş olmalı; Play App Signing parmak izi uygulama Play'e yüklenince Console'dan alınır).
8. **Apple tarafı.** App Store Connect, Apple Developer üyeliği, Sign in with Apple anahtarı (.p8), APNs anahtarı, Team ID: Apple hesabı oturumu/2FA gerekir. **Mac/Xcode archive** gerekli (`docs/IOS_MAC_HANDOFF.md`). iOS Firebase uygulaması (`GoogleService-Info.plist`) için Bundle ID `com.senmiydin.app` ile kayıt Firebase konsolunda yapılabilir; Mac'te kullanılacak.
9. **Instagram Story doğrudan paylaşımı** için Meta'dan bir Facebook App ID (gizli değil) alıp `--dart-define=INSTAGRAM_FACEBOOK_APP_ID=` verilmeli; verilmezse paylaşım normal Android paylaşım sayfasından (Instagram orada Story hedefi olarak çıkar) yapılır.

## Yapılmadı / iddia edilmiyor

- Play Console'da ana mağaza girişi, App Access, Data Safety, içerik derecesi, hedef kitle, Closed Testing sürümü ve **rollout yapılmadı** (madde 4–5). Uygulama kaydı ve Dahili test taslağı vardır.
- App Store Connect kaydı/metadata/gizlilik/yaş derecesi **yapılmadı** (madde 8); iOS archive iddia edilmez.
- Üretim backend dağıtımı, SMTP teslim testi, canlı HTTPS web doğrulaması (madde 1–3).
- Release-imzalı derlemede Google giriş turu, resmî In-App Review'in gerçek Play'de görünmesi, AdMob'dan gerçek doluluk (yeni reklam birimleri ~1 saat içinde aktifleşir; reklam gelmezse yerleşim boşluk bırakmaz — test ve kodda doğrulanmıştı).
- Firebase projesi, kullanılmayan bir Cloud projesine eklendi (hesabın proje kotası dolu); istersen yeni bir proje kotası artışıyla taşınabilir. Proje adı "SenMiydin", `com.senmiydin.app` dışında uygulama yok.


## İletişim adresleri (15 Kasım 2026)

Destek: `destek@senmiydin.tr`, genel / KVKK iletişimi: `info@senmiydin.tr`. Üretim `.env` içinde `PUBLIC_SUPPORT_EMAIL=destek@senmiydin.tr` ve `PUBLIC_CONTACT_EMAIL=info@senmiydin.tr` olmalı (`backend/.env.example` böyle); uygulamada Ayarlar > Destek ve Hakkında altında `destek@senmiydin.tr` satırı var. **Posta kutularının gerçekten açılması gerekir** (hosting/e-posta kurulumu kullanıcıda). Repo herkese açık olduğundan telefon numarası burada yazılmaz.
