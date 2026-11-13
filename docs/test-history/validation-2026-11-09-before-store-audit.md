# Doğrulama — 9 Kasım 2026

Bu tur kullanıcıya sızan test metinleri, Demo veri temizliği ve karşılaşma medyası üzerinde çalışıldı. Mevcut ürün, Ana Sayfa düzeni, renkler ve konum-zaman/Yolculuk davranışları korundu. Önceki 95 Laravel / 53 Flutter raporu [arşivde](../test-history/validation-2026-11-09-before-demo-quality.md) saklanır.

## Son otomatik sonuçlar

| Kontrol | Sonuç | Kayıt |
|---|---|---|
| Laravel / composer test | **103 test, 1240 assertion geçti** | .local/laravel-demo-quality.log |
| Flutter test | **59 test geçti** | .local/flutter-demo-quality.log |
| Flutter analyze | **Sorun bulunmadı** | .local/analyze-demo-quality.log |
| Pixel 6a gerçek API | **9 senaryo, 6 dakika 29 saniye; helper exit 0** | .local/pixel-release-regression.log, .local/pixel-demo-quality-run.log |
| Otomatik finally temizliği | **10 sahipli hesap, 10 gönderi ve 1 sohbet ilişkileriyle temizlendi** | [Temizleme denetimi](../pixel-cleanup-audit.json) |
| Kalıcı Demo medyası | **İki küçük avatar; medya sayıları 0 ve 2** | [Medya/veri denetimi](../demo-data-quality-audit.json) |
| Demo Ana Sayfa | **17 Alanya gönderisinin tamamı görüldü; 0 internal metin sızıntısı, 0 tekrarlı gönderi gövdesi** | Ekranlar ve UIA metin envanteri |
| Normal APK | Tek kernel_blob.bin; yinelenen ZIP girdisi yok; Pixel 6a kurulumu başarılı | [APK bilgisi](../apk-checksum.json) |

Mevcut 95 Laravel ve 53 Flutter testinin tamamı korunur. Sekiz yeni Laravel testi medya serialization, sahiplik/temizleme, timestamp/UUID sızıntısı ve gerçek CLI açılış korumasını doğrular. Altı yeni Flutter testi featured/feed × fotoğrafsız/iki gerçek medya, karışık pager sayfalarında doğal yükseklik ve cihaz testi metin üretimini kapsar.

Pixel senaryoları: kayıt/profil/oturum/hesap silme; sosyal akış/yorum/beğeni/kayıt/takip/arama; konum/mesafe/harita/gizlilik; fotoğraflı ortak karşılaşma onay/red/yayın; fotoğrafsız ortak karşılaşma; mesajlaşma/istek/okundu/fotoğraf/engelleme/şikâyet; Ankara ↔ Alanya; geçmiş konum-zaman/eşleşme/feed boost/tek bildirim; Pamukkale Ankara → Erzincan / 07 NM 365.

## Kaynak ve düzeltme

Zaman damgaları entegrasyon testlerindeki millisecondsSinceEpoch değerinin görünen başlık ve gövdeye eklenmesinden geliyordu. Testler artık doğal metin, disposable hesaplar ve API'nin döndürdüğü kayıt ID'lerini kullanır. UUID yalnız teknik request_id ve özel çalıştırma defterinde kalır.

Büyük portrelerin kaynağı, eski test galerilerinin user_0.jpg / user_1.jpg avatar dosyalarını gerçek hikâye medyası olarak yüklemesiydi. Backend media dizisi ile participant avatarları zaten ayrıydı; feed ve featured yanıtlarını denetleyen yeni testlerle bu ayrım korunur. Galeriler artık coast.jpg / sunset.jpg kullanır. Kalıcı Demo dosyalarının hash'leri de bu iki kaynağın JPEG yeniden kodlamasıyla birebir eşleşti.

PostMediaView featured ve normal feed için aynı gerçek medya kuralını kullanır. Medya boşsa büyük görsel, boş medya alanı, sayaç veya fotoğraf oku oluşmaz. Featured pager yalnız görünen kartın doğal yüksekliğini kullanır; başka sayfadaki fotoğraf boş sayfayı büyütmez.

Ayrıntılar: [Demo veri ve medya kuralları](../DEMO_DATA_QUALITY.md).

## Veri temizliği

