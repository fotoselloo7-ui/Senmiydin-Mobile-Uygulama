# Release freeze

**Başlangıç:** "Complete final messaging media and freeze release" commit'i ile. Bu noktadan sonra yeni özellik, yeni ekran, tasarım değişikliği veya "iyileştirme" **eklenmez**. Ürün özellik olarak tamamdır; geriye kalan iş yayın hazırlığıdır.

## Dondurulan ürün kapsamı

Şehir akışı · paylaşım (metin/fotoğraf/karşılaşma/Yolculuk) · yorum ve beğeni · koleksiyonlar · karşılaşma ve ortak hikâye · Harita ve Harita Notları (isteğe bağlı 1 fotoğraf dahil) · Geçtiğim Yerler · özel mesaj (metin, fotoğraf, konum, **sesli mesaj**, **ücretsiz hediye**, emoji paneli) · bildirimler · engelleme/şikâyet/yönetim · hesap silme · TR/EN · AdMob yerel reklamlar.

Ödeme, jeton, uygulama içi satın alma, sesli/görüntülü arama, rastgele anonim sohbet **yoktur** ve eklenmeyecektir. Hediyeler ücretsizdir; veri şeması ileride ücretli hediyeye hazırdır ama bu sürümde ödeme akışı yoktur.

> **Freeze notu (15 Kasım 2026):** Kullanıcının açıkça istediği dört yayın hazırlığı özelliği freeze'e alındı: Android native splash, göz animasyonu, haftalık değerlendirme daveti ve herkese açık içeriğin dış paylaşım kartı/bağlantısı (`docs/VALIDATION.md` ilk bölüm). Bunlar tamamlanıp test edildi; kapsam yine donuktur.

## Freeze sonrası yalnızca şunlar kabul edilir

1. **Blokaj hatası** — uygulama açılmıyor, giriş/kayıt çalışmıyor, veri kaybı, çökme.
2. **Güvenlik hatası** — yetki aşımı, sızıntı, doğrulama atlama, gizli bilgi açığa çıkması.
3. **Yerelleştirme hatası** — yanlış/eksik TR veya EN metin, dil değişince eski dilde kalan metin.
4. **Gerçek kimlik bilgisi entegrasyonu** — Firebase, Google/Apple giriş, AdMob, push anahtarları; yalnızca yapılandırma, kod davranışı değişmez.
5. **Deployment** — sunucu, HTTPS, veritabanı, depolama, kuyruk/zamanlayıcı, yedekleme.
6. **İmzalama** — Android upload key, Apple sertifika/profil (kimlik bilgisi sahibi yapar).
7. **Mağaza uyumu** — Google Play / App Store formlarının, veri güvenliği ve gizlilik etiketlerinin gerçek değerlerle doldurulması; ret gerekçesinden doğan zorunlu düzeltme.

Bunların dışındaki her istek bir sonraki sürüm listesine yazılır; bu sürüme alınmaz. Her freeze sonrası değişiklik için: neden yukarıdaki yedi maddeden biri olduğu commit mesajında yazılır, ilgili testler çalıştırılır ve `docs/VALIDATION.md`'ye not düşülür.

## Yayın öncesi sabit kontrol listesi

| Kontrol | Komut | Beklenen |
|---|---|---|
| Backend testleri | `cd backend && php artisan test` | hepsi yeşil |
| Statik analiz | `flutter analyze` | sorun yok |
| Flutter testleri | `flutter test` | hepsi yeşil (l10n denetimi dahil) |
| TR/EN denetimi | `python -I tool/l10n_audit.py --all` | 0 eksik |
| Release kontrolü | `tool/release_check.ps1` | FAIL yok; MISSING yalnız dış kimlik bilgileri |
| Android birleşik release manifest | `python -I tool/platform_manifest_check.py android --build` | FAIL yok (AdMob kimliği MISSING olabilir) |
| iOS statik sağlık | `python -I tool/platform_manifest_check.py ios` | FAIL yok — **Xcode derlemesi değildir** |
| Mağaza hazırlığı | `tool/store_readiness_check.ps1` | FAIL yok; WAITING/MISSING dış bilgiler |
| Pixel gerilemesi | `tool/run_pixel_regression.ps1` | 9/9 |
| Konum-zaman | `tool/run_pixel_regression.ps1 -Suite location-time` | 3/3 |

## Dış engeller (kod hazır, kimlik bilgisi/altyapı bekliyor)

Bunlar kodla çözülemez; sahibi sağlamadan "tamam" denmez.

- **Android imzalama anahtarı** (`android/key.properties`) — üretilmedi, uydurulmadı.
- **AdMob gerçek uygulama ve reklam birimi kimlikleri** (Android + iOS) — yoksa release derlemesi reklam göstermez (güvenli varsayılan).
- **Firebase / Google / Apple giriş genel kimlikleri**, APNs anahtarı.
- **Canlı HTTPS alan adı**, yasal/destek sayfalarının yayını, işletici bilgileri, çocuk güvenliği iletişim kişisi, log/yedek saklama politikası.
- **iOS**: Xcode archive, Privacy Report, gerçek cihaz testi, TestFlight — **Mac gerekir** (`docs/IOS_MAC_HANDOFF.md`). Windows'ta yapıldığı iddia edilmez.
- **Mağaza varlıkları**: nihai marka dosyaları, ekran görüntüleri, inceleme hesabı.
- Bilinen uyarı: `emoji_picker_flutter` Kotlin Gradle Plugin'i uyguluyor; Flutter ileride built-in Kotlin zorunlu kılarsa eklenti güncellenmeli ya da değiştirilmeli (şu an derleme sorunsuz).

## Bu sürümde bilinçli olarak yapılmayanlar

Sesli mesajda dalga formu / kaydı kilitleme jesti, GIF/sticker arama, çoklu fotoğraflı Harita Notu, ücretli hediye, hediye animasyonu. Hepsi freeze sonrası sürüm listesindedir.
