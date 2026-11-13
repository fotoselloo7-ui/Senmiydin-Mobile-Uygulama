# Release audit — 8 Kasım 2026

Bu audit mevcut kod ve yerel MySQL schema'sını esas alır. Üretim ölçeğinde yük testi iddiası değildir; gerçek sunucu donanımı/verisi geldiğinde slow query log ve EXPLAIN sonuçları yeniden değerlendirilir.

## Sorgular, sayfalama ve indeksler

| Alan | Yapı / sınır | Erişim ve indeks |
|---|---|---|
| Şehir / popüler / yakın feed, saved, profil postları | simplePaginate 20, ortak forViewer eager loading + count/exists alt sorguları | posts city/visibility/deleted/created/id; user/deleted/created/id; story/city indeksi |
| Kullanıcı adı / kişi arama | username prefix + yardımcı ad araması; 20'lik sayfa; etiket autocomplete en fazla 20 | unique username, active/city/id; contains-name taraması wildcard olduğu için B-tree'den mucize beklenmez |
| Follow / likes / saves | benzersiz çiftler ve ters erişim indeksleri; follower/following 20 | mevcut primary/unique ve reverse pair indeksleri |
| Yorumlar | 20'lik sayfa, author eager loading | post/deleted/id |
| Nearby kullanıcılar | doğrulanmış radius, en fazla 30; varsayılan 20 | city/visibility/lat/lng ve recorded_at; kullanıcı active/city/id |
| Harita | en fazla 80 | posts_region_index; sınırlı bölge sorgusu |
| Karşılaşma istekleri / profil / featured | 20'lik sayfalar, ilişkiler batch | requester/status/created, target/status/created, request unique, published story/city, featured rank |
| Sohbet listesi | 20; son mesaj ve unread SQL alt sorgusu; peer + city ve mesajlar batch | first/updated, second/updated, participant user/conversation, message conversation/id ve read/id |
| Mesajlar | cursor before/after, en fazla 30 + has_more sentinel | conversation/id |
| Bildirimler | 20; actor city ve announcement batch | user/read/id ve user/id |
| Admin kullanıcı / post / yorum / report | paginate 25; gerekli ilişkiler eager / join | user active/city/id, posts mevcut indeksleri, reports status/id |
| Admin audit / support / announcements | paginate 25 | primary id, publish_at / request type-created |

Yeni migration yalnızca iki eksik erişim yolunu ekler: reports(status,id) ve users(account_status,city_id,id). Eski migrationlar değiştirilmedi. Diğer indeksler mevcut; gereksiz fulltext, spatial veya çok sayıda tekrarlı indeks eklenmedi. LIKE %kelime% içerik / ad aramaları, alt sorguyla popüler sıralama ve mesafe hesaplama büyük veriyle ölçülmelidir; bunlar sınırlı sayfalama kullansa da indekslerin tüm hesaplamayı ortadan kaldırdığı iddia edilmez.

Mevcut SocialApiTest feed için query üst sınırı ve pagination'ı korur. Yeni ReleaseOperationsTest sohbet ve bildirim sayısı artınca sorgu sayısının sabit kalmasını ve 20'lik sayfayı doğrular. PublicUserResource yüklenmeyen ilişkiler için gizli lazy query üretmez. Admin rapor listesi doğrudan query builder, kullanıcı listesi city eager loading kullanır.

Kataloglar yalnızca public cities/interests alanlarını 5 dakika cache eder. Admin değişikliği ilgili anahtarı hemen invalid eder. Settings request-scoped kalır; kullanıcı tokenı, profil, özel mesaj, konum veya unread ortak cache'e alınmaz. Redis zorunlu değildir.

## Rate limit

