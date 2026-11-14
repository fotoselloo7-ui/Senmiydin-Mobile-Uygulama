# Apple App Privacy — kod temelli matris

Denetim: 9 Kasım 2026. Bundle ID com.senmiydin.app. “Data Not Collected” seçilemez. Sunucuya kaydedilen hesap, konum ve kullanıcı içeriği vardır. Anonymous post public kimliği gizler; backend user_id bağı devam ettiği için App Privacy’de “not linked” sayılmaz.

Tracking için güncel karar (15 Kasım 2026): **Evet — Google AdMob (Google Mobile Ads SDK) eklendi.** Yetişkin hesaplarda, kullanıcı UMP / ATT izin akışında onay verirse reklam kimliği (IDFA) kişiselleştirilmiş reklam için kullanılır; reddedilirse veya 16–17 yaşındaki hesapta yaş kısıtlı, kişiselleştirilmemiş reklam istenir. SenMiydin? konum verisini, konum geçmişini veya profil verisini AdMob isteğine eklemez. Uygulamanın kendi geçmişinden içerik önermesi reklam tracking’i değildir. Nihai SDK/native privacy report Mac üzerinde doğrulanmalıdır.

Amaçlar: AF=App Functionality (hesap, güvenlik, destek ve mesajlaşma dahil); PP=Product Personalization; **TPA=Third-Party Advertising** (yalnızca Google AdMob). Özel analytics event sistemi yoktur. AdMob satırları (Google’ın yayımlanmış AdMob / Firebase App Store veri toplama rehberine göre; **işletici nihai Privacy Report ve rehberle doğrular**): Identifiers → Device ID (Advertising Identifier) — TPA; Usage Data → Advertising Data / Product Interaction — TPA; Diagnostics — AF; Location → Coarse Location yalnızca IP’den türetilen yaklaşık konum olarak değerlendirilir. **Konum verisi reklam amacıyla toplanmaz veya gönderilmez.**

| Apple veri tipi | Gerçek alanlar | Collected? | Linked to identity? | Tracking? | Purpose / sınır |
|---|---|---|---|---|---|
| Contact Info / Name | Gösterim adı | Evet | Evet | Hayır | AF |
| Contact Info / Email Address | E-posta; OAuth e-posta | Evet | Evet | Hayır | AF; public kullanıcı resource’u email döndürmez |
| Identifiers / User ID | Username, user_id, provider subject, auth oturum ilişkileri | Evet | Evet | Hayır | AF |
| Other Data Types | Doğum tarihi/yaş doğrulaması, kimlik/auth teknik verileri | Evet | Evet | Hayır | AF; DOB ayrı kategori olmadığı için Other Data Types eşlemesi; Sensitive Info diye keyfi sınıflandırılmaz |
| Other User Content / Other Data Types | Bio, meslek/okul, bağlantı ve ilgi tercihleri | Evet | Evet | Hayır | AF, PP; kullanıcı kendi alanlarını girer |
| Location / Coarse Location | Şehir, manuel keşif şehri, yaklaşık OS örneği/harita bölgesi | Evet | Evet (kendi API’sinde) | Hayır | AF, PP; üçüncü taraf tile/IP akışı ayrıca açıklanır |
| Location / Precise Location | İzinli GPS; 0.001/0.005° grid konum/geçmiş/seçili post yeri | Evet, izin/özellik kullanımıyla | Evet | Hayır | AF, PP; 3+ ondalık çözünürlük ve cihazdan hassas iletim nedeniyle precise gizlenmez |
| Photos or Videos | Yalnız fotoğraf: profil, gönderi, hikâye, mesaj | Evet, yüklenirse | Evet | Hayır | AF; video özelliği yok, birleşik Apple kategorisinin adı korunur |
| Other User Content | Post, yorum, karşılaşma ve Yolculuk metni/metadata | Evet | Evet | Hayır | AF, PP; public/private seçimleri değişmez |
| Contacts | Uygulama içi takip/engelleme sosyal grafiği | Evet | Evet | Hayır | AF, PP; telefon rehberi izni veya cihaz rehberi okuma yok |
| Usage Data / Product Interaction | Beğeni, kayıt, takip, onay/red, okundu/istek ve tercih etkileşimleri | Evet | Evet | Hayır | AF, PP; analytics SDK’sı varmış gibi işaretleme yapılmaz |
| Emails or Text Messages | Uygulama içi mesaj gövdesi ve taraflar | Evet | Evet | Hayır | AF; SMS okumak/göndermek anlamına gelmez; E2EE yok |
| Customer Support | Şikâyet/destek talebi, açıklama, reporter/target | Evet, gönderilirse | Evet | Hayır | AF/güvenlik |
| Identifiers / Device ID | App-özel push cihaz UUID, FID/FCM/APNs | **Koşullu**: gerçek Firebase/push etkinse Evet; varsayılan yapılandırmasız sürümde kendi push kaydı yok | Evet (user_devices) | Hayır | AF; Store’daki son build define’larına göre kesinleştir |
| Other Data Types / teknik SDK verisi | Firebase etkinse cihaz modeli/dil/saat dilimi/OS/app sürümü/SDK user-agent | Koşullu SDK davranışı; nihai native paket/konfigürasyonla doğrulanır | SDK user-agent için Firebase’in ilişkisiz beyanı; kendi hesap cihaz kaydı ilişkilidir | Hayır | AF; Diagnostics etiketi yalnız son SDK raporu gerçekten gerektiriyorsa seçilir |
| Other Data Types | IP bazlı güvenlik rate-limit cache; web session/admin audit | Evet güvenlik cache’i; web/admin ayrı kapsam; production access log ayrıntısı [GERÇEK BİLGİ GEREKLİ] | Login kimlik hash’i/IP bağı ilişkilendirilebilir | Hayır | AF/güvenlik; saklama/log politikası tamamlanmalı |
| Search History | API’ye q arama sorgusu | Uygulama DB’sinde saklanmıyor; yalnız anlık işleme Apple “collected” olmayabilir. Access log tam query tutuyorsa Evet | Tutuluyorsa IP/kimlik ilişkisi incelenir | Hayır | AF; production log politikası **MISSING**, “kesin hayır” beyanı henüz verilemez |
| Sensitive Info | Irk/din/siyasi görüş/sağlık/cinsel yönelim/biyometri için özel alan | Özel yapılandırılmış toplama yok | UGC’nin kendisi linked olabilir | Hayır | UGC içeriğini mutlak hassas veri yok iddiasıyla sunma |
| Audio Data (sesli mesaj) | Sesli mesaj | Kullanıcı kaydeder ve gönderirse sunucuya yüklenir; özel depolama | Kullanıcıya bağlı | Hayır | App Functionality. Reklam/analytics yok; `PrivacyInfo.xcprivacy` içinde `AudioData` bildirilmiştir |
| Financial/Purchases/Fitness/Calendar/Browsing History | İlgili özellikler | Kodda ayrı toplama yok | — | Hayır | Ödeme, video, HealthKit, rehber tarama veya uygulama içi serbest web tarayıcı SDK’sı yok |

