# Demo veri ve karşılaşma medyası doğrulaması — 9 Kasım 2026

Sayısal son eklerin kaynağı canlı API veya serializer değildi. Entegrasyon testleri millisecondsSinceEpoch değerini karşılaşma başlığına/gövdesine ve sosyal içeriklere ekliyordu. Eski sosyal testler ayrıca kalıcı QA hesapları oluşturup bırakıyordu. Görünen büyük portreler, test galerilerinin user_0.jpg / user_1.jpg avatar dosyalarını gerçek post_media olarak yüklemesinden geliyordu.

Yeni testlerde başlık/gövde/bio/yorum/mesaj doğal metindir. UUID yalnızca istek idempotency alanında ve özel çalıştırma kimliğinde kullanılır. Oluşan gönderi ve karşılaşmalar API'nin döndürdüğü kayıt ID'leriyle izlenir. Test galerileri coast.jpg ve sunset.jpg kullanır.

## Sahiplik ve temizleme

tool/pixel_fixtures.php yalnız local/development/testing ortamında çalışır. Gerçek geliştirme veritabanı için ayrıca MySQL / 127.0.0.1 / 33076 kontrol edilir. Production reddedilir. Her çalıştırmaya dokuz ayrı rol hesabı ve rastgele parola atanır; kayıt testi için ayrılmış onuncu kimlik vardır. Parola ve sahiplik defteri yalnız ignored .local/pixel-fixtures.json içinde kalır; Dart tanımları ayrı ignored dosyadadır.

run_pixel_regression.ps1 kayıt testinin oluşturduğu hesap ID'sini günlük işaretinden hemen deftere kaydeder. Sonlandırma/finally yolunda da işareti arar. Beklenmedik bir kayıt kesintisinde reserved email ile yalnız kendi oluşturduğu kimliği geri bulur. Temizleme, defterdeki kesin hesap ID/email sahipliğini doğrular; başka katılımcı içeren istek/sohbet varsa silmeyi reddeder. Kayıt testi tarafından zaten anonimleştirilmiş hesap da önceden kaydedilmiş ID ile temizlenir.

Sadece sahipli kullanıcıların içerikleri ve ilişkileri silinir: post/medya, yorum, beğeni/kayıt/takip, istek/karşılaşma/ortak hikâye, Yolculuk detayı, mesaj/sohbet, bildirim/eşleşme, konum/geçmiş, token/cihaz. Medya dosyaları kesin UUID yollarıyla mevcut kalıcı media_deletions outbox'ına alınır. Sahiplik dışındaki kullanıcı ve gönderinin korunması otomatik testle doğrulanır. Normal Demo/Elif hesabı cihaz regresyonunda mutasyon için kullanılmaz; mevcut yakınlık örneği yalnız okuma gözlemcisidir. Son assertion Demo başlık/gövdesinde 13 haneli timestamp veya UUID son eki kalmadığını kontrol eder.

Önceki yerel veriler, özel .local envanteri ve kayıt alanları ve sahipliği tekrar karşılaştırılan kesin kayıt listesi üzerinden bir defa temizlendi. 17 bilinen eski test hesabı, Demo/Elif'e ait 25 eski test postu, 17 istek ve 11 mesajlı bir test sohbeti doğrulandı. Bu 25 sayısı test hesaplarıyla cascade silinen sosyal gönderilere ek olarak ölçülmüştür. Özel geri dönüş yedeği .local altında tutulur; kullanıcı verisi/parola rapora eklenmez. Üretim reset komutu veya genel içerik wildcard silme yolu eklenmedi.

DemoDataSeeder yalnız geliştirmede açıkça çağrılır. İki idempotent örnek: fotoğrafsız “Sahilde ikinci merhaba” ve gerçek sahil/gün batımı fotoğraflı “Birlikte bir sahil yürüyüşü”. Katılımcı avatarları ayrı kalır.

## Ortak medya kuralı

PostResource.media yalnız post_media ilişkisini serialize eder. story_participants.avatar kimlik alanıdır. socialPost yalnız media listesinden images üretir. PostMediaView, hem PublishedEncounterCard hem PostCard içinde tek ortak gösterim kuralıdır: images boşsa SizedBox.shrink; doluysa gerçek ImageCarousel. Avatar fallback'i yoktur.

FeaturedEncounterCarousel görünen sayfanın doğal yüksekliğini ölçer. Başka sayfadaki fotoğraf, fotoğrafsız sayfanın yüksekliğini büyütmez. İki küçük avatar, durum, başlık ve açıklama korunur. Fotoğrafsız kartta büyük görsel/medya sayacı/fotoğraf oku bulunmaz. İki fotoğrafta sayaç 1/2 → 2/2 olur.

## Kontroller

- Laravel: 103 test / 1240 assertion geçti; önceki 95 test korundu.
- Flutter: 59 test geçti; önceki 53 test korundu.
- flutter analyze: sorun bulunmadı.
- Dört yeni widget durumu: featured/feed × boş/iki gerçek medya; ayrıca karışık featured sayfalarında doğal yüksekliğe dönüş ve test metni kaynak kontrolü.
- İki API testi: iki avatar varken boş medya ve yalnız iki gerçek medya, hem feed hem featured response.
- Altı temizleme/veri kalitesi testi: tüm ilişki türlerinin temizliği, başka kimlikleri koruma, bozulmuş defter/legacy kimliği reddi production koruması ve timestamp/UUID sızıntısını silmeden tespit etme ve CLI’nin gerçek süreçte açılıp production’ı veri değiştirmeden reddetmesi.
- Pixel 6a: dokuz gerçek API senaryosu 6 dakika 29 saniyede geçti; helper exit 0 ve otomatik finally temizliği başarılı. On sahipli hesap, on gönderi ve bir sohbet kaldırıldı; Demo suffix assertion temiz. Parolasız kayıtlar docs/pixel-cleanup-audit.json ve docs/demo-data-quality-audit.json içindedir. Medya baytları da yeniden kodlanmış coast.jpg/sunset.jpg ile birebir eşleşti.
