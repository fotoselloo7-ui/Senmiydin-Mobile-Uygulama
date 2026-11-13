# Doğrulama

> **Güncel kaynak bu dosyanın ilk bölümüdür (13 Kasım 2026).** "Tarihsel kayıt" bölümü 10 Kasım 2026 çalışmasını olduğu gibi korur; oradaki sayılar ve tasarım ifadeleri (ör. mavi marka dili, herkese açık profildeki ilgi etiketleri) güncel durum değildir.

## Release candidate sertleştirme — 13 Kasım 2026 (2. tur, güncel)

Başlangıç `23125a5` (109 test / 1405 assertion, Flutter 98, analyze temiz, Pixel 9/9, location-time 3/3 doğrulandı). Yeni özellik eklenmedi; yalnız gerçek cihaz / güvenlik denetiminde bulunan iç sorunlar düzeltildi.

| Kontrol | Final |
|---|---|
| Laravel | **117 test / 1545 assertion geçti** (`release_check` içinde `composer test`) |
| Flutter | **99 test geçti**; `flutter analyze`: No issues found |
| Pixel 6a entegrasyon | **9/9 geçti**, fixture temizliği `clean=true` |
| Pixel 6a location-time | **3/3 geçti** |
| `tool/release_check.ps1` | Teknik adımların hepsi OK (analyze, testler, composer, migration, paket kimlikleri, seeder koruması, secret taraması). `MISSING` olanlar yalnız dış bağımlılık / production yapılandırması: Android signing, SMTP, FCM, Google/Apple OAuth, APP_URL HTTPS, mağaza URL'leri, operatör/legal, production yönetici |

Bulunan ve düzeltilen gerçek problemler:

1. **Pixel fixture otomasyonu** — `demo_ahmet`'in `user_locations.city_id` değeri NULL kalabiliyor ve yakınındakiler testi elle DB düzeltmesi gerektiriyordu. Kök neden: `demo:refresh-locations` yalnız zaman damgasını yeniliyordu, koordinat/şehri geri yazmıyordu. `DemoDataSeeder::restoreLocations()` artık her tohum hesabın koordinat ve açık şehrini deterministik yazıyor; seeder ve komut ortak kullanıyor (`DemoFixtureTest`). Regresyon elle müdahalesiz geçti.
2. **Onboarding metni** — "İlgi alanların profilinde görünsün" final kararla (public profilde hobi yok) çelişiyordu; metin düzeltildi.
3. **Profil hata durumu** — sunucu kapalıyken Profil sekmesi düz mavi metin gösteriyordu; mevcut `InlineState` + "Tekrar Dene" kartına geçti ve uygulama yeniden başlatılmadan toparlanıyor (`profile_refresh_test`).
4. **`PushDelivery` log sürücüsü** production'da bildirim kimliklerini loga yazabiliyordu; production'da yazmıyor (`DeliveryReadinessTest`).
5. **`tool/release_common.ps1`** — Windows PowerShell 5.1'de Composer'ın stderr satırı yönlendirilmiş komutu sahte "FAIL" yapıyordu. Yalnız çıkış kodu belirleyici oldu; teknik hata ile dış bekleme ayrımı doğru raporlanıyor.
6. **Eksik regresyon testleri**: kapak güvenliği (`CoverSecurityTest`: sahte uzantı, MIME uyuşmazlığı, SVG, bozuk görüntü, boyut/8 MB, EXIF GPS, dosya adı sızıntısı, eski kapak silme, hesap silmede temizlik, askıya alınmış/yasaklı hesap, traversal) ve block'un bildirim / sohbet / okunmamış sayaç filtrelemesi + unblock.