## Apple beyanı için koşullar

Hesap bilgileri, şehir ve ilgi alanları zorunludur; fotoğraf, gönderi, konum/geçmiş, mesaj ve push kullanıcı tercihine bağlıdır. “İsteğe bağlı özellik” tek başına disclosure’dan muafiyet sağlamaz. Temel mesaj/post/konum verileri tabloda açıklanır.

Geçtiğim Yerler iOS’ta yalnız uygulama açıkken örnek alır. Always/location background mode yoktur. Android’deki location foreground service davranışı App Review’a iOS özelliği olarak yazılmaz.

Hesap silmede temel kişisel içerik temizlenir/anonimleşir; ilişki/denetim/yedek detayları ACCOUNT_DELETION.md kapsamındadır. Gerçek işletmeci, alıcı/aktarım, saklama süreleri, destek ve privacy URL’si [GERÇEK BİLGİ GEREKLİ].

## Privacy manifest ve SDK sonucu

Kaynak plugin manifestlerinin bulunması tüm uygulamanın “no collection” olduğu anlamına gelmez. SDK wrapper manifestleri yalnız kendi kodunu kapsar. Firebase Core/Messaging, GoogleSignIn ve Flutter framework’ünün gerçek native manifest/signature birleşimi için Xcode Privacy Report beklenir. Windows’ta archive yapılmadı. Ayrıntılar SDK_AUDIT.md.

Nihai seçim, yayımlanacak gerçek build’in etkin push/OAuth servisleri ve sunucu log politikasıyla güncellenir; platform formuna koşullu satırlar çözülmeden otomatik cevap gönderilmez.

Kaynaklar: [Apple veri tipleri ve tracking tanımı](https://developer.apple.com/app-store/app-privacy-details/), [Apple SDK gereksinimleri](https://developer.apple.com/support/third-party-SDK-requirements/), [Firebase Apple veri açıklaması](https://firebase.google.com/docs/ios/app-store-data-collection). Kod referansları DATA_EVIDENCE.md içindedir.
