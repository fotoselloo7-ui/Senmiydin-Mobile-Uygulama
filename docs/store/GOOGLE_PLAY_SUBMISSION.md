# Google Play submission — Türkçe

Denetim: 9 Kasım 2026. Kimlikler com.senmiydin.app; sürüm 0.1.0+1. Bu dosya kopyalama taslağıdır; [GERÇEK BİLGİ GEREKLİ] alanları tamamlanmadan konsola gönderilmez.

## Kopyalanacak alanlar

### Uygulama adı
```
SenMiydin?
```
### Kısa açıklama
```
Şehrindeki hikâyeleri keşfet, yarım kalan karşılaşmalara yeniden merhaba de.
```
### Uzun açıklama
```
SenMiydin?, gerçek hayattaki karşılaşmaları ve şehir hikâyelerini bir araya getiren bir sosyal keşif uygulamasıdır. Sahilde, kafede veya bir yolculukta yarım kalan bir merhabayı, paylaşım ve karşılıklı onayla yeniden bir hikâyeye dönüştürmeyi amaçlar.

Şehrinin akışını keşfet
Anı, düşünce, itiraf, karşılaşma ve Yolculuk paylaşımlarına göz at. İstersen metin veya fotoğraf paylaş; ilgi alanlarınla keşfini şekillendir. Haritada paylaşımların yaklaşık noktalarını gör.

Karşılaşmayı birlikte doğrulayın
Karşılaştığın kişinin kullanıcı adını biliyorsan onu @kullanıcıadı ile etiketle. Karşı taraf kabul ettiğinde karşılaşma doğrulanır. Ortak hikâyenin yayımlanması için ayrıca partner onayı gerekir. Konum önerisi tek başına doğrulanmış karşılaşma değildir.

Geçtiğin yerlerdeki hikâyeler
Geçtiğim Yerler isteğe bağlıdır ve başlangıçta kapalıdır. Açtığında izinli konum geçmişin, daha sonra o bölgelerde paylaşılan ilgili hikâyeleri keşfetmene yardımcı olabilir. Eşleşme bildirimlerini ayrıca yönetebilirsin.

Yolculukta da bir merhaba
Otobüs, tren, uçak veya feribot yolculuğunu paylaş. İstersen güzergâh, yaklaşık kalkış saati ve yolculuk bilgilerini ekle; hangi detayların görünür olacağını seç.

İletişimini kontrol et
Mesaj istekleriyle sohbet başlat. Engelleme, şikâyet ve gizlilik ayarlarıyla iletişimini yönet. Kesin konumun diğer kullanıcılara gösterilmez; Yakındaki İnsanlar yalnız görünürlük tercihi açık uygun profillerden bir seçki sunar.

Konum izni vermeden de manuel şehir seçerek temel akışı kullanabilirsin. SenMiydin? kesin eşleşme veya bir kişiyi bulma garantisi vermez; canlı kişi ya da araç takibi sunmaz.

Android’de Geçtiğim Yerler’i açıkça etkinleştirdiğinde konum kaydı, uygulamada başlatılan görünür konum servisiyle arka planda da sürebilir. Özelliği kapatarak kaydı durdurabilir ve geçmişini temizleyebilirsin.
```

