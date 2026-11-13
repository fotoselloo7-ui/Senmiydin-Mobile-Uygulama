# Store screenshot planı — üretim yapılmadı

**Final branding uygulanmadan store screenshot çekilmeyecek.** Mevcut docs/screenshots doğrulama görüntüleri geçici marka ve yerel veri içerir; mağaza varlığı olarak yeniden paketlenmedi. Aşağıdaki 9 kare adaydır.

| Aday | Gerçek ekran | Kısa mağaza başlığı | Çekim şartı |
|---|---|---|---|
| 1 | Ana Sayfa / şehir akışı | Şehrinin hikâyelerini keşfet | Temiz doğal metin, gerçek görünür hesap, final marka |
| 2 | Yakınındaki İnsanlar + Öne Çıkan Karşılaşmalar | Bir merhabaya yeniden yer aç | Yalnız görünürlüğü açık profiller; fotoğrafsız kartta büyük medya yok |
| 3 | Harita | Hikâyelere haritada göz at | Yaklaşık post noktaları, attribution görünür, kesin kişi GPS’i yok |
| 4 | Paylaşım Oluştur | Aklında kalan anı paylaş | Anı/düşünce/itiraf/karşılaşma seçenekleri, fotoğraf isteğe bağlı |
| 5 | Konum → Geçtiğim yerlerden seç | Geçtiğin yerlerin hikâyeleri | Sadece hesabın kendi izinli geçmişi, yaklaşık bölge/yuvarlanmış saat; iOS foreground sınırı korunur |
| 6 | Yolculuk formu veya kartı | Yolculukta da bir merhaba | Güzergâh/isteğe bağlı public detay; aynı araç garantisi veya yeni grup yok |
| 7 | Doğrulanmış ortak karşılaşma | Birlikte doğrulanan hikâyeler | İki avatar, status, partner onaylı metin; iki gerçek fotoğrafta yalnız gerçek 1/2 |
| 8 | Mesajlaşma / mesaj isteği | İletişimini sen yönet | Normal örnek konuşma; kabul/engel/şikâyet; E2EE simgesi veya sahte güvenlik iddiası yok |
| 9 | Profil / gizlilik | Görünürlüğün senin elinde | Gerçek privacy kontrolleri; izin reddiyle manuel şehir örneği |

Android için Console’un ilgili cihaz grubundaki screenshot sayısı sınırına uy: en fazla 8’lik sette 1 ve 2 mevcut Home’un aynı karesinde gösterilebilir veya adaylardan biri çıkarılır. iOS için uygun iPhone cihaz grubunda bu 9 aday sıralanabilir; iPad destekleniyorsa ayrıca gerçek iPad seti gerekir. Ekran ölçüleri son Console/App Store Connect cihaz gereksiniminden alınır; Windows emülatörünü iPhone ekranı gibi etiketleme.

## Üretim kontrolü

Gerçek yayın adayı, final ikon/logo, gerçek çalışır backend, izinli demo/review görselleri ve kullanım hakkı onaylanmış fotoğraflar kullanılır. Kullanıcı/mesaj gizliliği korunur. Timestamp, UUID, debug işareti, test suffix’i veya dolu olmayan provider düğmesi başarı sahnesi yoktur. UI yeniden tasarlanmaz; olamayan ekran/özellik çizilmez. Mağaza üst yazıları gerçek ekranın anlamını değiştirmez.

Dosya teslimi Android/iOS ve locale için ayrı, seçilen cihazın gerçek piksel ölçülerinde ve mağazanın kabul ettiği PNG/JPEG formatında yapılır. Bu tur görsel üretimi yapılmadı.

Kaynaklar: [Google preview assets](https://support.google.com/googleplay/android-developer/answer/9866151), [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