Önceki bilinen yerel test kayıtları, özel envanter, yedek ve kesin ID/sahiplik karşılaştırmalarıyla temizlendi: 17 eski test hesabı; Demo/Elif üzerinde 25 eski karşılaşma postu, 17 istek ve 11 mesajlı bir test sohbeti. Test hesaplarının sosyal gönderileri ve ilişkileri de kendi hesap ID'leriyle kaldırıldı. Bilinen test hesapları dışındaki kullanıcı içerikleri korundu.

Yeni helper yalnız local/development/testing ortamında çalışır; gerçek geliştirme DB'si için ayrıca MySQL / 127.0.0.1 / 33076 kontrolü yapar. Production reddedilir. Dokuz rol hesabı ve kayıt senaryosunun onuncu hesabı ignored sahiplik defterinde ID ile izlenir. Finally temizliği gönderi/yorum/beğeni/kayıt/takip, istek/karşılaşma/hikâye, Yolculuk, sohbet/mesaj, bildirim/eşleşme, konum/geçmiş ve oturum ilişkilerini temizler. Medya kesin UUID yollarıyla mevcut media_deletions outbox'ına alınır. Sahiplik dışındaki katılımcıyla karşılaşma/sohbet varsa silme reddedilir. Normal Demo hesabına test içeriği yazılmaz.

Son koşu sonunda iki özel fixture dosyası kaldırıldı; temizleme assertion'ları ve Demo suffix denetimi başarılıdır. Parolalar rapora eklenmez.

## Korunan konum-zaman ve Yolculuk davranışları

Aktif şehir Ankara ↔ Alanya değişirken profil Alanya kaldı. Geçmiş yer/saat seçimi, gerçek eşleşme, feed boost ve tek doğru gönderi bildirimi geçti. Pamukkale Ankara → Erzincan / 07 NM 365 metadata ve öneri sinyali geçti; grup veya aynı araçta bulunma iddiası eklenmedi. Backend EXIF/GPS yeniden kodlama, özel metadata, izinler, tekrar/spam ve moderasyon testleri de geçti.

## Normal Pixel 6a önizlemesi

Entegrasyon hedefinden sonra üretilen dizinler proje sınırı ve reparse-point kontrolüyle temizlendi. Analiz ve 59 Flutter testi yeniden geçti; normal lib/main.dart debug hedefi derlendi ve yalnız Pixel_6a / emulator-5558 üzerine kuruldu.

Demo hesabıyla gerçek API'ye giriş yapıldı. Alanya konumu ve yakın kişiler yüklendi; 400 m örneği görüldü. Ana Sayfa son gönderiye kadar incelendi. Büyük avatar medya fallback'i, test suffix'i, bozuk medya, metin taşması veya tekrarlı gönderi gövdesi görülmedi. İki fotoğraflı featured ve feed kartlarında 1/2 → 2/2 kontrolü normal Demo oturumunda ayrıca doğrulandı.

Uygulama normal Demo Ana Sayfasında, fotoğrafsız featured kart seçiliyken açık bırakıldı.

| Görüntü | Dosya |
|---|---|
| Son Ana Sayfa / fotoğrafsız featured | [pixel6a-current.png](../screenshots/pixel6a-current.png) |
| Featured gerçek fotoğraf 1/2 | [pixel6a-featured-photos.png](../screenshots/pixel6a-featured-photos.png) |
| Featured gerçek fotoğraf 2/2 | [pixel6a-featured-photos-second.png](../screenshots/pixel6a-featured-photos-second.png) |
| Normal feed gerçek fotoğraf 2/2 | [pixel6a-feed-photos-second.png](../screenshots/pixel6a-feed-photos-second.png) |
| Normal feed fotoğrafsız ortak hikâye | [pixel6a-home-audit-02.png](../screenshots/pixel6a-home-audit-02.png) |
| Akışın sonu | [pixel6a-home-audit-06.png](../screenshots/pixel6a-home-audit-06.png) |

Tam akış görüntüleri screenshots/pixel6a-home-audit-01.png–06.png dosyalarındadır. Metin envanteri gerçek Alanya akışındaki 17 gönderi gövdesinin tamamıyla eşleştirildi.

Normal debug APK 170.798.638 bayt; SHA-256 2C2E6078B1C5B4EF01CA149B1DADC5B1B71AB9FD7D86159C14ABA72C3624BB4B. Paket/sürüm com.senmiydin.app / 0.1.0+1 korunur. Bu tur Firebase, domain, release signing veya mağaza yayını çalışması yapılmadı.

Galeri test adaptörü gerçek JPEG dosyalarını gerçek API'ye yükledi. Native sistem galeri penceresi veya dış sağlayıcı teslimatı bu turun doğrulama kapsamı değildir.
