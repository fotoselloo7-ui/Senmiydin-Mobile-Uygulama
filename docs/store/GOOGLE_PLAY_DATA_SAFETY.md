# Google Play Data Safety — kod temelli matris

Denetim: 9 Kasım 2026. Bu, mevcut kodun form eşlemesidir. Canlı backend/TLS, işlemci sözleşmeleri, log/yedek saklama ve etkin release define’ları doğrulanmadan nihai Console beyanı gönderilmez. Eksik gerçek değerler [GERÇEK BİLGİ GEREKLİ]. Varsayılan yerel debug HTTP trafiği production şifrelemesi kanıtı değildir.

## Form dili ve ortak koşullar

- Toplama: cihaz dışına API veya SDK aracılığıyla iletim. Yalnız uygulama veritabanını incelemek yeterli değildir.
- S0: kendi backend’ine iletim; tek başına Google’ın üçüncü tarafa paylaşım tanımı değildir.
- S1: kullanıcının bilerek profil/paylaşım/yorum/mesaj yayımlaması veya görünürlüğü açması. Kullanıcı başlatımlı paylaşım istisnası değerlendirilebilir; verinin başkalarına hiç görünmediği anlamına gelmez.
- S2: barındırma, SMTP, FCM/APNs gibi hizmet sağlayıcı. Form paylaşım istisnası ancak gerçek veri işleyen ilişkisi/sözleşmesi ve kullanım amacı uygunsa uygulanır. Sağlayıcı/ülke/retention [GERÇEK BİLGİ GEREKLİ].
- S3: varsayılan OSM tile isteğinde harita bölgesi/tile indeksleri ve IP ağ karşı tarafa gider. Bağımsız sağlayıcının veri rolü doğrulanmadığından yaklaşık harita bölgesi/IP için paylaşım **Evet** yönünde muhafazakâr taslak kullanılır; uygun istisna ancak gerçek dayanakla seçilir. Tam kullanıcı GPS koordinatı tile parametresi olarak gönderilmez.
- Amaç: F=işlevsellik, H=hesap yönetimi, İ=iletişim, G=güvenlik/dolandırıcılık önleme, K=kişiselleştirme. Reklam/pazarlama veya özel analytics amacı kodda yoktur.
- Console amaç eşlemesi: F=App functionality, H=Account management, G=Fraud prevention/security/compliance, K=Personalization. İ, bu tabloda kullanıcı mesajı ve bildirim bağlamını açıklar; kullanıcılar arası mesaj/etkileşim bildirimi App functionality kapsamındadır. Developer communications yalnız gerçekten geliştiriciden uygulama/hesap hakkında iletişim için seçilir; İ geçen her satırda otomatik işaretlenmez. Advertising/marketing veya Analytics amacı eklenmez.
- T: uygulama/API için release HTTPS zorunluluğu kodda mevcut; gerçek production sertifikası ve tüm ağ hedefleri ayrıca doğrulanmalı. Formdaki “encrypted in transit” sorusuna yayın ortamı doğrulanmadan tamamlandı denmez.
- Silme: A=hesap silmede metin/kimlik temizleme veya anonimleştirme; P=kendi paylaşımını silme (normal soft delete ardından 30 gün sonra purge, moderasyonla tutulan kayıtlar ayrı); Hİ=geçmiş kapatıldığında geçmiş/eşleşme silme ve saatlik varsayılan 7 gün purge; M=kesin medya yolları outbox/worker/scheduler ile fiziksel silme; E=cache TTL; O=destek/log/yedek/denetim için gerçek işletmeci retention politikası gerekir.
- Her satırda transit=T. Kullanıcı silme talebi uygulama içi akıştan veya /hesap-silme destek formundan iletilebilir; bu, bütün teknik/denetim/yedek kayıtların anında fiziksel olarak yok olduğu anlamına gelmez.

## Veri türleri

