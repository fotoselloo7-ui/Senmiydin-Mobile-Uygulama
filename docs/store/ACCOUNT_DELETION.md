# Hesap silme — mağaza incelemesi

Denetim: 9 Kasım 2026. Gerçek mobil yol **Profil → Ayarlar → Hesabımı Sil**. “Hesabın” bir bölüm başlığıdır; ayrı “Hesap” ekranı varmış gibi tarif edilmez. SettingsRow /delete-account rotasını açar.

## Gerçek doğrulama

Ekran mevcut parolayı ister. Kullanıcı tam **SİL** yazar; buton bu onay olmadan etkinleşmez. Sunucuda DELETE /api/v1/auth/account aktif bearer token, rate limit, password doğrulaması ve confirmation=in:SİL uygular. İşlem başarılıysa AppStore oturumu temizler ve uygulama giriş durumuna döner. Sosyal kayıt akışı da hesap silme için yedek parola ister; parola unutulduysa gerçek SMTP’li sıfırlama kullanılmalıdır. Canlı SMTP ve sosyal providerlar henüz doğrulanmış sayılmaz.

## Public web yolu

GET /hesap-silme route’u mevcut ve auth olmadan okunur. POST aynı yol ad/e-posta ve isteğe bağlı mesajla web_requests type=deletion oluşturur; support mail varsa yalnız talep kimliği/bağlantılı bildirim kuyruklanır. **Form doğrudan hesap silmez.** Destek, sahipliği doğrulayarak talebi sonuçlandırmalıdır. İşletme sorumlusu, erişilebilir gerçek e-posta ve yanıt/saklama süresi [GERÇEK BİLGİ GEREKLİ].

Google formuna verilecek gerçek HTTPS adresi [GERÇEK BİLGİ GEREKLİ]; hedef path /hesap-silme. Yerel localhost veya doğrulanmamış proje domain’i mağaza URL’si olarak kopyalanmaz.

## EraseAccount işlemi

| Veri | Kodun yaptığı |
|---|---|
| Profil adı/username/email/password/DOB/şehir | Anonim değerlerle değiştirilir; account_status=deleted ve erased_at konur; ad “Silinmiş hesap” |
| Bio/meslek/okul/avatar/kapak/bağlantı/tercihler | Boşaltılır; görünürlük ve history kapatılır, aktif şehir temizlenir |
| Auth ve recovery | Bütün Sanctum tokenları, user_devices ve kullanıcıya ait password_reset_tokens silinir |
| Gönderiler | Metin/story başlığı/koordinat/olay saati/yer/content hash/featured bilgisi temizlenir, private ve soft deleted olur |
| Post media / Yolculuk metadata | İlişki satırları silinir; dosyalar outbox’a alınır |
| Kullanıcının yorumları | Gövde/hash boşaltılır, soft delete |
| Kullanıcının mesajları | Gövde ve image_path temizlenir, deleted_at; dosya outbox |
| Karşılaşma/sohbet | İlgili encounter_requests soft delete; conversations cancelled; onay/erişim akışı kapanır |
| Aktif/geçmiş konum ve eşleşme | Kullanıcıya ait satırlar ve kendi postlarına ait matches silinir |
| İlgi/beğeni/kayıt/takip/engel/notification/participant | İlgili kişisel ilişkiler silinir |
| Şikâyet | Kendi report açıklaması null; rapor hedefi/durumu/ilişki kimlikleri kalabilir |
| Sosyal provider bağı | social_identities kaldırılır; Apple şifreli refresh tokenı revocation outbox’a aktarılır |
| Medya fiziksel silme | media_deletions + database job/scheduler tekrar dener; erişim DB referansı kaldırılınca kapanır |
| Yerel uygulama / SDK kimlikleri | Oturum tokenı client’ta temizlenir. Push app-özel UUID/Firebase installation yaşam döngüsü ayrı olabilir; bütün SDK installation verilerinin anında silindiği iddia edilmez |

## Kalan kayıtlar ve süreler

Anonim users/post/comment/message/encounter/conversation ilişki kimlikleri FK bütünlüğü için kalabilir. Başka kullanıcıların kendi mesajları ve içerikleri, sınırlı admin audit/notları, report hedef/durumları topluca silinmez. Bu kalıntılar hukuken otomatik “tam anonim” kabul edilmez; gerçek yeniden ilişkilendirme riski ve işletme retention politikası değerlendirilmelidir.

Normal, moderasyonda tutulmayan soft-deleted postlar mevcut posts:purge-deleted işiyle 30 gün sonra fiziksel temizlenir. Hesap silmede kişisel post/yorum/mesaj gövdesi zaten hemen boşaltılır. Medya temizliği worker veya 10 dakikalık scheduler tarafından denenir; altyapı başarısızsa gecikebilir. Apple yetki iptali yalnız gerçek provider kurulumu ve çalışan kuyrukla tamamlanır. Destek talepleri, loglar, audit, report metadata ve yedekler için gerçek süreler **[GERÇEK BİLGİ GEREKLİ]**. “Her veri anında silinir” beyanı kullanılmaz.

Geçtiğim Yerler ayrıca kapatıldığında history/matches silinir; saatlik görev varsayılan 7 günlük geçmiş/eşleşmeyi ve bir günden eski aktif konum kayıtlarını temizler. Mobil history tercih kapama ve tüm hesap silme farklı işlemlerdir.

Kanıt: lib/screens/settings.dart; AppStore::eraseAccount; AccountDeletionController; Accounts/EraseAccount; Accounts/MediaCleanup; Jobs/CleanErasedMedia; routes/console.php; WebsiteController::submit; routes/web.php. Mevcut AccountDeletionTest ve disposable Pixel hesap silme senaryosu önceki 103/59/9 doğrulama kapsamındadır.

Kaynaklar: [Google hesap silme gereksinimleri](https://support.google.com/googleplay/android-developer/answer/13327111), [Apple uygulamada hesap silme](https://developer.apple.com/support/offering-account-deletion-in-your-app/).
