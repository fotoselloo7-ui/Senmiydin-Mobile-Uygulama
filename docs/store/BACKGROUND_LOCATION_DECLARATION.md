# Google Play background location / location FGS beyanı

Denetim: 9 Kasım 2026. Bu metin Android gerçek koduyla uyumlu bir Console taslağıdır; onay alındığı anlamına gelmez.

## Teknik kapsam

Android manifestte ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, FOREGROUND_SERVICE ve FOREGROUND_SERVICE_LOCATION vardır. **ACCESS_BACKGROUND_LOCATION yoktur.** Uygulamada kullanıcı tarafından açılmış Geçtiğim Yerler, visible location foreground service ile uygulama küçültülünce devam edebilir. Force-stop/detached sonrası kesintisiz veya “always” kayıt garantisi verilmez. İzin reddedilince manuel şehirle temel kullanım sürer. Kullanıcı tarihçeyi kapattığında stream normal konum kullanımına döner; geçmiş/eşleşme kayıtları temizlenir.

FGS, background-location politikasından otomatik muafiyet değildir. Console ilgili background-location veya FGS formunu açarsa gerçek location FGS kullanımı belirtilir. APK’da bulunmayan background izni varmış gibi seçilmez; sırf form doldurmak için yeni izin eklenmez. iOS bu belgenin kapsamında değildir; yalnız foreground konum kullanır.

## Console için tek özellik açıklaması

**Uygulamanın amacı:** SenMiydin?, gerçek hayattaki karşılaşmalar ve şehir hikâyeleri etrafında sosyal keşif sunar.

**Arka planda devam edebilen tek özellik:** Geçtiğim Yerler.

**Gerekçe / kullanıcı faydası:** Kullanıcı açıkça etkinleştirdiğinde ziyaret ettiği yaklaşık bölgelerin geçmişi, daha sonra bu bölgelerde oluşan ilgili paylaşımları keşfetmesine yardımcı olur. Örneğin öğleden sonra bir parktan geçen kullanıcı, akşam o bölge ve zamanla ilişkili bir karşılaşma paylaşımı yayımlandığında bunu öneri olarak görebilir. Ayrı bildirim tercihi açıksa in-app bildirim üretilebilir; gerçek push ayrıca FCM yapılandırmasına bağlıdır. Geçmiş olmadan daha sonra yayımlanan gönderiyi önceki ziyarete bağlamak mümkün değildir. Temel şehir akışı ise bu özellik olmadan kullanılabilir.

**Veri / kapsam:** Konum cihazdan API’ye iletilir, sunucuda grid’e alınır; geçmiş varsayılan 0.005° grid ve mevcut varsayılan 7 günlük saklama kullanır. Aktif konum 0.001° grid’dir. Mağaza sınıflamasında hassas konum da bildirilir. Geçmiş ham listesi diğer kullanıcılara yayımlanmaz; kesin kullanıcı GPS’i public API’ye konmaz. Arka plan örnekleri “canlı yakında” görünürlüğünü güncellemez. Eşleşme kesin karşılaşma iddiası değildir.

**Başlatma / durdurma:** Profil → Ayarlar → Gizlilik ve Konum → Konum → “Geçtiğim Yerler” anahtarı; “Geçtiğim Yerler açılsın mı?” onayı, gerekirse Android’in kullanım sırasında konum izni ve görünür devam eden servis. Anahtar kapatılarak kayıt durdurulur ve geçmiş/eşleşmeler temizlenir. Bu anahtar history kaydını yönetir; “Geçtiğim Yerlerden Haber Ver” bildirim kategorisi ayrı tercihtir.

## Uygulamadaki mevcut açıklama

Mevcut settings onayında konumun sunucuya iletildiği, Android arka plan kaydı, öneri/bildirim amacı, diğer kullanıcılara kesin konum verilmediği ve kapatınca temizleme açıklandı. iOS metni yalnız uygulama açıkken kaydı belirtir. Normal kayıt/onboarding akışında cihaz konumu satırının önüne mevcut InfoNote stiliyle platforma uygun açıklama alındı; kullanıcı ayarlara girmeden sunucuya iletim, history varsayılan kapalı ve Android arka plan/iOS foreground farkını görebilir. Yeni ekran veya yeni kayıt davranışı eklenmedi. Uzun settings onayı küçük ekranda kaydırılabilir.

## Gönderimden önce açık noktalar

- Açıklama hem normal onboarding’de izin satırından önce hem history etkinleştirme onayında gösterilir. Son yayımlanacak build’de bu bağlamın Google’ın belirgin açıklama ve video incelemesiyle karşılaştırılması **WAITING**; mağaza onayı alınmış gibi işaretlenmez. Bu tur Home/yeni ekran eklenmedi.
- Privacy CMS ve web açıklaması gerçek veri sorumlusu, amaç, alıcılar ve retention ile tamamlanmalı; varsayılan metinler MISSING.
- Gerçek Android cihazda arka plan/FGS durdurma/OS kısıtları ve gerekli Console video kanıtı hazırlanmalı. Önceki Pixel testi GPS/izin ve geçmiş eşleşmesini kapsar; gerçek sürekli background video kanıtı değildir.
- Kamuya açık, erişilebilir video bağlantısı: [GERÇEK BİLGİ GEREKLİ].
- İzin açıklaması ve metadata’nın nihai yayın build’iyle eşleşmesi kontrol edilmeli.

Kaynaklar: [Google background location ve FGS değerlendirmesi](https://support.google.com/googleplay/android-developer/answer/9799150?hl=en), [FGS gereksinimleri](https://support.google.com/googleplay/android-developer/answer/13392821?hl=en). Kod: lib/data/location_service.dart, lib/screens/settings.dart, backend/app/Location/LocationData.php, backend/config/location.php.
