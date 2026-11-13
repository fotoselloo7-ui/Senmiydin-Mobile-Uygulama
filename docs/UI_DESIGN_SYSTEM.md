# Mobil tasarım sistemi

> **Güncel kaynak (13 Kasım 2026).** Bu belgenin ilk bölümü FINAL karardır ve kod (`lib/core/theme.dart`, `lib/widgets/app_drawer.dart`, `lib/widgets/media_viewer.dart`) ile uyumludur. "Tarihsel notlar" bölümündeki eski ifadeler (ör. "mavi marka rengi", "iki panodan türetilen mavi dil") geçersizdir; geçmiş kanıt olarak korunur.

## FINAL kararlar

**Kilitli yüzeyler** (yeniden tasarlanmaz, sadeleştirilmez, rengi değiştirilmez): Ana Sayfa, Profil, Medya Görüntüleyici, Yan Menü / Hamburger (drawer), Alt Navigasyon, global ikon sistemi, final SenMiydin markası, açılış ekranı ve temel kart / buton / input sistemi.

**Renk kuralı**

| Rol | Renk | Kullanım |
|---|---|---|
| Mavi = işlevsel birincil | `#0877E8` (`AppColors.primary`; hover `#0567CA`; parlak `#19AEFF`) | navigasyon, harita, konum, filtre, normal CTA, keşif, mesajlar |
| Mor / lila = marka | `#7C20D4`, `#A855F7` (derin `#5413A5`) | SenMiydin logosu, marka vurguları, karşılaşma, profil vurgusu, seçili özel durumlar, drawer dekorasyonu |
| Lacivert = metin | `#0B1F44` (`AppColors.navy`) | başlık ve gövde metni |
| Beyaz = ana yüzey | `#FFFFFF`, ikincil `#F7F9FC` | arka plan ve kartlar |

**İkon sistemi:** Yan menüdeki ikonlar ana referanstır: outline, yuvarlak uçlu, ortak stroke hissi, tutarlı boyutlar (`AppDimensions.iconXS…iconXL`). Drawer, Ayarlar, Filtre ve özellik kartlarında yumuşak ikon kutusu (`AppIconBox`, `surfaceIcon`) kullanılabilir. Alt navigasyon, app bar, gönderi aksiyonları, sohbet ve kapat düğmelerinde ikon tek başına (outline) durur. Emoji, rastgele SVG veya farklı dolu ikon ailesi eklenmez.

**Herkese açık profil:** kapak, avatar, ad, @kullanıcıadı, kısa biyografi, Paylaşım / Karşılaşma / Takipçi / Takip sayaçları, Takip Et / Mesaj, Paylaşımlar / Karşılaşmalar / Medya sekmeleri. Şehir satırı, konum, mesafe ve hobi / ilgi çipi gösterilmez; kişi listelerinde yalnız `@kullanıcıadı` görünür. Kendi profilde gerekirse özel Kaydedilenler bulunur. Kapak fotoğrafı Profil Düzenle ekranındaki "Kapak Fotoğrafı" satırından değiştirilir (yeni panel yok).

**Medya görüntüleyici (final):** koyu arka plan, açık yuvarlatılmış görüntüleyici, büyük fotoğraf (contain), kaydırma, 1/2 sayaç, küçük resimler, pinch ve çift dokunma zoom, hata / yeniden dene; mobilde önceki / sonraki oku yoktur.

**Yeni arayüz gerekirse:** `AppColors`, `AppShape`, `AppDimensions`, `AppTypography`, `PrimaryButton`, `SecondaryButton`, `AppIconBox` ve `common.dart` bileşenleri kullanılır; ayrı stil sistemi, rastgele gradient veya yeni font eklenmez.

**Public web** mobil gibi kilitli değildir; aynı renk rolleriyle (mavi işlevsel, mor / lila marka, lacivert metin, beyaz yüzey) geliştirilir. Ayrıntı: SENMIYDIN_URUN_TANIMI.md §21.

## Tarihsel notlar (ilk UI denetimi, 10 Kasım 2026)

(Tarihsel) Ana kaynak Ekran Görüntüleri klasöründeki iki onaylı panoydu. Beyaz ana zemin, canlı mavi vurgu, lacivert içerik, açık mavi yardımcı yüzey, hafif sınır ve outline ikon dili korunur. (Final marka sonradan kodda uygulandı; geçerli kural yukarıdaki FINAL bölümüdür.)

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
