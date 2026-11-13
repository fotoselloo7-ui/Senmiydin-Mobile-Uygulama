# UGC ve moderasyon incelemesi

Denetim: 9 Kasım 2026. “Var” ifadeleri aşağıdaki kod yollarıyla sınırlıdır; insan ekibinin yanıt süresi veya canlı operasyon bu koddan kanıtlanamaz.

| Kontrol | Gerçek davranış / kanıt | Durum |
|---|---|---|
| Koşulları kabul | AuthController::register accepted_terms=accepted zorunlu; minimum yaş ayardan uygulanır | Var; metin sürümü/zamanının ayrı kabul geçmişi tutulduğu iddia edilmez |
| Kullanıcı/content report | SafetyController::report user/post/comment/message/encounter_story/system; target visibility ve ownership kontrolü | Var; yorum/gönderi/mesaj/profile arayüzleri mevcut |
| Sebepler | harassment/spam/fake/inappropriate/hate/privacy/other; other için açıklama zorunlu | Var; özel bir “CSAE” sebebi varmış gibi yazılmaz |
| Block | user_blocks; karşılıklı takip temizleme, pending mesaj/encounter iptal, görünürlük/iletişim filtresi | Var; engellenenler ayarlardan yönetilir |
| Post/comment moderation | Admin remove/restore; moderated_at ve soft delete; medya erişimi kesilir | Var |
| Message report context | Admin report detail yalnız şikâyetin hedef mesajını/ilgili kimlikleri getirir; metin ve görsel inceleme audit kaydı üretir | Var; tüm özel sohbetlerin serbest global tarayıcısı veya çevre mesaj penceresi iddiası yok |
| Message kaldırma | Şikâyet üzerinden remove → moderated_at; ConversationController visibleMessages filtreler | Var |
| Anonim gönderi sahibi | Public resource author=null olabilir; admin Post::with(author) gerçek user_id’yi görür | Var; backend anonimleşmiş toplama değildir |
| Spam prevention | API rate limits; posts/comments normalize hash ve zaman penceresi tekrar sınırları | Var |
| Kelime filtresi | ContentGuard operator moderation_banned_words listesini post/comment üzerinde uygular | Mekanizma var; denetlenen yerelde liste BOŞ |
| URL filtresi | Link sayısı, configured domain/subdomain engeli | Mekanizma var; engellenen domain listesi yerelde BOŞ, link sınırı mevcut |
| Mention abuse | Configured maksimum mention sayısı | Var |
| Görsel güvenliği | MIME/uzantı/boyut/decode; JPEG re-encode/EXIF temizliği | Var; cinsel/şiddet/CSAM içerik sınıflandırıcısı değildir |
| Admin audit | İşlem, admin ID, hedef, sınırlı not/metadata, IP ve zaman | Var; Audit::record |
| Suspension / ban | suspended/banned; token iptali, device deactivation, aktif konum temizleme; ActiveAccount erişim kontrolü | Var |
| Silinen hesabı geri açma | erased_at/account_status deleted kontrolü | Reddedilir |
| Moderasyon SLA / 7/24 ekip / otomatik acil eskalasyon | Kodla kanıtlanmaz | [GERÇEK BİLGİ GEREKLİ] |
| Yayınlanmış gerçek destek | support_email şu an boş; legal içerikler taslak/default | MISSING |

Mesaj gövdeleri normal server DB içeriğidir; uçtan uca şifreleme yoktur. Normal kullanıcı yalnız yetkili olduğu sohbeti görür. Şikâyet içeriğini yetkili moderatör görebilir. Moderasyon erişimi privacy metninde açıklanmalıdır.

## Çocuk güvenliği — Social kategorisi için açık eksik

Google’ın Social uygulama standardı yetişkin yaş kapısı olsa da uygulanır. Mevcut kayıt alt sınırı 18’dir; bu tek başına muafiyet değildir. Topluluk varsayılan metni taciz/nefret/spam/mahremiyet maddeleri içerir fakat açık CSAE standardı ve gerçek çocuk güvenliği iletişim kişisi yoktur. Şu an **MISSING**.

Mevcut report/block mekanizması kullanılabilir; “özel CSAM otomatik tespit/raporlama sistemi var” denmez. İşletmeci aşağıdaki politika ekini hukuk/operasyonla onaylayıp mevcut Topluluk Kuralları CMS’sinde yayımlayabilir; bu taslak uygulamanın mevcut yayımlanmış kuralı olarak sunulmaz:

> SenMiydin?’de çocukların cinsel istismarı ve sömürüsü (CSAE), çocukların cinsel amaçla hedef alınması, grooming, cinsel şantaj ve çocukların cinsel istismarını gösteren materyaller (CSAM) yasaktır. Bu içerik ve davranışlar uygulamadaki şikâyet mekanizması üzerinden bildirilebilir. Doğrulanan ihlallerde içerik kaldırılır ve hesaplara yaptırım uygulanır. İlgili yetkili kuruma bildirim, uygulanacak hukuk ve doğrulanmış işletme prosedürüne göre yürütülür.

Gerçek yayın öncesi: kamuya açık standardın HTTPS URL’si, güvenlik temas kişisi/e-posta, ihbar değerlendirme ve yetkili kuruma bildirim prosedürü, sorumlu ekip ve yanıt süresi **[GERÇEK BİLGİ GEREKLİ]**. Bu dosya yasaya uygun fiilî operasyonun yerine geçmez.

## İnceleme sınırı / yayın kontrolü

Apple UGC incelemesindeki filtreleme, report, block ve yayımlanmış iletişim gereksinimleri mekanizma + gerçek işletme yapılandırması olarak birlikte değerlendirilmelidir. Boş moderasyon listeleri ve gerçek destek yokken “tam policy-ready” işaretlenmez. Bu tur büyük yeni moderasyon sistemi, otomatik görsel sınıflandırıcı veya yeni ürün ekranı geliştirilmedi. Operatör mevcut admin ayarlarından gerçek listeleri/güvenlik süreçlerini tamamlar.

Kanıt: backend/app/Safety/ContentGuard.php; Http/Controllers/SafetyController.php; Admin/ModerationController.php; Admin/RecordsController.php; Administration/Audit.php; Policies; Providers/AppServiceProvider.php; Website/Pages.php; lib/screens/direct_chat.dart; widgets/social.dart.

Kaynaklar: [Apple 1.2 UGC](https://developer.apple.com/app-store/review/guidelines/#user-generated-content), [Google Social çocuk güvenliği](https://support.google.com/googleplay/android-developer/answer/14747720?hl=en).
