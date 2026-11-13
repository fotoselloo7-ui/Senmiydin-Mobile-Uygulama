# Mobil arayüz denetimi — 9 Kasım 2026

> **Tarihsel rapor — güncel kaynak değildir.** Bu belge 9–10 Kasım 2026 tarihli UI envanterini olduğu gibi korur. Sonraki kullanıcı kararları bu metinden üstündür: mavi yalnız işlevsel renktir, mor / lila SenMiydin markasıdır; herkese açık profilde şehir, mesafe ve hobi çipi gösterilmez ("diğer profil" kanıtındaki statik ilgi etiketleri artık geçersizdir); Home, Profil, Medya Görüntüleyici, drawer, alt navigasyon ve ikon sistemi kilitlidir. Güncel kurallar için [UI_DESIGN_SYSTEM.md](UI_DESIGN_SYSTEM.md) ve [VALIDATION.md](VALIDATION.md) okunur.

Kaynaklar: SENMIYDIN_URUN_TANIMI.md, VALIDATION.md, LOCATION_TIME_TRAVEL.md, STORE_READINESS.md ve Ekran Görüntüleri klasöründeki iki panonun tamamı tek tek incelendi. Birinci pano: Ana Sayfa, composer, kişi etiketleme, karşılaşma onayı. İkinci pano: kayıt, profil tamamlama, ilgi alanları, filtreler ve profil. Diğer ekranlar aynı beyaz/mavi/lacivert dilin ortak bileşenlerini kullanır; yeni görsel kimlik veya final logo üretilmez.

## Envanter

29 temel ekranın tamamının gerçek karşılığı vardır; ayrı route yerine tab veya sheet olanlar açıkça belirtilir. Ek 12 yüzeyle toplam **41 mobil ekran/akış yüzeyi** değerlendirilir. Tab/sheet ayrımı bu sayıyı yeni bağımsız route sayısı yapmaz. İlk durumlar aşağıdadır. Sonuçlar ve tek tek incelenen ekran kanıtları UI_AUDIT_VALIDATION.md içinde kayıtlıdır.

| # | Ürün ekranı | Gerçek karşılık | İlk durum / bulgu |
|---|---|---|---|
| 1 | Splash | auth.dart SplashPage / | IMPLEMENTED |
| 2 | Karşılama | WelcomePage /welcome, 3 slide | NEEDS UI POLISH |
| 3 | Giriş | AuthPage /login | NEEDS UI POLISH |
| 4 | Kayıt | AuthPage /register | NEEDS UI POLISH |
| 5 | Profil tamamlama | CompleteProfilePage /complete | PARTIAL: düzenlemede kaydedilmemiş değişiklik koruması eksik |
| 6 | İlgi alanları | InterestsPage /interests | IMPLEMENTED: arama, minimum 5, aktif katalog |
| 7 | İzin açıklaması | PermissionsPage /permissions | IMPLEMENTED: kullanıcı eylemi, platform farkı |
| 8 | Ana Sayfa | HomeShell/HomeContent | NEEDS UI POLISH: sahte online işareti, metadata/touch hedefleri |
| 9 | Harita | MapContent → LiveMapContent | NEEDS UI POLISH: loading/kontrol dili |
| 10 | Filtreler | FilterPage /filters | PARTIAL: API'nin desteklediği tüm post türleri UI'da yok |
| 11 | Arama | SearchPage /search | NEEDS UI POLISH: API people/posts, katalog şehirleri mevcut |
| 12 | Paylaşım oluştur | ComposePage /compose | IMPLEMENTED: koşullu alanlar, preview, discard |
| 13 | Kişi etiketleme | SearchPage(tag:true) /tag | IMPLEMENTED; uydurma recent search yok |
| 14 | Karşılaşma onay/red | EncounterPage /encounter | IMPLEMENTED |
| 15 | Paylaşım detayı | PostDetailPage /post | NEEDS UI POLISH: ortak kart okunabilirliği |
| 16 | Yorumlar | CommentsPage /comments | IMPLEMENTED; keyboard/safe-area kontrolü gerekli |
| 17 | Diğer profil | ProfilePage /profile id | NEEDS UI POLISH |
| 18 | Kendi profilim | HomeShell tab 4 /profile | NEEDS UI POLISH: istatistiklerin küçük yazı/taşma riski |
| 19 | Profil düzenle | CompleteProfilePage(edit:true) | PARTIAL: unsaved guard eksik |
| 20 | Karşılaşmalarım | EncountersPage /encounters | IMPLEMENTED: gerçek backend durumları |
| 21 | Kaydedilenler | SavedPage /saved | IMPLEMENTED: ortak kart, private liste |
| 22 | Bildirimler | LiveNotificationsPage | NEEDS UI POLISH: yoğun kartlar, metin ağırlığı |
| 23 | Mesajlar | MessagesContent/DirectConversationList | NEEDS UI POLISH: zaman/badge hiyerarşisi |
| 24 | Sohbet | DirectChatPage /conversation, /chat | IMPLEMENTED: 4 saniye polling korunur; typography polish |
| 25 | Ayarlar | SettingsPage /settings | NEEDS UI POLISH: grup sınırları |
| 26 | Gizlilik/konum/bildirim | PreferencesPage, 3 tab | PARTIAL: history anahtarının adı bildirimle karışıyor |
| 27 | Engellenenler | BlockedPage /blocked | IMPLEMENTED: liste, engel kaldırma, empty |
| 28 | Şikâyet | ReportPage /report | IMPLEMENTED: gerçek reason, other açıklama zorunlu |
| 29 | Hesap silme | DeleteAccountPage /delete-account | IMPLEMENTED: parola ve SİL, geri alınamaz |

