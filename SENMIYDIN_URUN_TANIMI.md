# SenMiydin? — Ürün Tanımı ve Uygulama Kuralları

## 1. Ürün Özeti

**SenMiydin?**, gerçek hayatta aynı şehirde, aynı bölgede, bir yolculukta, kafede, sahilde, parkta veya başka bir yerde yolları kesişen insanların yarım kalan karşılaşmalarını yeniden buluşturmayı hedefleyen; aynı zamanda düşünce, itiraf, anı ve sosyal paylaşımları konumla ilişkilendiren bir sosyal medya uygulamasıdır.

Ürün klasik bir flört uygulaması olarak konumlandırılmamalıdır. Ana deneyim, gerçek hayattaki karşılaşmaların, konum temelli sosyal keşfin ve şehir içi sosyal paylaşımların birleşimidir.

Temel örnekler:

- “Bugün sahilde yürürken yanımdan geçen o kişi… Sen miydin?”
- “Otobüste göz göze geldiğimiz o an hâlâ aklımda.”
- “Kafede aynı şarkıda birbirimize baktık.”
- “Ankara–Erzincan yolculuğundayım, aynı otobüsteysen molada kahve içelim mi?”
- “Bugün burada şunu düşündüm…”
- “Bu şehirde bunu söylemek istedim…”

---

## 2. Temel Ürün Kuralları

### 2.1 Şehir bazlı görünürlük

Profildeki yaşanılan şehir ile aktif keşif şehri ayrıdır. Cihazın güncel koordinatı güvenilir sınır verisinde çözüldüğünde aktif şehir değişir; profil şehri değişmez. Konum izni yoksa veya şehir çözülemiyorsa kullanıcı manuel şehir seçebilir, akışı kullanabilir ve gönderi oluşturabilir. Bilinmeyen koordinata profil şehri atanarak cihaz şehriymiş gibi sunulmaz.

Bir paylaşım yalnızca çok küçük bir kilometre çemberine hapsedilmez.

Varsayılan davranış:

- Paylaşım, kullanıcının bulunduğu şehirdeki uygun kullanıcılara gösterilebilir.
- Yakınlık, görünürlüğü tamamen engelleyen bir bariyer değil; sıralama ve keşif sinyalidir.
- 350 metre uzaktaki bir paylaşım “Yakın” akışında 8 km uzaktaki bir paylaşımdan daha üstte gösterilebilir.
- Kullanıcı isterse filtrelerle tüm şehir, 5 km, 10 km, 25 km gibi kapsamlar seçebilir.

Kesin GPS koordinatları diğer kullanıcılara açık biçimde gösterilmez.

### 2.2 Sosyal medya hissi

Ana akış klasik sosyal medya rahatlığında olmalıdır.

- Metin paylaşımı yapılabilir.
- Fotoğraf zorunlu değildir.
- Fotoğraf varsa metnin altında tam genişlikte gösterilir.
- Bir gönderide en fazla 10 fotoğraf kullanılabilir; çoklu fotoğraf yatay kaydırılabilir.
- Görsel sayacı `1/4` gibi gösterilebilir.
- Beğeni, yorum, paylaş ve kaydet aksiyonları bulunur.
- İçerik kartları çok ağır veya birbirinden kopuk görünmemelidir.
- Akış rahat, sade ve hızlı okunabilir olmalıdır.

### 2.3 Kategoriler arka planda kalmalı

İçerik türleri vardır ancak ana sayfada büyük kategori blokları olarak kullanıcıya dayatılmaz.

İçerik türleri:

- Anı
- Karşılaşma
- İtiraf
- Düşünce
- Yolculuk

Bu türler:

- Paylaşım oluştururken seçilebilir.
- Filtrelerde kullanılabilir.
- Gönderide küçük bir etiket olarak gösterilebilir.
- Ana sosyal akışın önüne geçmez.

---

## 3. Ana Sayfa

Onaylı ana sayfa referans görseli uygulamanın görsel ve yapısal ana referansıdır.

Ana sayfada:

- Üst bar
- SenMiydin? marka kullanımı
- Akış
- Yakın
- Popüler
- Şehir seçimi
- Yakın çevredeki yeni paylaşımlar bilgisi
- Haritada Gör
- Yakınındaki İnsanlar
- Öne Çıkan Karşılaşmalar
- Hızlı paylaşım alanı
- Normal sosyal akış
- Metin gönderileri
- Fotoğraflı gönderiler
- Çoklu fotoğraf slider
- Beğeni
- Yorum
- Paylaş
- Kaydet
- Alt navigasyon

bulunur.

Alt navigasyon:

- Ana Sayfa
- Harita
- Ortada büyük `+`
- Mesajlar
- Profil

---

## 4. Yakınındaki İnsanlar

Ana sayfada yatay kaydırılabilir bir modüldür.

Sadece bu özelliğin görünürlüğüne izin veren kullanıcılar burada yer alabilir.

Gösterilebilecek bilgiler:

- Profil fotoğrafı
- Ad
- Kullanıcı adı gerektiğinde
- Yaklaşık mesafe

Gösterilmeyecek bilgi:

- Kesin koordinat
- Açık adres
- Kullanıcının gerçek zamanlı kesin rotası

Kullanıcı ayarlardan bu görünürlüğü kapatabilmelidir.

Bu modül “yakındaki herkes” anlamına gelmez. Uygun ve görünür profillerden seçki sunar.

---

## 5. Karşılaşma Sistemi

### 5.1 Karşılaşılan kişiyi etiketleme