Gerçek Pixel 6a senaryoları (normal debug uygulama, local API): clean install (Splash → onboarding → kayıt → profil → ilgi alanları → izin açıklamaları → Ana Sayfa); konum izni DENY ile uygulama kullanılabilir, manuel şehir Alanya, akış görünür, anonim gönderi yayımlandı, izin döngüsü yok; bildirim izni reddi ile uygulama içi bildirim merkezi çalışıyor; Geçtiğim Yerler varsayılan KAPALI, açınca örnek yazıldı, uygulama arka plana alınınca location foreground service (tip 0x8) sürdü ve yeni örnek geldi, kapatınca geçmiş ve eşleşmeler silindi, servis durdu, yeni örnek gelmedi; process kill sonrası token geri yüklendi ve Ana Sayfa açıldı; duyuru admin panelinden oluşturuldu → Bildirimler'de göründü → dokununca duyuru ayrıntısı → pasifleştirince "Bu içerik artık kullanılamıyor"; minimum sürüm: admin formu resmî mağaza bağlantısı olmadan minimum sürümü reddediyor ("Minimum sürüm için resmî mağaza bağlantısı gerekli"); doğrulamayı atlayıp değer doğrudan yazıldığında uygulama kırık bağlantı açmamak için kapıyı kurmadı ve Ana Sayfa'ya devam etti — sahte mağaza bağlantısı üretilmediğinden gerçek cihazda "Güncelleme gerekli" ekranı gösterilemedi (EXTERNAL: gerçek Play adresi); kapı mantığı mevcut `production_test.dart` widget testiyle doğrulanır, değer geri alındı; API durdurulunca Ana Sayfa / Mesajlar / Bildirimler "İçerik yüklenemedi · Tekrar Dene" gösterdi, API açılınca yeniden başlatmadan toparlandı; polling ölçümü (API günlüğü): açık sohbette ~4,5 sn (7 istek / 32 sn, yalnız sohbet uçları), kök sayaçlar ~8 sn (4 istek / 32 sn), arka planda 0 istek, ön plana dönüşte hemen 1 sayaç isteği; yazı taslağı arka plana gidip gelince korundu; 1,6× yazı tipinde Ana Sayfa, Profil, Mesajlar ve Compose'da taşma yok; anonim gönderi başka hesaptan `author:null`, ad / kullanıcı adı / avatar / e-posta sızmıyor; hesap silme sonrası token 401, profil 404, arama ve yakında listesinde yok, konum / geçmiş / eşleşme / cihaz / token kayıtları silindi, cihazda oturum login ekranına döndü.

Sınırlar: hesap silme formundaki "SİL" onay metninin noktalı İ harfi `adb input text` ile yazılamadığı için bu turda elle yazılmadı; aynı form her Pixel regresyonunda (`account_test.dart`) gerçek UI'dan çalıştırılıp geçiyor. Silme bu turda uygulamanın gönderdiği aynı gövdeyle API üzerinden çağrılıp cihazdaki etkisi gözlendi. Tam TalkBack sertifikasyonu iddia edilmez (Flutter semantics widget testleriyle, 1,6× yazıyla görsel olarak denetlendi). Force-stop sonrası konum kaydı iddia edilmez.

Kapak dosyaları `GET /api/v1/covers/{uuid}.jpg` ile kimlik doğrulamasız sunulur — bilinçli: herkese açık profil kapağı. Yalnız aktif bir kullanıcının `covers/` altındaki bağlı dosyası sunulur; UUID regex'i, traversal / yetim dosya / askıya alınmış / yasaklı / silinmiş hesap için 404 testlidir.

---

## Ürün tamamlama doğrulaması — 13 Kasım 2026 (1. tur)

Başlangıç (`db90b1e`, değişiklik öncesi) ile final karşılaştırması:

| Kontrol | Başlangıç | Final |
|---|---|---|
| Laravel `php artisan test` | 105 test / 1303 assertion | **109 test / 1405 assertion geçti** (+4 test: kapak yükleme, public profil gizliliği, scheduler/7 gün saklama, public web akışı) |
| `flutter analyze` | No issues found | **No issues found** |
| Flutter `flutter test` | 96 geçti | **98 geçti** (+2: kapak yükleme, kişi satırında şehir yok) |
| Pixel 6a entegrasyon (`tool/run_pixel_regression.ps1`) | — (başlangıçta koşulmadı) | **9/9 geçti**, sahipli fixture temizliği `clean=true` (`tool/run_pixel_regression.ps1 -SkipClean`) |
| Pixel 6a location-time (`-Suite location-time`) | — | **3/3 geçti** |

Hiçbir test silinmedi, atlanmadı veya assertion'ı gevşetilmedi. Entegrasyon testlerinde yalnızca kilitli final arayüzle ve bu çalışmadaki kararla uyumsuz bulucular güncellendi: "Profili Düzenle" etiketi, ikinci "Paylaşım oluştur" semantiği için `compose-button` anahtarı, kişi satırlarında artık şehir olmadığı için `@kullanıcıadı` (önceki `@kullanıcıadı · şehir`) bulucusu ve boş bulucuda çöken kaydırma yardımcısı.

