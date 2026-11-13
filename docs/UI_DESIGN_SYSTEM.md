# Mobil tasarım sistemi

Ana kaynak Ekran Görüntüleri klasöründeki iki onaylı panodur. Beyaz ana zemin, canlı mavi vurgu, lacivert içerik, açık mavi yardımcı yüzey, hafif sınır ve outline ikon dili korunur. Final logo üretilmez.

| Alan | Ortak kaynak / kullanım |
|---|---|
| Renkler | AppColors: blue marka/ikon, action küçük beyaz metinli birincil buton ve seçili chip, navy içerik, muted metadata, pale yardımcı yüzey, line sınır, danger okunabilir tehlike metni/aksiyonu, red kalp vurgu |
| Aralıklar | Space 4 / 8 / 12 / 16 / 20 / 24 / 32; sayfa kenarı 16 |
| Köşeler | AppShape 8 / 12 / 16 / 20 / pill; varsayılan kart 16 |
| Etkileşim ölçüsü | AppDimensions.touch=48; input/button 52; top bar 56; bottom nav 72, büyük yazıda genişler |
| Tipografi | Nunito Sans; display 30, headline 25, title 20, section 16, body 15 ve 1.5 satır aralığı, metadata 12, button 15 |
| Ağırlık | Başlık/isim 700–800, uzun gönderi metni 400, metadata 500; mevcut geçici wordmark kendi ağırlığını korur |
| Kart yüzeyi | AppShape.card varsayılan gölgesiz hafif sınır; elevated yalnız gerekirse |
| Birincil aksiyon | PrimaryButton, koyulaştırılmış mavi; minimum 52 ve ortalanmış çok satırlı metin |
| Form alanı | Field; next/newline, ortak hata/label; güvenli alanlarda erişilebilir göster/gizle |
| Seçim | ChoicePills ve InterestChip; seçili durum renk yanında check/semantics ile anlaşılır; read-only interest no-op buton değildir |
| Loading | LoadingState: sabit, erişilebilir açıklamalı sade placeholder; yeni dependency veya sürekli shimmer yok |
| Empty/error | EmptyState, InfoNote, mevcut gerçek hata mesajı ve Tekrar Dene; stack trace/HTTP kodu gösterilmez |
| Ayarlar | SectionLabel ile hesap/profil, gizlilik/tercihler, destek/hakkında, oturum/hesap işlemleri |
| Medya | Gerçek image dizisi; boşsa shrink. Tek fotoğrafta sayaç/dot yok. Önizleme contain/zoom; tam görsel crop edilmez |
| İki carousel | Featured pager çoklu hikâyede lacivert kısa çubuk kullanır; medya kendi mavi yuvarlak dot ve gerçek fotoğraf sayacını kullanır. İkisi tek öğede gizlenir |
| Harita | Yaklaşık koordinat/marker, gerçek current-region kontrolü, tile hatası için yeniden yükleme, görünür OSM atfı |
| Gizlilik | Anonim kart owner/avatar/profile route açmaz. History kaydı ile bildirim tercihi ayrı anlatılır |

Home modül sırası değiştirilmez. Şehir adı dar ekranda veya büyük yazıda tabların altına geçer ve tam adı sarılarak okunur. İlgi seçim kartlarının yüksekliği yazı ölçeğine göre büyür. Backend'de bulunmayan count/online durumu/filtre/arama yeteneği çizilmez. Yeni Anı/İtiraf/Düşünce/Yolculuk seçenekleri mevcut feed content API'sine bağlanır; bağımsız photo+type birleşimi desteklenmediği için aynı anda iki filtre varmış gibi sunulmaz.

Ölçüm: action/white ve muted/white kontrastları widget testinde ≥4.5 doğrulanır. 320×568 viewport ve 1.6× yazı; ayrıca 2× uzun izin diyaloğu testi bulunur. Tam TalkBack oturumu ve her OEM/ekran/işletim sistemi doğrulaması yapılmış gibi raporlanmaz. Güncel sonuçlar UI_AUDIT.md ve VALIDATION.md içindedir.