Paylaşım oluştururken kullanıcı “Karşılaştığım kişiyi etiketle” seçeneğini kullanabilir.

Bu özellik büyük bir kullanıcı listesi göstermemelidir.

Arama yöntemi:

`@kullanıcıadı ara`

Arama sonucu:

- Profil fotoğrafı
- Ad
- @kullanıcıadı
- Şehir

İsim ile yardımcı arama yapılabilir.

Sistem çok büyük kullanıcı sayılarında da arama/API tabanlı çalışacak şekilde tasarlanmalıdır.

### 5.2 Karşılaşma isteği

Bir kullanıcı başka bir kullanıcıyı karşılaşmada etiketlediğinde karşı tarafa bildirim gider.

Örnek:

“Ahmet D. seni bir karşılaşmada etiketledi.”

Karşı taraf:

- Karşılaşmayı Onayla
- Reddet

seçeneklerini görür.

Karşı taraf onaylamadan bu olay doğrulanmış karşılaşma sayılmaz.

### 5.3 Doğrulanmış karşılaşma

Karşı taraf onaylarsa iki kullanıcı aynı karşılaşma kaydına bağlanır.

Ardından isterlerse ortak bir karşılaşma paylaşımı oluşturabilirler.

Bu paylaşımda:

- İki profil fotoğrafı
- `Karşılaşıldı ✓`
- Başlık
- Kısa açıklama
- İsteğe bağlı fotoğraf
- İsteğe bağlı çoklu fotoğraf

bulunabilir.

Örnek:

Başlık:
`Birbirimizi bulduk`

Açıklama:
`Kahveler içildi. ☕✨`

### 5.4 Öne Çıkan Karşılaşmalar

Ana sayfada yatay kaydırılabilir bir modül olarak gösterilir.

Kartta:

- İki profil fotoğrafı
- Karşılaşıldı durumu
- Ortak başlık
- Ortak açıklama
- Varsa görsel

bulunur.

Doğrulanmış karşılaşmalar normal akışta da paylaşılabilir.

İki küçük profil avatarı kimlik alanıdır; hikâye medyası yerine kullanılamaz. Ortak hikâyeye fotoğraf eklenmemişse hem öne çıkan hem normal akış kartında büyük görsel, boş medya alanı, fotoğraf sayacı veya fotoğraf oku bulunmaz; kart içeriğin doğal yüksekliğinde kalır. Fotoğraf eklenmişse carousel yalnız gerçek post/story medyasını sayar. Demo ve cihaz testlerinde görünen metinlere timestamp, UUID veya debug son eki eklenmez.

---

## 6. Paylaşım Oluşturma

Paylaşım oluşturma ekranında:

- Metin alanı
- Fotoğraf ekleme
- Kamera
- Çoklu fotoğraf
- Fotoğraf sıralama
- Fotoğraf silme
- Konum
- Paylaşım türü
- Karşılaştığım kişiyi etiketle
- Şehir görünürlüğü
- İsteğe bağlı anonim paylaşım
- Karakter sınırı
- Paylaşım önizlemesi

bulunabilir.

Fotoğraf zorunlu değildir.

Paylaşım türleri:

- Anı
- Karşılaşma
- İtiraf
- Düşünce
- Yolculuk

---

## 7. Anonim Paylaşım

Kullanıcı isterse paylaşımını anonim olarak yayınlayabilir.

Diğer kullanıcılara:

- Ad
- Kullanıcı adı
- Profil fotoğrafı

gösterilmez.

Ancak sistem ve yetkili admin hesabın gerçek sahibini bilir.

Anonimlik taciz, spam veya ihlal için denetimsiz bir alan değildir.

---

## 8. Yolculuk Kullanımı

Yolculuk türünün isteğe bağlı ayrı detayları vardır: ulaşım türü (Otobüs, Tren, Uçak, Feribot, Diğer), kalkış ve varış şehri, yaklaşık kalkış saati, firma, sefer kodu ve isteğe bağlı plaka/araç tanımlayıcısı. Detayların gönderiyi görenlere açık olması ayrıca seçilir; varsayılan kapalıdır. Kullanıcının açıkça paylaştığı araç bilgisi admin moderasyonuna tabidir. Canlı araç takibi veya araç/plaka arama indeksi yoktur.

Yolculuk için ek katılım, seyahat odası, otobüs grubu veya eşleşme havuzu bulunmaz. İzinli geçmişte kalkış/varış şehri ve yaklaşık saat örtüşmesi öneriyi güçlendirebilir; sistem aynı araçta bulunulduğunu iddia etmez.

Uygulama şehir içi karşılaşmaların yanında yolculuk senaryolarını da destekler.

Örnek:

“Ankara–Erzincan otobüsündeyim. Aynı yolculuktaysan molada kahve içelim mi?”

Desteklenen bağlamlar:

- Otobüs
- Tren
- Uçak
- Feribot
- Diğer yolculuklar

Kullanıcının canlı rotası veya açık konumu herkese açık şekilde yayınlanmaz.

---

## 9. Konum ve Harita

Harita ayrı ana ekrandır.

Desteklenecek filtreler:

- Tüm şehir
- 5 km
- 10 km
- 25 km
- En yakın
- Yeni
- Popüler

Harita noktaları gerektiğinde yaklaşıklaştırılır.

Kesin konum başka kullanıcılara gösterilmez.

Açık ve mümkün olduğunca maliyetsiz harita altyapısı tercih edilmelidir.

---

## 10. Geçilen Yerler ve Konum Bildirimleri