| Console alanı | Değer / işlem |
|---|---|
| Tür / kategori | Uygulama / Social (Sosyal); flört merkezli konumlandırma yapılmaz |
| Etiketler | Console’un sunduğu seçeneklerden Social / Social networking / Local kavramlarına en yakın, gerçek işleve uygun en çok 5 etiket; serbest keyword alanı varmış gibi doldurma |
| Keyword yaklaşımı | Karşılaşma, şehir, keşif, anı, düşünce, itiraf, Yolculuk ve mesaj isteği kavramları doğal metne yerleştirildi; rakip markası, sıralama iddiası veya keyword tekrarı yok |
| Geliştirici / şirket / adres | [GERÇEK BİLGİ GEREKLİ] |
| Destek e-postası | [GERÇEK BİLGİ GEREKLİ] |
| Telefon (sunulacaksa) | [GERÇEK BİLGİ GEREKLİ] |
| Web sitesi | [GERÇEK BİLGİ GEREKLİ] — yayınlanmış gerçek kök adres |
| Privacy Policy URL | [GERÇEK BİLGİ GEREKLİ] — uygulamadaki /gizlilik yolu |
| Account deletion URL | [GERÇEK BİLGİ GEREKLİ] — /hesap-silme yolu |
| Reklam içeriyor mu? | **Evet (Contains ads = YES):** Google AdMob native feed reklamları; ayrıntı SDK_AUDIT.md. Hedef kitle 16+; 16–17 için yaş kısıtlı reklam işleme |
| Uygulama içi satın alma | Hayır; ödeme/abonelik/billing akışı yok |
| Hedef kitle | Mevcut kayıt alt sınırı 18; Console hedef kitlesi yetişkinler olarak seçilmeli. Bu bilgi IARC sonucunun yerine geçmez |
| Erişim | Hesap gereklidir. E-posta/kullanıcı adı + parola; Google/Apple yalnız gerçek yapılandırma etkinse alternatif |
| İnceleme hesabı kullanıcı adı | [GERÇEK BİLGİ GEREKLİ] |
| İnceleme hesabı parolası | [GERÇEK BİLGİ GEREKLİ] — yalnız Console’un güvenli alanına girilir |
| İnceleme için şehir | [GERÇEK BİLGİ GEREKLİ] — manuel seçimle GPS olmadan içerik görülebilmeli |

## App access açıklaması

Hesapla giriş yaptıktan sonra Ana Sayfa şehir seçicisinden inceleme şehrini seçin. Konum ve bildirim izinleri temel akış için zorunlu değildir. Gönderi, fotoğraf, doğrulanmış ortak karşılaşma ve kabul edilmiş örnek mesaj isteği review hesabında hazır tutulmalıdır. İki kişinin etkileşimini incelemek gerekirse ikinci normal rol hesabı sağlanır. Gerçek hesaplar ve erişim ayrıntıları REVIEW_ACCOUNT.md süreciyle manuel hazırlanır. Yerel Demo parolası veya üretim admin hesabı verilmez.

## UGC / konum / bildirim açıklamaları

Kullanıcılar metin, fotoğraf ve yorum yayımlar; ilk özel mesaj bir istektir. Şikâyet, engelleme ve admin kaldırma/askıya alma mekanizmaları vardır. Otomatik görsel inceleme veya uçtan uca şifreleme iddiası yoktur. Konum şehir/bölge keşfi, yaklaşık yakınlık ve izinli geçmiş eşleşmesi içindir. Kesin koordinat başkalarına gösterilmez; ağ üzerinden hassas koordinat işlenebildiği için Data Safety’de precise location dikkate alınır.

Android’de opt-in Geçtiğim Yerler görünür location foreground service ile arka planda sürebilir. ACCESS_BACKGROUND_LOCATION manifestte yoktur; kullanımın Play background-location değerlendirmesinden otomatik muaf olduğu söylenmez. BACKGROUND_LOCATION_DECLARATION.md ve video planı kullanılır. Bildirimler isteğe bağlıdır; canlı push gerçek FCM yapılandırmasına bağlı, uygulama içi merkez ayrıdır.

## Gönderim öncesi tamamlanacaklar

Data Safety, içerik derecelendirmesi, UGC ve sosyal uygulama çocuk güvenliği beyanları ek dosyalardan doldurulur. Gerçek CSAE standardı URL’si ve çocuk güvenliği iletişim kişisi eksiktir. Final logo ve onaylı store görselleri gelmeden görsel alanlar tamamlandı sayılmaz. Gerçek HTTPS/legal içerik/review hesabı/signing hazır olmadan submit yapılmaz.

Sınırlar: ad ≤30, kısa açıklama ≤80, uzun açıklama ≤4000 karakter. Sayılar store_readiness_check ile ölçülür. Kaynak: [Google uygulama/mağaza alanları](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en), [çocuk güvenliği](https://support.google.com/googleplay/android-developer/answer/14747720?hl=en).
