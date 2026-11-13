# Aktif şehir, konum-zaman ve Yolculuk

Profilin city_id alanı yaşanılan şehirdir. users.active_city_id / active_city_source ise geçici keşif şehridir. PUT /api/v1/location cihaz koordinatını yaklaşıklaştırır ve CityResolver üzerinden çözer; profili değiştirmez. PUT /api/v1/active-city manuel seçimi tutar. Sonraki güvenilir foreground cihaz örneği aktif şehri günceller. Bilinmeyen şehirde koordinat korunur, manual_city_required döner; manuel keşif temel kullanımı engellemez.

Varsayılan LOCATION_CITY_PROVIDER=boundaries, resources/geography/cities.geojson içindeki açık sınır verisini kullanır. Provider none yapılabilir; CityResolver arayüzü başka uygulama ile değiştirilebilir. API üçüncü tarafa GPS göndermez. Sınır verisi 2021 temsillidir ve sadeleştirilmiştir; kesin kadastro verisi değildir. Kapsam dışı / belirsiz sonuçta şehir uydurulmaz. Veri kaynağı, değişiklik ve lisans atfı resources/geography/README.md içindedir; dağıtım paketine dahildir.

## API

Mevcut /api/v1/posts alanları korunur. Optional alanlar:

- occurred_at: UTC'ye normalize edilen olay zamanı; şu andan ileri veya saklama penceresinden eski olamaz. Eski istemciler alanı göndermeyebilir.
- location_source: current, history veya map. Eski attach_location alanı çalışmaya devam eder.
- history_id: yalnızca oturum sahibinin izinli, süresi dolmamış kaydı. Başkasının kaydı kullanılamaz.
- place_latitude / place_longitude: yalnızca map girdisi; sunucuda mevcut post_grid ile yaklaşıklaştırılır.
- travel: transport_type (bus/train/plane/ferry/other), origin_city_id, destination_city_id, optional departure_at/operator_name/service_code/vehicle_identifier/is_public. Yalnızca travel türü içindir. is_public varsayılan false; kendi sahibi ve yetkili admin dışında private detaylar dönmez. Multipart dosyada nested alanlar travel[transport_type] biçiminde korunur.

GET /api/v1/location-history yalnızca sahibine paginated bölge/saat seçimi sunar. Koordinat dönmez; saat başına yuvarlanır. Geçmiş kapalıysa boş liste döner. Gönderi response'u optional occurred_at, match_hint ve izinli travel içerir; geçmiş satırı/konumu, skor, eşleşen geçmiş saati veya history_id sızdırmaz. Mevcut harita endpoint'i yalnızca yaklaşık post grid noktalarını döndürür; kullanıcı GPS/geçmiş noktaları döndürmez.

## Eşleştirme ve sıralama

MatchLocationPost yeni public gönderi commit'inden sonra kuyruğa verilir. Production database queue ile mevcut worker çalışır; testte sync mümkündür. Job mevcut silinmiş/engellenmiş/private/askıya alınmış içerik ve hesapları tekrar kontrol eder. DB coğrafi bounding box, aynı Europe/Istanbul günü ve history retention filtresi uygular; mesafe ve zaman farkını SQL hesaplar. ROW_NUMBER her kullanıcı için en iyi örneği seçer. PHP'ye bütün history tablosu alınmaz; yalnızca SQL'den seçilmiş en iyi adaylar 100'lük gruplarla işlenir.

location.matching merkezi eşikler: güçlü 500 m / 3600 s / 90; orta 2000 m / 14400 s / 60; aynı yerel gün 5000 m içinde zayıf / 25. Kullanıcı/gönderi primary key duplicate eşleşmeyi önler. Güçlü eşleşmede location_match tercihi açıksa tek gerçek Inbox bildirimi eklenir. Notification_state saklanır; tekrar çalışan job bildirim çoğaltmaz. Kapalı tercihte feed sinyali kullanılabilir, in-app/push üretilmez. PushDelivery yeniden gönderim anında tercih ve history iznini tekrar kontrol eder.

Yolculukta kalkış/varış şehri ve yaklaşık kalkış saati ±1 saat içinde geçmiş örtüşmesi orta öneri üretebilir; mesafe bilinmiyorsa null saklanır. Aynı araç, aynı plaka veya kesin karşılaşma iddiası yoktur. Extra grup/katılım kaydı yoktur.

Yeni sıralamada güçlü/orta/zayıf eşleşme sırasıyla sınırlı saat desteği alır; şehir ve visibility filtresi korunur. Yakın sıralamada mesafe, popüler sıralamada popülerlik korunur. Match işareti doğrulanmış karşılaşma değildir.

## Gizlilik, medya ve moderasyon

History varsayılan kapalıdır. Kaydetme izni, location_match ve nearby_activity bildirim tercihleri ayrıdır. Kapama history/match kayıtlarını temizler; scheduler mevcut 7 günlük varsayılan saklama süresini uygular. Hesap silme yeni active city, occurred_at/place label, travel ve içerik hash alanlarını da temizler.

PrivateImage ortak JPEG decode/re-encode hattı post/avatar/mesaj/ortak hikâyede metadata temizler. Sentetik EXIF GPS fixture ile dört upload akışı doğrulanır. MIME, uzantı, dosya boyutu, boyutlar, decode, bozuk görsel/SVG/double extension kontrolleri korunur. Orijinal dosya adı public URL'ye taşınmaz.

ContentGuard normalize edilmiş tekrar hash'i, kısa süreli tekrar sınırı, mention/link sayısı, operatörün belirlediği ifadeler ve domain/subdomain engeli uygular. Kaynakta keyfi kelime listesi dayatılmaz. Admin mevcut Sistem Ayarları bölümünden listeleri ve makul aralıktaki eşikleri yönetir; post detayında Yolculuk alanlarını görebilir ve aynı moderasyon işleminden kaldırabilir. Public web araç/plaka arama indeksi oluşturmaz.

## Doğrulama

Backend LocationTimeTravelTest aktif şehir, Gülhane geçmiş yer/zaman, güçlü/orta/zayıf eşleşme, feed boost, izinler, tek bildirim, private metadata, Pamukkale Ankara → Erzincan / 07 NM 365, UTC, EXIF ve spam senaryolarını kapsar. Flutter post_context_test form/state/kart/navigasyon testlerini kapsar.

tool/run_pixel_regression.ps1 sekiz mevcut senaryoya fotoğrafsız karşılaşma kontrolünü ekler. tool/pixel_fixtures.php tüm mutasyon senaryolarını dokuz disposable rol hesabına ayırır; kayıt testinin onuncu kimliği ID ile eklenir. tool/location_scenarios.php aynı helper'a uyumluluk girişidir. Helper yalnız bu projenin local/development MySQL'inde açıkça çağrılır; production'da REFUSE eder. Test parolaları rastgele ve ignored .local dosyalarında kalır. Finally yolunda yalnız sahipliği doğrulanmış test hesapları ve ilişkileri temizlenir. Normal Demo hesabına test içeriği yazılmaz. Direkt entegrasyon hedefi fixture tanımları olmadan çalıştırılırsa gerçek API senaryoları skip olur; tam helper tanımları sağlar. Temizleme ve medya kuralları docs/DEMO_DATA_QUALITY.md içindedir.