Geçtiğim Yerler varsayılan kapalıdır. Kullanıcı açınca yaklaşık bölgeler en fazla mevcut 7 günlük varsayılan saklama süresi boyunca tutulur; kapatınca örnek toplama durur ve kendi geçmiş/eşleşme kayıtları temizlenir. Geçmiş kaydetmek ve “Geçtiğim Yerlerden Haber Ver” bildirim tercihi ayrı ayarlardır. Yakın bölge aktiviteleri de ayrı bildirim kategorisidir.

Paylaşım oluştururken “Şu an bulunduğum yer”, “Geçtiğim yerlerden seç” ve “Haritadan yaklaşık yer seç” seçenekleri bulunur. Geçmiş yer seçimi yalnızca kullanıcının kendi izinli ve süresi dolmamış kayıtlarından yapılır. Liste yaklaşık bölge ve yuvarlanmış saat gösterir. Harita noktası sunucuda yaklaşıklaştırılır.

Olayın gerçekleştiği occurred_at, gönderinin created_at yayın saatinden ayrıdır. Karşılaşma ve Yolculukta “Ne zaman oldu?” alanı Şimdi, Az önce, Bugün veya tarih/saat seçimini sunar. Geçmiş bölge seçildiğinde yaklaşık geçmiş saat başlangıç değeri olur ve değiştirilebilir.

Konum-zaman motoru önce SQL düzeyinde şehir/bölge/zaman filtresi uygular, sonra aynı kullanıcı/gönderi için tek eşleşme saklar. Güçlü eşleşme yaklaşık 500 m ve ±60 dakika; orta eşleşme 2 km ve ±4 saat; zayıf eşleşme aynı yerel gün ve 5 km sınırındadır. Kurallar merkezi yapılandırmadadır. Geçmişi kapalı kullanıcı eşleştirilmez. Eşleşme şehir görünürlüğünü kısıtlamaz; sıralamaya sınırlı destek sağlar. İzinli güçlü eşleşmede tek in-app bildirim oluşturulur; push credential olmasa da bildirim merkezi çalışır.

Location match bir olasılıktır; “Geçtiğin bir bölgeden” ifadesi kullanılır. Kullanıcı adıyla gönderilen ve diğer kişi tarafından kabul edilen doğrulanmış karşılaşmadan ayrıdır; otomatik “Karşılaşıldı ✓” üretmez. Başka bir kullanıcının geçmişi, kesin koordinatı veya eşleşen geçmiş saati response'a konmaz.

Kullanıcı ilgili izni ve ayarı açarsa konum temelli bildirimler alabilir.

Örnek bildirimler:

- “Bulunduğun bölgede yeni bir paylaşım var.”
- “Geçtiğin bir yerde yeni bir iz bırakıldı.”
- “Birine denk gelmiş olabilirsin.”

Bildirim özellikleri kullanıcı tarafından ayrı ayrı kapatılabilmelidir.

Arka plan konumu yalnızca gerçekten gerekli özellikler için kullanılmalıdır.

---

## 11. Filtreler

Filtre ekranı:

### Konum
- Tüm şehir
- 5 km
- 10 km
- 25 km

### Sıralama
- En yakın
- Yeni
- Popüler

### İçerik
- Tüm paylaşımlar
- Fotoğraflı
- Yazılı
- Karşılaşmalar
- Etiketli içerikler

### İlgi alanları
Kullanıcının seçtiği hobiler ve genel ilgi alanları.

Ek seçenekler:

- Sadece yakınımdakileri göster
- Fotoğraflı paylaşımları önceliklendir
- Karşılaşma hikâyelerini öne çıkar
- Filtreleri temizle
- Uygula

---

## 12. Kayıt ve Giriş

Kayıt ekranı:

- Ad Soyad
- Kullanıcı Adı
- E-posta
- Şifre
- Doğum Tarihi
- Şehir

Alternatif giriş:

- Google
- Apple

Ayrıca:

- Giriş Yap
- Şifremi Unuttum
- Kullanım Koşulları
- Gizlilik Politikası
- Yaş kontrolü

bulunmalıdır.

---

## 13. Profil Oluşturma

Kullanıcı profilini tamamlayabilir.

Alanlar:

- Profil fotoğrafı
- Kısa biyografi
- Meslek / okul
- Yaşadığı şehir
- İlgi alanları
- Kullanıcı adı
- Aradığı bağlantı türleri

Bağlantı tercihleri örneği:

- Arkadaşlık
- Karşılaşmalar
- Sohbet
- Yeni insanlarla tanışma

Ayarlar:

- Konumumu şehir içinde göster
- Yakınımdaki karşılaşmaları öner

---

## 14. Hobiler ve İlgi Alanları

Hobiler aranabilir ve çoklu seçilebilir.

Başlangıç örnekleri:

- Kahve
- Müzik
- Kitap
- Seyahat
- Sahil yürüyüşü
- Sinema
- Fotoğraf
- Fitness
- Kamp
- Yemek
- Bisiklet
- Kediler
- Köpekler
- Oyun
- Girişimcilik
- Teknoloji
- Sanat
- Doğa
- Spor
- Etkinlik
- Gece yürüyüşü

Admin panelinden:

- Yeni hobi eklenebilir
- Hobi pasifleştirilebilir
- Hobi sırası değiştirilebilir

---

## 15. Profil

**FINAL KARAR (güncel kaynak):** Herkese açık profilde şehir satırı, konum, mesafe ve hobi / ilgi alanı çipi **yoktur**. Şehir, ilgi alanı ve meslek / okul bilgisi backend'de yalnızca onboarding, filtre ve eşleştirme için saklanır; başka bir kullanıcıya dönen hiçbir API yanıtında (`PublicUserResource`) bulunmaz. Kendi profil düzenleme ekranında bu alanlar düzenlenebilir.