| Gerçek veri | Console veri türü | Toplanıyor? | Paylaşılıyor? (taslak) | Zorunluluk | Amaç | Silme / talep | Kod kanıtı |
|---|---|---|---|---|---|---|---|
| Ad/soyad veya gösterim adı | Personal info / Name | Evet | S1 public profil; S2 | Kayıtta zorunlu | F,H,İ | A; güncellenebilir | AuthController::register, PublicUserResource |
| Kullanıcı adı, hesap ID, sosyal provider subject | Personal info / User IDs | Evet | Public handle S1; provider seçilirse S2 | Temel kimlik zorunlu; sosyal subject isteğe bağlı | F,H,G | A; anonim ilişki ID kalabilir | users, social_identities, IdentityVerifier |
| E-posta | Personal info / Email address | Evet | Diğer kullanıcılara hayır; SMTP/OAuth S2 | Zorunlu | H,İ,G | A; destek/yedek O | AuthController, ProfileResource, Mail |
| Doğum tarihi / yaş kontrolü | Personal info / Other info | Evet | Public API’de doğum tarihi yok; S0/S2 | Zorunlu; mevcut alt sınır 18 | H,G | A | birth_date, AuthController |
| Profil/kapak fotoğrafı | Photos and videos / Photos | Evet, gönderilirse | Profil avatarı S1; S2 | İsteğe bağlı | F,H | A,M; avatar değişiminde eski dosya silinir | ProfileController::uploadAvatar, EraseAccount |
| Bio, meslek/okul, bağlantı tercihleri | Personal info / Other info; App activity / Other user-generated content | Evet, girilirse | Bio/meslek public S1; bağlantı tercihleri public resource’ta yok | İsteğe bağlı | F,H,K | A; düzenlenebilir | ProfileController, PublicUserResource |
| Profil şehri / manuel aktif şehir | Location / Approximate location | Evet | Profil şehri S1; S0/S2 | Profil şehri zorunlu; aktif şehir seçimi değiştirilebilir | F,K | A; şehir güncellenebilir | users.city_id/active_city_id, selectCity |
| İlgi alanları | Personal info / Other info; App activity / Other actions | Evet | Public profil S1 | Onboarding’de en az 5 zorunlu | F,K | A; seçim güncellenir | saveInterests, user_interests |
| Cihaz hassas latitude/longitude/accuracy | Location / Precise location | Evet, izinle | Kesin kullanıcı GPS’i başka kullanıcıya verilmez; S0/S2 | İsteğe bağlı; manuel şehir fallback | F,K | A; aktif konum clear; saklama aşağıda | LocationDevice high, AppStore::_publishPosition, LocationData |
| Yaklaşık cihaz konumu / bölge | Location / Approximate location | Evet, izinle | Yaklaşık mesafe S1; tile bölgesi S3 | İsteğe bağlı | F,K | A,Hİ; tile sağlayıcı retention O | LocationController::nearby/map, live_map.dart |
| Konum geçmişi, saat ve türeyen eşleşme | Location / Precise location + Approximate location; App activity / Other actions | Evet, kullanıcı açarsa | Geçmiş/eşleşme detayı diğer kullanıcıya hayır; S0/S2 | Varsayılan kapalı | F,K,İ (tercihle bildirim) | Hİ,A | user_location_history, location_matches, PostMatcher |
| Gönderi metni, türü, olay saati/yer seçimi, Yolculuk firma/sefer/araç | App activity / Other user-generated content; seçilen konum için Location | Evet, paylaşırsa | Şehir postu S1; private metadata sahibine; S2 | İsteğe bağlı | F,İ,K,G | P,A; travel detayları hesap silmede silinir | PostController, PostResource, post_travel_details |
| Gönderi/hikâye fotoğrafları | Photos and videos / Photos | Evet | Görünürlük/partner onayı S1; S2 | İsteğe bağlı | F,İ,G | P,A,M | post_media, PrivateImage |
| Yorumlar | App activity / Other user-generated content | Evet | S1 public yorum; S2 | İsteğe bağlı | F,İ,G | Kendi yorumunu silme; A | post_comments, PostController |
| Beğeni/kaydetme | App activity / App interactions / Other actions | Evet | Beğeni sayısı/ilgili bildirim S1; kayıt listesi public değil | İsteğe bağlı | F,K,İ | Toggle,A | post_likes, post_saves |
| Takip/engelleme sosyal ilişkisi | Contacts (uygulama sosyal grafiği); App activity / Other actions | Evet | Takip/sayılar S1; engel listesi sahibine | İsteğe bağlı | F,K,G | Takibi/engeli kaldırma,A | user_follows, user_blocks |
| Karşılaşma isteği, kabul/red, ortak hikâye/revizyon | App activity / Other user-generated content / Other actions | Evet | Bekleyen istek taraflarla; yayımlanan hikâye S1 | İsteğe bağlı | F,İ,G | Kaynak/hikâye silme, iptal, A; anonim ilişki kalabilir | EncounterController, encounter_* |
| Mesaj gövdesi, taraflar, okundu ve istek durumu | Messages / Other in-app messages | Evet | Alıcıya S1; şikâyette yetkili moderatör; S2 | İsteğe bağlı | F,İ,G | A kendi mesaj gövdesini temizler; sohbet gizleme fiziksel silme değildir | ConversationController, Message |
| Mesaj görseli | Photos and videos / Photos; Other in-app messages | Evet | Alıcı S1; yetkili şikâyet incelemesi; S2 | İsteğe bağlı | F,İ,G | A,M | messages.image_path, private image endpoint |
| Şikâyet açıklaması, destek talebi, hedef/reporter ID | App activity / Other user-generated content; Personal info (iletilen iletişim) | Evet, iletirse | Public değil; moderatör/SMTP S2 | İsteğe bağlı | G,İ,H | A kendi şikâyet açıklamasını temizler; hedef/durum ve destek kayıtları O | reports, web_requests, SafetyController |
| Push token, uygulama-özel cihaz UUID, FID/APNs, app version | Device or other IDs; teknik sürüm bilgisi için App info/performance değerlendirmesi | Koşullu: gerçek push kurulumunda Evet; varsayılan yapılandırmasız akışta üretilmez | FCM/APNs S2; reklam ağı yok | Push isteğe bağlı | F,İ,G | Devre dışı/token silme,A; stale cihaz purge; provider retention O | PushClient, user_devices, PushDelivery |
| Parola/hash, Sanctum/reset tokenı, OAuth tokenları | Personal info / User IDs + Other info (ayrı “password” alanı yok) | Evet | Başka kullanıcıya hayır; doğrulama/provider S2 | Temel auth zorunlu; OAuth alternatif | H,G | Parola değiştirme/token iptali/A; Apple revocation kuyruğu | AuthController, personal_access_tokens, social_identities |
| IP adresi/rate-limit anahtarı, web session UA, admin IP audit | Device or other IDs / Other info (kullanıma göre), güvenlik verisi | IP tabanlı cache anahtarı Evet; web/admin session/audit var; mobilde özel erişim-log tablosu yok | Kendi sistem S0/S2; tile karşı tarafına IP S3 | Güvenlik isteğin doğal parçası | G | Rate cache E; admin/log/yedek O | AppServiceProvider RateLimiter, sessions, Audit |
| Arama sorgusu | App activity / In-app search history | API’ye iletilir; özel arama geçmişi DB tablosu yok | S0/S2 | İsteğe bağlı | F | Sadece anlık ise ephemeral; production URL/access log retention doğrulanmalı O | search GET endpoint; erişim log politikası [GERÇEK BİLGİ GEREKLİ] |