| # | Ek mevcut yüzey | Gerçek karşılık | İlk durum |
|---|---|---|---|
| 30 | Aktif şehir seçimi | chooseCity bottom sheet | IMPLEMENTED; aranabilir katalog |
| 31 | Geçmiş yer seçimi | PostPlaceField/history sheet | IMPLEMENTED; yalnız kendi izinli geçmişi |
| 32 | Yaklaşık harita yeri seçimi | map place picker | IMPLEMENTED |
| 33 | Olay zamanı seçimi | OccurredAtField/date-time picker | IMPLEMENTED |
| 34 | Yolculuk alanları | TravelFields composer içinde | NEEDS UI POLISH: metadata hiyerarşisi |
| 35 | Ortak hikâye/yayın/revizyon | /encounter-story, /encounter-story-edit | IMPLEMENTED |
| 36 | Yeni mesaj alıcısı / paylaşım alıcısı | SearchPage picker, /message-recipient /share | IMPLEMENTED |
| 37 | Takipçi/takip edilen | PeoplePage /people | IMPLEMENTED |
| 38 | Parola yardım/değiştirme | ForgotPage, PasswordPage | NEEDS UI POLISH: ortak field davranışı |
| 39 | Hukuk/lisans | LegalPage, showLicensePage | IMPLEMENTED; gerçek legal içerik eksikleri store paketinde |
| 40 | Bakım/minimum sürüm | AppAvailability, maintenance notice | IMPLEMENTED; mevcut servis politikası |
| 41 | Medya galerisi/önizleme | ImageCarousel dialog, composer preview | IMPLEMENTED; media/no-media ayrımı korunur |

## Tasarım ve aksiyon bulguları

Ürün motorlarına yeni backend eklenmedi. Yakın listede sahte çevrimiçi nokta, mock dalındaki sabit 27 sayısı ve authenticated drawer içindeki geliştirici inceleme girişi kaldırıldı. Gerçek chat recently_active alanının davranışı korundu.

Formlar, empty/loading/error, kart tipografisi, dokunma hedefleri ve seçili chip durumları ortak token/bileşenlerle düzenlendi. Home modül sırası korundu. Filtreler mevcut API content değerlerine bağlandı; desteklenmeyen bağımsız photo+type birleşimi gösterilmiyor.

## Doğrulama kaydı