Final profil yapısı:

- Kapak görseli (kullanıcı kendi kapağını Profil Düzenle ekranından ekleyip değiştirebilir veya kaldırabilir)
- Profil fotoğrafı
- Ad
- @kullanıcıadı
- Kısa biyografi
- İstatistik satırı: Paylaşım, Karşılaşma, Takipçi, Takip (sayaçlar gerçek listeye gider)
- Başkasının profilinde: Takip Et / Mesaj. Kendi profilinde: Profil Düzenle / Ayarlar
- Sekmeler: Paylaşımlar, Karşılaşmalar, Medya (yalnızca kendi profilinde özel Kaydedilenler)

> Not: Bu bölümün önceki sürümü herkese açık profilde şehir ve ilgi alanlarını listeliyordu; bu karar geçersizdir.

---

## 16. Takip Sistemi

Kullanıcılar birbirlerini takip edebilir.

- Takip Et
- Takibi Bırak
- Takipçi
- Takip Edilen

Takip sistemi ürünün ana karşılaşma deneyimini gölgelememelidir.

---

## 17. Mesajlaşma

İlk sürüm için:

- Mesaj listesi
- Özel sohbet
- Mesaj isteği
- Karşılaşma sonrası sohbet başlatma
- Okundu bilgisi
- Engelle
- Şikâyet
- Push bildirimi

bulunur.

İlk sürümde sesli veya görüntülü arama gerekli değildir.

---

## 18. Bildirim Merkezi

Bildirim türleri:

- Beğeni
- Yorum
- Takip
- Mesaj
- Etiket
- Karşılaşma isteği
- Karşılaşma onayı
- Yakın bölge aktivitesi
- Sistem duyurusu

Kullanıcı bildirim türlerini ayarlardan yönetebilir.

---

## 19. Arama

Arama şunları destekleyebilir:

- Kullanıcı adı
- Ad
- İnsanlar
- Paylaşımlar
- Şehir

Karşılaşma etiketleme ekranındaki arama, kullanıcı aramasının özel bir kullanım şeklidir.

---

## 20. Güvenlik ve Moderasyon

Uygulamada:

- Şikâyet
- Engelle
- İçerik kaldırma
- Kullanıcı askıya alma
- Kullanıcı yasaklama
- Spam kontrolü
- Uygunsuz kelime/URL kontrolü
- Tekrarlayan paylaşım kontrolü
- İçerik moderasyonu
- Kesin konum gizliliği

bulunmalıdır.

Başka bir kişinin açık adresi veya kesin konumu paylaşılmamalıdır.

---

## 21. Web Sitesi

Ana alan adı:

`senmiydin.com`

Public web sitesi:

- Ürün tanıtımı
- Nasıl çalışır?
- Özellikler
- App Store bağlantısı
- Google Play bağlantısı
- Gizlilik Politikası
- KVKK
- Kullanım Koşulları
- Topluluk Kuralları
- İletişim
- Hesap Silme Talebi

içermelidir.

İlk sürümde mobil uygulamanın tüm sosyal işlevlerini web'e taşımak zorunlu değildir.

**Güncel durum (14 Kasım 2026 — public web final adayı):** Mobil tasarım FINAL ve kilitlidir; public web tasarımı (blade: `website/home.blade.php`, stil: `public/web/home.css`) final adaydır ve kullanıcının son görsel onayını bekler. Ana sayfa bir özellik kataloğu değil, bir hikâye anlatır: Header → iki kolonlu Hero ("Belki de aradığın kişi buradadır.", 5 hikâyeli slider; 4. hikâye gerçek Harita Notu ekranları) → SenMiydin Nedir? → Nasıl Çalışır? → Şehir Bazlı Sosyal Keşif → Karşılaşmalar → Harita → **Harita Notları / Dijital Mektuplar (ayrı büyük bölüm, `#harita-notlari`)** → Geçtiğim Yerler → Yolculuk → Mesajlaşma → Gizlilik ve Güvenlik → Gerçek ekranlar → Final CTA → Footer. Karşılaşma (kişiyi @kullanıcıadı ile bulma ve karşılıklı onay) ile Harita Notu (bir mekâna bırakılan, 7 gün kalan açık mektup) metinde ayrı tutulur; Geçtiğim Yerler isteğe bağlı, varsayılan kapalı, yaklaşık bölge, en fazla 7 gün ve kesin rota takibi olmadan anlatılır; şehir akışı ana model, yakınlık keşif ipucudur. Web'de uydurma kullanıcı sayısı, puan, yorum, basın veya mağaza durumu bulunmaz; mağaza adresi boşsa "Yakında" gösterilir, `#` bağlantısı yoktur; mobil bölümlerde yalnızca gerçek Pixel 6a ekran görüntüleri (WebP, `public/web/screens/`) kullanılır. Ana sayfa tek H1, H2 bölüm hiyerarşisi, JSON-LD `featureList` (Harita Notları dahil), kısa meta açıklama ve `prefers-reduced-motion` desteğiyle sunulur; ağır JS çerçevesi yoktur.

---

## 22. Admin Paneli

Admin girişi normal kullanıcı girişinden tamamen ayrı olmalıdır.

Yetki yapısında en az Super Admin bulunmalıdır.

Admin panelinden:

### Kullanıcılar
- Arama
- Profil inceleme
- Askıya alma
- Yasaklama
- Hesap durumu