Fotoğrafların sunucuda yeniden kodlanan türevlerinden EXIF/GPS temizlenir. Bu işlem orijinal yüklemenin backend'e hiç iletilmediği veya fotoğraf içeriğinin hassas bilgi taşıyamadığı anlamına gelmez; fotoğraf toplama beyanı korunur.

## Hassas konum için kesin karar

Koordinat istemciden sunucuya iletilir; sunucuda aktif konum 0.001°, geçmiş/post noktası 0.005° grid’e alınır. Bu grid’ler mağazanın precise location tanımını otomatik olarak ortadan kaldırmaz. **Precise ve approximate location birlikte değerlendirilir; “yalnız coarse topluyoruz” seçilmez.** Kullanıcıya kesin GPS yayınlamama ile geliştiricinin hassas konum işlemesi farklı beyan konularıdır.

## Form özet cevapları

- Veri toplanıyor: **Evet**.
- Veri paylaşımı: bütünü için “Hayır” seçilmez. Özellikle varsayılan harita sağlayıcısının bağımsız tile/IP aktarımı açıklığa kavuşmadan S3 satırları için **Evet** taslağı korunur; S1/S2 istisnaları gerçek dayanağa göre uygulanır.
- Tüm toplanan veri transit encryption: release kodu HTTPS ister; gerçek yayın ortamı testinden sonra seçilir. Şu an **WAITING**.
- Hesap oluşturma: kullanıcı adı/e-posta + parola; OAuth yalnız gerçek etkin yapılandırmada.
- Hesap/veri silme: uygulama içi parola + SİL; web talep URL’si [GERÇEK BİLGİ GEREKLİ].
- İsteğe bağlı toplama: konum, geçmiş, fotoğraf, gönderi, mesaj, şikâyet ve push. Hesap bilgileri ile onboarding ilgi alanları zorunlu.
- Ephemeral: yalnız anlık API arama işlemi için söz konusu olabilir; tüm saklanan konum/mesaj/veri “ephemeral” işaretlenmez. Erişim logları bilinmeden arama için de kesin işaret konmaz.
- Reklam ID’si, reklam hedefleme, kişisel reklam ve veri broker’ı kodda yok. Analytics/Crashlytics/Sentry SDK’sı veya analytics event akışı yok. Firebase Messaging/Installations teknik SDK verileri SDK_AUDIT.md’de koşullu olarak belirtilir.
- Telefon rehberi okunmaz; Contacts satırı uygulama sosyal grafiği içindir. Kamera videosu, ses, mikrofon, ödeme, sağlık, biyometri ve takvim için ayrı toplama akışı yoktur. Serbest UGC’ye kullanıcıların yazabilecekleri her şeyi yapılandırılmış veri toplama gibi varsayma.

Kaynaklar: [Google form tanımları ve istisnalar](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en), [Firebase Android açıklamaları](https://firebase.google.com/docs/android/play-data-disclosure), [Firebase veri işleyen ilişkisi](https://firebase.google.com/support/privacy). Yerel kanıt: `DATA_EVIDENCE.md`, `SDK_AUDIT.md`, `ACCOUNT_DELETION.md`. Teknik kod kanıtı ile bilinmeyen production işletme politikası ayrı tutulur.
