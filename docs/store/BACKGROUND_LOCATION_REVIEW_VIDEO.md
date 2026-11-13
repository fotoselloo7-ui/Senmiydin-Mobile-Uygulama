# Background location review videosu — yalnız çekim planı

Video üretilmedi. Yalnız Android gerçek yayın adayı ve gerçek izin/FGS davranışı kaydedilecek. iOS videosu kullanılmayacak. Google’ın önerdiği kısa ana kanıt hedefi yaklaşık **30 saniye**; gerekli adımlar anlaşılmıyorsa kesilmiş bir yalan akış üretmek yerine ek ayrıntılı kayıt hazırlanır.

## Ön hazırlık

Final branding, gerçek backend, erişimi açık privacy URL’si ve iki normal review hesabı hazırlanır. Hesaplar manuel şehirle de kullanılabilmeli; geçmiş/bildirim başlangıçta kapalı olmalı. Android konum izni daha önce verilmemiş bir inceleme durumu hazırlanır. Kayıtla gösterilecek geçmiş bölge ve daha sonra oluşturulacak ilgili gönderi kontrollü, izinli gerçek test verisidir; başka kişilerin özel verileri gösterilmez.

## Ana kısa kanıt — yaklaşık 0–30 saniye

| Süre | Gerçek ekran / hareket | Gösterilecek kanıt |
|---|---|---|
| 0–3 sn | Normal uygulama açılışı, Profil → Ayarlar | Uygulama adı ve gerçek build |
| 3–6 sn | Gizlilik ve Konum → Konum | Geçmiş anahtarı kapalı |
| 6–11 sn | “Geçtiğim Yerler” aç; mevcut onay diyaloğu | Sunucuya konum iletimi, arka plan, hikâye önerisi ve silme açıklaması okunabilir |
| 11–15 sn | Onay ve Android konum penceresi | Gerçekte istenen kullanım sırasında/approximate-precise seçenekleri; olmayan “Always” ekranını üretme |
| 15–20 sn | Uygulamayı küçült; sistem bildirim alanını aç | “SenMiydin? · Geçtiğim Yerler” devam eden konum servisi |
| 20–24 sn | Uygulamaya dön; paylaşımda Konum → Geçtiğim yerlerden seç | Kaydedilmiş yaklaşık bölge / yuvarlanmış saat |
| 24–27 sn | Hazırlanmış ilgili paylaşım ve Bildirimler merkezi | Gerçek eşleşme önerisi / doğru gönderiye açılan in-app notification; otomatik “Karşılaşıldı” yok |
| 27–30 sn | Aynı geçmiş anahtarını kapat | Kaydın durması; geçmiş seçicisinde temizlenme ek kayıtta doğrulanabilir |

Tek kısa videoda bütün adımlar okunur gösterilemiyorsa ana deklarasyon videosu disclosure + runtime prompt + background FGS kanıtına odaklanır; geçmiş/sonraki gönderi/bildirim/kapama ikinci, açıkça “ayrıntılı demo” olarak verilen bölümde yer alır. Saatler arası gerçek bekleme hızlandırılırsa açıkça belirtilir; sahte UI, sahte permission diyaloğu veya var olmayan push teslimatı eklenmez.

## Ayrıntılı kontrol sırası

1. İzin verilmeden manuel şehirle temel akışın kullanılabildiğini göster.
2. Konum geçmişini kullanıcı eylemiyle aç; başlangıçtaki açıklama/izin sırasını tam kaydet.
3. Uygulama küçültülmüşken gerçek konum örneği/FGS etkisini göster. Force-stop sonrası çalışıyormuş gibi anlatma.
4. İzinli geçmişin yaklaşık bölge/saat seçimini göster.
5. İkinci hesapla ilgili bölge ve olay zamanında gerçek gönderi oluştur.
6. İlk hesapta feed önerisini ve yalnız location_match tercihi açıkken in-app bildirimi göster.
7. Bu önerinin onaylı karşılaşma rozeti üretmediğini göster.
8. Geçmişi kapat; bölge listesi ve eşleşmelerin temizlenmesini doğrula.
9. Bildirim tercihi ile history kaydetme izninin ayrı olduğunu açıkla.

Video URL’si, erişim yetkisi ve gerçek review hesapları: [GERÇEK BİLGİ GEREKLİ]. Kayıt Store build’inin gerçek davranışı ve deklarasyon metniyle karşılaştırılmadan gönderilmez.

Kaynak: [Google video gereksinimleri](https://support.google.com/googleplay/android-developer/answer/9799150?hl=en). Final disclosure/video policy değerlendirmesi BACKGROUND_LOCATION_DECLARATION.md içinde WAITING; gerçek legal içerik ve yayın bilgileri MISSING olarak kayıtlıdır.