### İçerik
- Paylaşımlar
- Yorumlar
- Anonim paylaşımlar
- Karşılaşmalar
- Öne çıkan karşılaşmalar
- İçerik kaldırma

### Moderasyon
- Şikâyetler
- Kullanıcı şikâyetleri
- İçerik şikâyetleri
- Mesaj şikâyetleri
- Engelleme kayıtları

### İçerik yapılandırması
- Hobiler
- İçerik türleri
- Şehirler
- Ana sayfa modülleri
- Öne çıkarılan içerikler

### Bildirimler
- Push duyuruları
- Sistem duyuruları

### Sistem
- Temel istatistikler
- Uygulama ayarları
- Web içerikleri
- App Store / Google Play bağlantıları
- KVKK metni
- Gizlilik metni
- Kullanım koşulları
- Topluluk kuralları
- Bakım modu
- Audit log

yönetilebilir olmalıdır.

Uygulamanın kritik ayarlarında kontrol admin panelinde olmalıdır.

---

## 23. Tasarım Sistemi

Onaylı referans ekranlar tasarım açısından tek kaynaktır.

Temel görsel dil (güncel, FINAL):

- Beyaz ana arka plan
- **Mavi = işlevsel birincil renk** (`#0877E8`): navigasyon, harita, konum, filtre, normal CTA, keşif, mesajlar
- **Mor / lila = marka** (`#7C20D4`, `#A855F7`): SenMiydin logosu, marka vurguları, karşılaşma, profil vurgusu, seçili özel durumlar, drawer dekorasyonu
- Koyu lacivert metin (`#0B1F44`)
- Açık mavi yardımcı yüzeyler
- Hafif mavi gölgeler
- Bol beyaz alan
- Yuvarlatılmış kartlar
- Modern outline ikonlar
- Kalın ve rahat okunan tipografi
- Sade ve premium sosyal medya hissi

Uygulama karmaşık görünmemelidir.

### Tasarım kuralları

- KİLİTLİ ve FINAL: Ana Sayfa, Profil, Medya Görüntüleyici, Yan Menü (drawer), Alt Navigasyon, global ikon sistemi, final SenMiydin markası, açılış ekranı ve temel kart / buton / input sistemi yeniden tasarlanmaz.
- Onaylı ana sayfa yapısı değiştirilmez.
- Yeni bir tema icat edilmez.
- Koyu tema ilk sürüm için zorunlu değildir.
- Rastgele gradient kullanılmaz.
- Her şehre özel şehir fotoğrafı gerektiren bir tasarım kurulmaz.
- Fotoğraf yalnızca gerçekten içerik veya modül gerektiriyorsa kullanılır.
- İçerik okunabilirliği dekorasyondan önemlidir.
- Header ve alt navigasyon tutarlı kalır.
- Aynı spacing, radius ve buton sistemi tüm ekranlarda kullanılır.
- Ekranlar farklı ürünlerden alınmış gibi görünmemelidir.

---

## 24. Mobil Ekranlar

Mobil uygulamada en az şu ekranlar bulunacaktır:

1. Splash
2. Karşılama / Onboarding
3. Giriş
4. Kayıt
5. Profil Tamamlama
6. Hobiler / İlgi Alanları
7. Konum ve Bildirim İzinleri
8. Ana Sayfa
9. Harita
10. Filtreler
11. Arama
12. Paylaşım Oluştur
13. Karşılaştığım Kişiyi Etiketle
14. Karşılaşma Onayı / Red
15. Paylaşım Detayı
16. Yorumlar
17. Diğer Kullanıcı Profili
18. Kendi Profilim
19. Profil Düzenle
20. Karşılaşmalarım
21. Kaydedilenler
22. Bildirimler
23. Mesajlar
24. Sohbet
25. Ayarlar
26. Gizlilik / Konum / Bildirim Ayarları
27. Engellenen Kullanıcılar
28. Şikâyet
29. Hesap Silme

---

## 25. Çalışan Sistem ve Test Verisi

Mobil uygulama Laravel API, Sanctum ve MySQL ile çalışır. Kayıt/giriş, kalıcı oturum, sosyal içerik, konum, karşılaşmalar, mesajlar, bildirimler ve moderasyon gerçek servisleri kullanır. Mock önizleme ayrı geliştirme/test amacı taşır; canlı sağlayıcı veya production kullanıcı verisi gibi sunulmaz.

Development senaryoları production seed ile oluşturulmaz. Cihaz testleri ayrı disposable hesapları kullanır ve sonunda yalnızca kendi verilerini temizler. Fotoğraflar sunucuda decode/re-encode edilerek EXIF/GPS metadatasından temizlenir; dosya adları rastgele sunucu kimlikleridir.

İlk sürümde Reels, video feed, yeni story ürünü, premium, ödeme, reklam, grup sohbeti veya sesli/görüntülü arama yoktur. İki kişinin onaylı ortak karşılaşma hikâyesi mevcut ürün davranışıdır.

---

## 26. Teknik Yön

Mobil:

- Flutter
- iOS + Android tek kod tabanı

Backend:

- Laravel tabanlı API uygun bir tercihtir.

Veritabanı:

- Konum sorgularını destekleyecek yapı kullanılmalıdır.

Bildirim:

- iOS ve Android push bildirim altyapısı.

Harita:

- Mümkün olduğunca açık ve maliyetsiz çözüm.

Web:

- Public tanıtım sitesi
- Ayrı admin paneli

---

## 27. Yayına Hazırlık