Kaynak başlangıcı .local/ui-source-before.zip içinde korunur. Başlangıç tabanı 60 Flutter ve temiz analyze; backend 104/1271 önceki geçerli sonuçtur. Son otomatik sonuç: 82 Flutter testi geçti; flutter analyze No issues found. API sözleşmesi/backend değişmediği için Laravel bu tur yeniden çalıştırılmadı. Pixel normal kullanıcı turu ve screenshot kontrol matrisi UI_AUDIT_VALIDATION.md içindedir. Gerçek screenshot dosyaları docs/screenshots/ui-audit/ altında tutulur; final normal Demo Home kanıtı docs/screenshots/pixel6a-current.png olur.


## Tamamlanan kaynak düzeltmeleri

- Ortak renk/kontrast, spacing/radius/ölçü ve typography rolleri UI_DESIGN_SYSTEM.md'de belgelenir. Default kart gölgeleri sadeleştirildi; güçlü başlık ile uzun gövde ayrıldı.
- Home sırası korundu. Banner'daki sabit sayı, yakındaki kişilerin sahte online noktası ve drawer'daki kullanıcıya dönük olmayan inceleme girişi kaldırıldı. Şehir alanı uzun ad/büyük yazıda ayrı satıra geçer ve tam adı sarar; tablar gerektiğinde yatay kayar. Composer fotoğraf/kamera/yer kısayolları gerçek ekranı açar; yer kısayolu galeri açmaz.
- Filtreler API'nin mevcut moment/confession/thought/travel değerlerine bağlandı. API bir content değeri desteklediği için photo ve post türü aynı anda uygulanıyormuş gibi iki ayrı seçim yapılmadı.
- Harita mevcut distance chip'lerini kullanır. Tüm feed filtrelerini haritaya uyguluyormuş gibi açan eski üst aksiyon, gerçek yenileme aksiyonuna dönüştürüldü. Yaklaşık bölgeye dön, tile hata/tekrar yükle ve yalnız gerekli OSM atfı gösterilir.
- Kendi profilinde pull-to-refresh, büyük yazıda 2×2 istatistikler ve private saved ayrımı korundu. Edit formu geri çıkışta değişiklikleri korur; mevcut avatar upload anlık kayıt davranışı değiştirilmedi.
- History anahtarı görünür metinde Geçtiğim Yerler olarak açıklandı; kendi kayıt tercihi ile haber verme kategorisine ayrı erişim var. İç preference anahtarı/API davranışı değiştirilmedi.
- Bildirimlerde read/unread hem semantics hem hafif yüzey/işaretle ayrılır. Metin ağırlıkları sadeleşti. Mesaj/chat polling ve destination route'ları korundu; chat bubble okunabilirliği iyileşti.
- Paged listeler ortak statik loading placeholder ve gerçek hatada retry kullanır. Empty listelerde Türkçe açıklamalar korunur; kısa listelerde refresh için scroll physics sağlanır.
- Anonim kartta avatar/isim/profile route açılmaz. Fotoğrafsız kartta medya alanı oluşmaz; gerçek medya contain/zoom ile kırpılmadan incelenebilir. Geçici markanın şekli ve final olmayan statüsü korunur.

## İlk partial bulgularının sonucu

Ürün tanımındaki 29 ekranın hiçbiri MISSING değildi. Profil tamamlama/düzenlemenin kaydedilmemiş taslak koruması, filtrelerin eksik tür seçenekleri ve history kaydı/bildirim metni ayrımı tamamlandı. Bu, ürün motorlarının tüm dış servislerle üretim doğrulamasının tamamlandığı anlamına gelmez. Güncel gerçek sınırlar UI_AUDIT_VALIDATION.md ve STORE_READINESS.md içinde açık tutulur.

İlgi seçimi kartları yüksek kontrastlı action mavisini ve selected semantics durumunu kullanır; yüksekliği yazı ölçeğine uyarlanır. Featured carousel lacivert çubuk, medya carousel mavi yuvarlak gösterge kullanır; her ikisi tek öğede gizlenir. Fotoğrafsız profil kapağı kısaltıldı; salt okunur ilgi etiketleri devre dışı buton gibi soluk görünmez.