| İşlem | Limit |
|---|---|
| Kayıt | 5 / dakika / IP |
| Giriş | 30 / dakika / IP, aynı kimlik + IP 5 |
| Şifre kurtarma | 5 / dakika / IP |
| Post | 15 / dakika / kullanıcı |
| Yorum | 30 / dakika / kullanıcı |
| Like / save / follow | 120 / dakika / kullanıcı |
| Search | 90 / dakika / kullanıcı |
| Location yazma / okuma | 12 yazma, 60 okuma / dakika / kullanıcı |
| Encounter aksiyonu | 30 / dakika / kullanıcı |
| Communication okuma / mesaj yazma | 120 / 40 dakika başına kullanıcı |
| Şikâyet | routes/api.php üzerindeki sınırlı endpoint throttle |
| Public contact / deletion form | 10 dakikada 5 / IP, CSRF |
| Admin login | 15 / dakika / IP; aynı kimlik + IP 5 |
| Health | 60 / dakika / IP |

Yeni kör mutation retry eklenmedi. API istemcisi timeout/socket/TLS hatalarını kullanıcı diline çevirir; 401 oturumu temizler, 403/404/422/429 mesajları güvenli JSON sözleşmesini kullanır, 500+ iç hata içeriğini gizler, bakım 503 mesajını korur. Polling yalnızca okuma yenilemelerinde makul backoff uygular.

## Polling ve konum

Açık sohbetin normal aralığı 4 saniye, ana shell sayaçları 8 saniyedir. Route örtülünce veya uygulama foreground dışına çıkınca timer iptal edilir. Geri dönünce hemen bir yenileme yapılır. İstekler üst üste binmez; hata halinde aralık 2 kat artar ve en fazla 120 saniye olur; başarı normal aralığa döner. Dispose timer/observer/route kaydını kaldırır. Root counter açık sohbetin arkasında paralel çalışmaz.

Geçtiğim Yerler varsayılan kapalıdır. LocationService kullanıcı opt-in'i olmadan background stream yayını yapmaz; kapatma stream'i keser. Backend profile değişikliği history/matches temizliğini yapar. iOS background desteği kapalı kalır. Kullanıcı izin vermeden feed / mesajlaşma kullanılabilir.

## Queue, scheduler, silme ve log

Mail ve push işlerindeki dış teslimat HTTP isteğinden ayrıdır. Apple login code exchange kimlik doğrulamanın parçasıdır; onu async yapıp doğrulamadan giriş yapılmaz. Hesap silme fiziksel medya ve Apple revoke kalıcı outbox üzerinden retry edilir.

Bütün kritik zamanlanmış görevler withoutOverlapping kullanır. devices:prune yalnızca 30 günden eski pasif veya tokenı kalmamış cihazları temizler; canlı geçerli cihazları silmez. Scheduler ve worker'ın gerçek sunucuda kurulduğunu kaynak koddan kanıtlamak mümkün değildir; production-check bunu ayrı işletim gereksinimi olarak raporlar.

Production error reporter yalnızca hata türünü kaydeder. Push log/no-op kişisel payload, exact location veya credential dökmez. Production log/array parola sıfırlama maili reddedilir. Mail queue payload'ları şifrelenir. Debug/test fixture reset akışı production'a taşınmaz. AccountDeletionTest token, profil, search, nearby ve private conversation erişimini tekrar doğrular; legal/moderation ilişkilerinde anonim kayıtlar korunur.

Gerçek yerel MySQL schema/EXPLAIN raporu .local/release-schema-audit.json içindedir. Rapor sadece indeksler ve plan metadatasıdır; kullanıcı satırı, credential veya koordinat export etmez. Public crawler .local/release-public-crawl.log içinde 14 route / asset / iç bağlantıyı ve /health sonucunu doğrular.

## Konum-zaman ve Yolculuk genişlemesi

Aktif şehir, occurred_at, post_travel_details ve gerçek skor/bildirim alanları yeni migration ile eklenir. SQL bounding box + şehir + zaman filtresi ve ROW_NUMBER en iyi geçmiş örneği seçer; tüm history PHP belleğine çekilmez. Yeni history_city_time_index, posts_city_occurrence_index, matches_recommendation_index ile travel origin/destination/departure indeksleri denetlendi. Manuel şehir ve profil şehri ayrıdır. Paylaşılan harita noktası post_grid'dir; raw GPS/geçmiş/özel travel bilgisi public resource'a eklenmez. Detaylar LOCATION_TIME_TRAVEL.md içindedir. Yeni queue işi mevcut worker tarafından çalışır; production-check persistent queue gerektirir.