Final sürüm öncesinde:

- Mobil UI kontrolü
- Responsive kontrol
- API hata yönetimi
- Güvenlik
- Konum izin metinleri
- Bildirim izinleri
- Gizlilik
- Hesap silme
- Moderasyon
- Android release
- iOS release
- Store metinleri
- Production ayarları
- Veritabanı migrationları
- Deploy dokümantasyonu

tamamlanmalıdır.

---

## 28. Referans Görseller

Proje kökünde bulunan:

`Ekran Görüntüleri`

klasörü SenMiydin? uygulamasının onaylanmış görsel referanslarını içerir.

Arayüz geliştirilirken bu klasördeki görseller temel alınmalıdır.

Referans ekranlarda görülen:

- renkler
- tipografi yaklaşımı
- header
- bottom navigation
- kart yapıları
- buton yapıları
- spacing
- radius
- gölgeler
- içerik hiyerarşisi

uygulama genelinde tutarlı biçimde devam ettirilmelidir.

Referansların dışında yeni bir görsel kimlik oluşturulmamalıdır.

---

## 29. Harita Notları / Dijital Mektuplar

> Bu bölüm ayrı ve bağımsız bir ürün modülüdür. Normal paylaşım, Karşılaşma (encounter), konum eşleşmesi (location match), Geçtiğim Yerler ve Yolculuk sistemlerinden **ayrıdır**; bunların hiçbirinin yerine geçmez.

**Fikir.** Kullanıcı şehir haritasında yaklaşık bir noktaya herkese açık bir dijital not / mektup bırakır. “Birini bulamadıysan, geçtiğiniz yere bir not bırak.” Başkaları notu okur ve nota yanıt yazabilir.

**Encounter ile farkı.** Encounter, belirli bir kullanıcıyı @kullanıcıadı ile etiketleme ve karşı tarafın onayıdır. Harita Notu ise bir mekâna bırakılmış, kimseyi etiketlemeyen herkese açık bir mektuptur. İkisi birleştirilmez; bir yanıt Encounter oluşturmaz.

**Kesin kararlar**

- **Ayrı modül.** Yeni `map_notes` ve `map_note_replies` tabloları, `MapNote` / `MapNoteReply` modelleri. Altıncı bir post türü yoktur; kanonik türler Anı, Karşılaşma, İtiraf, Düşünce, Yolculuk olarak kalır. Notlar Ana Sayfa akışına **düşmez**; deneyim Harita → Notlar'dadır.
- **7 gün.** Her not oluşturulduğu andan itibaren (`created_at + 7 gün`) haritada görünür. Kullanıcı süre seçmez. Yanıt süreyi uzatmaz. Süresi dolan not haritada, detayda ve yanıt listesinde görünmez, yanıt kabul etmez, bildirim hedefi olarak "kullanılamıyor" olur. Satırlar yönetici incelemesi için 30 gün tutulup günlük zamanlanmış görevle (`map-notes:purge`) kalıcı silinir; veritabanı sonsuza kadar büyümez, ancak 7 günlük herkese açık görünürlük kuralı değişmez.
- **Haritada herkes okur.** Notu okumak için oradan geçmiş olmak, Geçtiğim Yerler'i açmış olmak, bildirim almış olmak veya yakında olmak gerekmez. Aktif şehir haritasındaki herkes Notlar sekmesinde şehrin tüm aktif notlarını görür; mesafe filtreleri (5 / 10 / 25 km) mevcut Harita davranışıyla aynıdır.
- **Yaklaşık konum.** Seçilen nokta sunucuda `Geo::grid()` ile **harita notuna özel ince ızgaraya** (`config/map_notes.php` → `location_grid`, varsayılan **0,0005°**; kuzey-güney ≈ 55 m, Alanya enleminde doğu-batı ≈ 45 m, seçilen noktadan en fazla ≈ 36 m uzaklık) yuvarlanır. Bu ızgara, normal paylaşımları koruyan `location.post_grid` (0,005°, ≈ 555 m) değerinden bağımsızdır; normal paylaşımların gizliliği değişmez. Yalnız yaklaşık koordinat saklanır ve yayınlanır; ham koordinat hiçbir yerde tutulmaz. Aynı ızgara noktasındaki notlar tek işaret + sayaç rozeti altında gruplanır (tam eşitlik karşılaştırması yapılmaz). Eski kaba ızgarada kaydedilmiş notlar geçerli nokta olarak çalışmaya devam eder. Not yerleştirme ekranında merkezdeki nokta kaydedilecek koordinatın kendisidir (zarf ikonu noktanın üstünde durur); not oluşturma yanıtındaki sunucu koordinatı esastır, harita kamerası oraya gider (yakınlaştırma ≥ 14) ve yeni işaret kısa süre halelenir. Nokta, `CityResolver` ile seçilen aktif şehirle doğrulanır; yanlış şehirde kullanıcı dilinde hata verilir. Bu özellik başka kullanıcının canlı konumunu hiçbir zaman göstermez.
- **Açık veya anonim.** Açık notta avatar / ad / @kullanıcıadı görünür ve profile gidilir (final herkese açık profil kuralları geçerlidir: şehir, mesafe, hobi yok). Anonim notta kullanıcılara yalnız "Anonim" görünür; user_id, ad, kullanıcı adı, avatar, e-posta veya profil yolu hiçbir yanıtta bulunmaz. Yönetici moderasyon için gerçek sahibi görür.
- **Sınırlar.** Not en fazla 700, yanıt en fazla 500 karakter; boş kabul edilmez. Mevcut `ContentGuard` (yasaklı ifade, bağlantı / spam, tekrar) ve hız sınırı: saatte 8 not; yanıtlar dakikada 10, saatte 60.
- **Yanıtlar.** Her aktif nota yanıt yazılabilir. Bu özel mesaj değildir; notun altında herkese açık, **tek seviyeli** bir dizidir (yanıta yanıt yoktur). Notlar yeniden eskiye, yanıtlar eskiden yeniye sıralanır. Yanıt açık ya da anonim yazılabilir. Anonim bir notun sahibi kendi dizisinde "Not sahibi" olarak, kimliği açılmadan yanıt verir. Yanıt sahibi kendi yanıtını silebilir; düzenleme yoktur. Yazışmaya devam etmek için açık yanıtın profili ve mevcut mesajlaşma kullanılır; Harita Notları için ayrı özel sohbet yoktur.
- **Bildirimler.** `map_note_reply`: nota yanıt gelince not sahibine (not anonim olsa da), yanıtın gönderen kimliği bildirim yanıtında asla yer almaz. `map_note_nearby`: not yayınlandığı anda, aynı şehirde, yakın zamanlı konumu etkin sayılan (`location.active_minutes`) ve merkezi yarıçap (`config/map_notes.php`, varsayılan 1000 m) içindeki, yazar olmayan, engel ilişkisi bulunmayan, tercihi açık kullanıcılara **bir kez** gönderilir; Geçtiğim Yerler'in açık olması gerekmez. Ayarlarda iki ayrı tercih: "Yakınıma bırakılan notlar" ve "Notlarıma gelen cevaplar" (ikisi de varsayılan açık; `location_match` ve `nearby_activity` tercihlerinden bağımsız). Tercih kapatılınca ne uygulama içi ne cihaz bildirimi oluşur.
- **Güvenlik.** Engelleme çift yönlüdür: notlar, yanıtlar, bildirimler, profile geçiş ve nearby bildirimi iki taraf için de görünmez; engel kalkınca yeni içerik normal görünür. Rapor hedefleri `map_note` ve `map_note_reply`; kendi içeriğini raporlayamaz, anonim içerik yöneticiye gerçek sahibiyle iletilir. Not sahibi notunu siler (haritadan ve herkese açık dizilerden kalkar, eski bildirim güvenli "Bu içerik artık kullanılamıyor." gösterir). Hesap silmede notlar ve yanıtlar anında herkese kapanır.
- **Admin.** Harita Notları alanı: kimlik, yazar, anonim mi, şehir, metin önizleme, yanıt sayısı, oluşturma / bitiş zamanı, aktif / süresi dolmuş / kaldırılmış durumu, şikâyetler; detay, not ve yanıt kaldırma / geri açma, işlem günlüğü.
- **Tasarım.** Harita Notu pini marka moru / lila outline zarf ikonudur (emoji yok), birden çok not varsa sayı rozeti taşır; normal paylaşım pini mavi konum pini olarak kalır. Mektup yüzeyi çok hafif sıcak beyaz, ~22 yarıçap, ince lila sınır, yumuşak gölge, lacivert metin; yeni font veya tema yoktur. Harita altlığı (OSM) boyanmaz.