Gerçek cihaz / tarayıcı kanıtları: Pixel 6a (`Pixel_6a`, emulator-5554) üzerinde normal debug uygulama, local API `http://127.0.0.1:8000/api/v1`; admin paneli → mobil uçtan uca: Yakınındaki İnsanlar modülü kapatıldı → mobil Ana Sayfa'dan kayboldu → yeniden açıldı; bakım modu açıldı → mobil bakım ekranı → kapatıldı → uygulama normale döndü (`docs/screenshots/ui-audit/e2e-module-disabled.png`, `e2e-maintenance.png`). Duyuru ve minimum sürüm akışları testlerle (`AdministrationTest`, `ProductionReadinessTest`) doğrulandı; bu turda cihazda ayrıca denenmedi. Public web: 1200 px masaüstü ve 390 px mobil tam sayfa görüntüleri `docs/screenshots/web-final/` altındadır; yatay taşma yok, mobil menü çalışıyor.

Dış bağımlılıklar (Firebase/FCM, Google/Apple production, APNs, SMTP, Android keystore, alan adı/sunucu/SSL, gerçek operatör ve legal bilgileri, App Store / Play Store adresleri) bu çalışmada sahte değerle doldurulmadı: EXTERNAL / WAITING.

---

# Doğrulama — 10 Kasım 2026 (tarihsel kayıt)

Güncel çalışma mobil UI/UX denetimi ile uçtan uca ürün bütünlüğü (mobil + Laravel API + Admin panel + Public web) tamamlamasıdır. [Ürün bütünlüğü denetimi](PRODUCT_GAP_AUDIT.md), [41 yüzeylik envanter](UI_AUDIT.md), [tasarım sistemi](UI_DESIGN_SYSTEM.md) ve [cihaz/ekran kanıtları](UI_AUDIT_VALIDATION.md) birlikte okunmalıdır. Önceki [store hazırlık raporu korunur](test-history/validation-2026-11-09-before-ui-audit.md); [store paketinin gerçek yayın kapıları](store/README.md) değişmedi.

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| Flutter test | **83 geçti**; birleşik filtre ve UI kalite regresyonları dahil | `flutter test` |
| Flutter analyze | **No issues found** | `flutter analyze` |
| Android normal debug APK | **Başarılı**, `lib/main.dart` | [Checksum](apk-checksum.json) |
| APK bütünlüğü | **1 kernel_blob.bin, 0 mükerrer ZIP entry** | [Checksum](apk-checksum.json) |
| Laravel test | **105 test / 1303 assertion geçti** | `php artisan test` |
| Pixel 6a | Normal Demo UI walkthrough; birleşik filtre, harita, akış ve bildirim kontrolü | [UI doğrulaması](UI_AUDIT_VALIDATION.md) |
| Mobil ekran kanıtları | İstenen 24 dahil 32 gerçek PNG tek tek incelendi (`03-filters.png` güncellendi) | [Screenshot indeksi](UI_AUDIT_VALIDATION.md#tek-tek-görsel-kontrol) |
| Web & Admin kanıtları | Public web (5 PNG) ve Admin panel (12 PNG) olmak üzere **17 gerçek browser ekran görüntüsü** | `docs/screenshots/web-admin-audit/` |
| Geçici veri temizliği | **10 sahipli kullanıcı, 0 test postu/sohbet; clean=true** | [Temizlik](ui-pixel-cleanup-audit.json) |

Ürün tanımındaki 29 ekranın hiçbiri eksik değildi. Profil taslak koruması, birleşik feed filtreleri (`Karşılaşmalar + Fotoğraflı + 10 km + Yeni`), bildirim hedefi erişilebilirlik kontrolü (`available`), uygulama içi + push bildirim tercihlerinin ortak uygulanması, duyuru yaşam döngüsü (`is_active`, `expires_at`), admin engellemeler/modüller/roller/kullanıcı moderasyon geçmişi ve public web yolculuk anlatısı tamamlandı. Home sırası korundu; sabit sayı/sahte online işareti kaldırıldı.

Normal uygulama Demo hesabıyla Pixel 6a Ana Sayfa'da açık bırakıldı; [güncel ekran](screenshots/pixel6a-current.png) bunun kanıtıdır. Fotoğrafsız ve anonim gönderi kuralları, gerçek medya, konum/zaman/yolculuk ve mesaj polling davranışları korundu.

İşlevsel sınırlar: harita yalnız desteklediği mesafe parametrelerini uygular, arama ilgi alanına göre insan aramaz. Tam TalkBack/VoiceOver, iOS fiziksel cihaz ve tüm temiz-kurulum izin varyantları ayrıca doğrulanmalıdır. Final logo, production provider/signing/legal/store bilgileri ve mağaza gönderimi bu çalışmanın dışındadır; [STORE_READINESS.md](STORE_READINESS.md) geçerlidir.
