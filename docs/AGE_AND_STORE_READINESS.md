# Yaş, mağaza ve 16+ hazırlık raporu

Durum: 14 Kasım 2026. **Üretim minimum yaşı 18 olarak kalır.** Bu belge, 16+ desteğine geçmeden önce ne yapılması gerektiğini ve uygulamanın şu an mağaza formlarında neyi beyan etmesi gerektiğini açıklar. Hiçbir beyan, ürünün gerçek özelliklerini gizleyecek şekilde yazılmamalıdır.

## 1. Kod hazırlığı (bu turda tamamlandı)

Minimum yaş artık **tek bir yapılandırma değeridir**:

| Katman | Davranış |
|---|---|
| `backend/config/mobile.php` → `minimum_age` | `MINIMUM_AGE` ortam değişkeni, varsayılan **18** |
| Backend kayıt doğrulaması | `AuthController` doğum tarihini `Settings::get('minimum_age')` ile doğrular; hata metni değeri içerir |
| Yönetim paneli | Ayarlar → "Minimum kayıt yaşı"; sınır **16–25** (16'nın altı kabul edilmez) |
| `/api/v1/app-config` | `minimum_age` alanı (genel okuma) |
| Flutter | Kayıt ekranındaki doğum tarihi seçici, yardım metni ve onay kutusu metni `AppStore.minimumAge` değerini kullanır; hiçbir yerde sabit "18" yoktur (`test/social_engagement_test.dart`) |
| Test | `SocialEngagementTest::test_minimum_age_is_one_config_value...`: 17 yaş 18'de reddedilir, tek ayarla 16'ya geçince kabul edilir, 15 reddedilir |

Yani tek ayar değişikliğiyle (`MINIMUM_AGE=16` veya panel) doğrulama, tarih seçici ve metinler birlikte güncellenir. **Bunu tek başına yapmak 16–17 yaşı güvenle desteklemek anlamına gelmez** (bkz. §4).

## 2. Apple App Store — yaş derecelendirme anketi

SenMiydin kendini **flört uygulaması olarak konumlandırmaz** (Reels, swipe, eşleşme destesi, "sevgili ara" modu, uyum yüzdesi yoktur). Ancak anketi gerçek özelliklere göre doldurmak gerekir:

| Anket alanı | Gerçek durum | Beyan |
|---|---|---|
| Kullanıcı tarafından oluşturulan içerik / sosyal medya | Paylaşım, yorum (tek seviyeli yanıt), harita notu ve yanıtı, mesaj, fotoğraf | **Evet** |
| Paylaşılan konum | Yaklaşık konum, Yakındaki İnsanlar (opt-in), harita, harita notları, Geçtiğim Yerler (opt-in) | **Evet** (kesin GPS paylaşılmaz; yaklaşık) |
| Kullanıcılar arası mesajlaşma | İzinli birebir mesaj, fotoğraf mesajı; grup sohbeti ve arama yok | **Evet** |
| Tanışma / ilişki ("Dating and Relationships") | Karşılaşma = belirli kişiyi @kullanıcıadı ile bulma + karşılıklı onay; profilde `connections` tercihleri (arkadaşlık, karşılaşmalar, sohbet, insanlarla tanışma) iç sıralama sinyalidir, herkese açık değildir | Anketteki soru "romantik / flört işlevi" mi diye soruyorsa: ürün flört amaçlı değildir ama **insanlarla tanışma ve karşılaşma** işlevi vardır; bu, App Review Notes'ta açıkça yazılmalı ve soru en yakın doğru yanıtla (işlev kısmen var) işaretlenmelidir. Yanlış "hiç yok" beyanı **yapılmamalıdır** |
| Yetişkinlere özel / müstehcen içerik | Yok (ContentGuard, rapor, moderasyon) | Hayır |

**App Review Notes'ta açıklanacaklar:** UGC (rapor, engelleme, ContentGuard, yönetim panelinde moderasyon, hesap silme sayfası ve uygulama içi silme); konum kullanımı (ön planda, yaklaşık, kapatılabilir; Geçtiğim Yerler varsayılan kapalı); harita notlarının herkese açık, 7 gün yaşayan, anonim olabilen yapısı; yorum yanıtları; test hesabı. **Destek e-postası / iletişim bilgisi** hâlâ **dış bağımlılıktır** (aşağıda).

## 3. Google Play — hedef kitle

- Hedef yaş **18+** ise: "Hedef kitle" formunda 18+ seçilir; ek küçük yaş önlemi gerekmez. Mevcut durum budur.
- **16–17 hedeflenirse** Play, çocuk / genç hedef kitle politikaları ve UGC + konum politikaları devreye girer: yaş kapısı (age gate), reşit olmayanlar için ek korumalar, "tanışma / sosyal" işlevlerinin yetişkin ve reşit olmayan arasında ayrılması, konum paylaşımı beyanı ve veri güvenliği formunda doğum tarihinin işlendiğinin belirtilmesi gerekir. "Flört yok" gibi gerçeği saklayan bir beyan kabul edilmez; gerçek özellikler (§2) beyan edilir.
- 13–15 yaş **kapsam dışıdır**; asgari hedef değerlendirmesi 16+'dır.

## 4. 16–17 (teen) güvenlik açıkları — yapılmadan 16'ya geçilmez

Yalnız doğum tarihi sınırını 18 → 16 yapmak **kabul edilmeyecek** kısa yoldur. Güvenli bir 16+ modeli için gereken yaş bandı izinleri:

| Alan | Bugünkü durum | 16–17 için gerekli |
|---|---|---|
| Yetişkin ↔ reşit olmayan doğrudan mesaj | Herkes herkese mesaj isteği gönderebilir (alıcının `message_privacy` tercihi geçerli) | Reşit olmayana yetişkinden **ilk mesaj isteği yok**; yetişkin ↔ reşit olmayan DM kapalı veya yalnız karşılıklı takip + onay |
| Karşılaşma isteği | @kullanıcıadı ile herkes etiketleyebilir | Yaş bandı dışı kullanıcıya etiket isteği yok; reşit olmayan arama / etiketlenebilirlik kapalı varsayılan |
| Yakındaki İnsanlar | Opt-in, yaklaşık mesafe | Reşit olmayanlar yetişkinlere (ve tersi) **hiç gösterilmez**; reşit olmayan için varsayılan kapalı |
| Harita notu yazar kimliği | Açık notta ad / profil görünür | Reşit olmayanın notu yalnız **anonim** veya yaş bandı içinde; açık kimlik varsayılan kapalı |
| Harita notu yanıtları | Herkes yanıtlayabilir (açık / anonim) | Yetişkin → reşit olmayan notuna yanıt kapalı veya moderasyonlu |
| Konum bildirimleri (nearby / location_match) | Opt-in tercihler | Reşit olmayan için kapalı ve değiştirilemez |
| Engelleme / şikâyet | Var | Reşit olmayan raporlarına öncelikli inceleme + hızlı müdahale |
| Hesap bulunabilirliği (arama, takip önerisi) | Arama ile bulunabilir | Reşit olmayan profili yaş bandı dışına aranamaz / listelenmez |
| Ebeveyn / yaş doğrulama | Doğum tarihi beyanı | Beyan dışında doğrulama stratejisi ve yanlış beyan sürecinin kararı |

Bu liste bir **uygulama planıdır**; bu görevde gizlice teen mimarisi kurulmamıştır. Önerilen sıra: (1) `age_band` türetmesi (kullanıcı modelinde `birth_date` zaten var), (2) mesaj / karşılaşma / nearby / harita notu için bant kuralları, (3) bildirim ve görünürlük varsayılanları, (4) mağaza formları ve politika metinleri, (5) gözden geçirilmiş test paketi. Ancak bundan sonra `MINIMUM_AGE=16` yapılmalıdır.

## 5. Güncel final durumu

- Üretim minimum yaşı: **18** (değişmedi).
- Kod: tek ayarla 16'ya geçebilir (doğrulama, panel sınırı, `/app-config`, Flutter metinleri); 13–15 desteklenmez.
- **Dış bağımlılık (EXTERNAL):** genel erişilebilir destek / iletişim e-postası (Apple UGC şartı), App Store / Play Store gerçek URL'leri, operatör / yasal bilgiler. Sahte e-posta üretilmemiştir.