**Bu sürümde yoktur:** yanıta yanıt, not / yanıt düzenleme, süre seçimi, özel not sohbeti.


## 30. Takip Akışı

- **Ana Sayfa sekmeleri:** Akış · **Takip** · Yakın · Popüler (mevcut yatay sekme davranışı; 320–430 px'te taşmaz).
- **Backend:** `GET /feed?following=1` aynı Post sorgusunu yeniden kullanır (şehir, görünürlük, engel, askıya alma, silinmiş, sayfalama kuralları aynen geçerlidir) ve yalnız kullanıcının takip ettiği kişilerin gönderilerini döner.
- **Anonim gizliliği:** Takip akışı **anonim gönderileri göstermez** (`is_anonymous = false`). Kısa bir takip listesinde anonim gönderiler yazarı ele verirdi. Anonim gönderiler Akış / Yakın / Popüler içinde anonim olarak görünmeye devam eder. Karar testle korunur.
- **Boş durum:** "Henüz kimseyi takip etmiyorsun." + kısa açıklama + "İnsanları Keşfet" (mevcut `/search`). Takip edilen kimse yoksa "Takip ettiklerin henüz bir şey paylaşmadı." gösterilir. Yeni keşif ekranı yoktur.
- Popüler algoritması takip veya ilgi alanı ile manipüle edilmez.

## 31. Yorum Yanıtları

- **Tek seviye:** ana yorum → yanıtlar. Yanıtın yanıtı, sonsuz iç içe yapı **yoktur**. `post_comments.parent_id` (nullable); sunucu `parent_id` olarak başka bir yanıtı, başka bir yazının yorumunu veya görünmeyen bir yorumu reddeder (422 / 404).
- **Sıralama:** ana yorumlar mevcut davranışla (yeniden eskiye); bir ana yorumun yanıtları **eskiden yeniye** (konuşma okunur). Liste ilk 3 yanıtı gömer; "N yanıt daha" ile tamamı `GET /posts/{post}/comments/{comment}/replies` üzerinden yüklenir.
- **Arayüz:** her ana yorumun altında küçük "Yanıtla"; composer `@kullanıcıadı ` ile başlar ("Yanıtlanıyor" şeridi, iptal düğmesi). Hashtag / mention ağı yoktur; yalnız konuşma bağlamı.
- **Bildirim `comment_reply`:** "Yorumuna bir cevap geldi." yalnız cevaplanan yorumun sahibine; kendi yorumuna cevap, engel ilişkisi, silinmiş / modere hedef için bildirim yok (güvenli "kullanılamıyor"). Yazı sahibi aynı zamanda ana yorum sahibiyse tek anlamlı bildirim; yanıtlar için ayrıca genel "comment" bildirimi üretilmez. Tercih mevcut "Yorumlar" kategorisiyle yönetilir.
- **Silme / moderasyon:** ana yorum silinir veya modere edilirse tüm başlık herkese kapanır (yetim yanıt yok, yorum sayısına girmez). Yanıt silme yalnız sahibine açıktır. Rapor mevcut `comment` hedefini kullanır; ContentGuard yanıtlara da uygulanır; engel iki yönlüdür.

## 32. Mektuplarım

- **Drawer:** tek satır "Mektuplarım" (outline zarf, marka moru vurgu).
- **Ekran:** `Aktif` · `Arşiv`. Aktif: hâlâ herkese açık 7 günlük notlar (önizleme, yaklaşık bölge, cevap sayısı, mektubun gerçek tarihi, "N gün kaldı"). Arşiv: süresi dolan veya kullanıcının haritadan kaldırdığı notlar; **yalnız sahibine görünür**, başka kullanıcı göremez.
- **"Haritadan Kaldır"** (`POST /map-notes/{id}/archive`): herkese açık görünürlük kapanır, mektup Arşiv'de kalır. **"Kalıcı Sil"** (`DELETE /map-notes/{id}`): metin, yanıtlar ve kişisel erişim silinir (raporlanmış notlar moderasyon penceresi boyunca yumuşak silinir). Hesap silme her şeyi kaldırmaya devam eder.
- **Saklama:** herkese açık 7 gün değişmez. Sahibinin özel arşivi, kullanıcı kalıcı silene veya hesabı silene kadar korunur; `map-notes:purge` artık süresi dolmuş notları **silmez**, yalnız kalıcı silinmiş / moderasyonla kaldırılmış satırları denetim penceresi (30 gün) sonrası temizler. Moderasyon / denetim saklaması ile kullanıcı arşivi ayrı kavramlardır.
- **"Tekrar Paylaş"** (`POST /map-notes/{id}/repost`): arşivdeki kendi mektubunu aynı yaklaşık noktaya **yeni bir yayın** olarak bırakır: `created_at` / `expires_at` yeni 7 gün; `occurred_at` (mektubun gerçek tarihi) **değişmez** ve kartta "Tekrar paylaşıldı" notuyla gösterilir. Eski yanıtlar yeni herkese açık başlığa taşınmaz (yalnız sahibin arşivinde kalır). Aynı anda tek canlı yayın; yeniden "yakınında" bildirimi gönderilmez.

## 33. Yakındaki Yeni Mektuplar

- **Ana Sayfa:** küçük, düşük yükseklikli kart "Yakınında N yeni mektup var · Haritada keşfet". Yalnız: harita notları açık, kullanıcının yakın zamanlı konumu varsa ve gerçekten **açılmamış** yakın aktif not varsa görünür; 0 ise veya konum yoksa **hiç kart yok**. Tıklayınca Harita → Notlar modunda açılır.
- **"Yeni" tanımı:** kullanıcı not detayını gerçekten açana kadar okunmamıştır (`map_note_reads`, `POST /map-notes/{id}/read`, idempotent). Haritada işaretin görünür olması okundu sayılmaz; kendi notu hiç izlenmez.
- **Gizlilik:** okuma kaydı başka kullanıcıya ve not sahibine **asla** görünmez (kim okudu listesi, görüntülenme sayısı yoktur).
- **Rozet:** Harita → Notlar sekmesinde kullanıcıya özel küçük "N yeni" rozeti. Engelli / kaldırılmış / süresi dolmuş notlar sayıma girmez.
- **Yönetim:** Modül Ayarları'nda "Yakınında yeni mektuplar" anahtarı kartı kapatır; Harita Notları özelliğinin kendisi etkilenmez.

## 34. Discovery Ranking Principles

- Dating değil: "Ne arıyorsun?", "Sevgili ara", uyum yüzdesi, eşleşme oranı, "perfect match" **yoktur**; herkese açık profile tercih chip'i eklenmez.
- Yakındaki İnsanlar'da mesafe (herkese gösterilen 100 m adımı), gizlilik, engel, etkinlik ve şehir uygunluğu ana kuraldır. Aynı mesafe adımındaki kişiler arasında **düşük ağırlıklı, iç** bir sinyal sıralamayı değiştirir: ortak ilgi alanı (en çok 3) ve karşılıklı uyumlu mevcut `connections` tercihi (1). Zorunlu filtre değildir: farklı tercih seçen biri kaybolmaz. Sinyal hiçbir yanıtta görünmez.
- Popüler algoritması takip / ilgi alanı ile değiştirilmez.

## 35. Yaş / Mağaza Hazırlığı

Üretim minimum yaşı **18** olarak kalır; değer tek yapılandırmadır (`config/mobile.php` → `MINIMUM_AGE`, panelde 16–25) ve backend doğrulaması, `/app-config`, Flutter tarih seçici / metinleri birlikte güncellenir. 16–17 desteği için yaş bandı güvenlik planı, Apple yaş derecelendirme beyanı ve Google Play hedef kitle notları `docs/AGE_AND_STORE_READINESS.md` içindedir. Doğum tarihini yalnız 18 → 16 yapmak kabul edilmez; 13–15 kapsam dışıdır.
