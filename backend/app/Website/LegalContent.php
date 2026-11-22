<?php

namespace App\Website;

/**
 * The legal pages of the public website, written against what the app really does (accounts, birth date / age band,
 * posts, photos, messages, approximate locations, "Geçtiğim Yerler", push tokens, safety logs, AdMob).
 *
 * Operator identity is never invented: {operator_name}, {operator_address}, {operator_registration} and
 * {contact_email} are filled from the admin settings (Ayarlar → Operatör bilgileri). When a value is missing the page
 * says so openly, and the production readiness check fails until the operator has supplied them.
 */
final class LegalContent
{
    public const UPDATED = ['tr' => '15 Kasım 2026', 'en' => 'November 15, 2026'];

    /** English slug => Turkish slug (the Turkish slug is the canonical key everywhere in the code). */
    public const EN_SLUGS = [
        'privacy' => 'gizlilik', 'kvkk' => 'kvkk', 'terms' => 'kullanim-kosullari',
        'community-guidelines' => 'topluluk-kurallari',
    ];

    public static function titles(string $locale): array
    {
        return $locale === 'en'
            ? ['gizlilik' => 'Privacy Policy', 'kvkk' => 'KVKK Notice (Turkish data protection law)', 'kullanim-kosullari' => 'Terms of Use', 'topluluk-kurallari' => 'Community Guidelines']
            : ['gizlilik' => 'Gizlilik Politikası', 'kvkk' => 'KVKK Aydınlatma Metni', 'kullanim-kosullari' => 'Kullanım Koşulları', 'topluluk-kurallari' => 'Topluluk Kuralları'];
    }

    /** @return array{title:string,intro:string,sections:list<array{id:string,h:string,p?:list<string>,ul?:list<string>}>}|null */
    public static function get(string $slug, string $locale): ?array
    {
        $all = $locale === 'en' ? self::en() : self::tr();

        return $all[$slug] ?? null;
    }

    /** Plain text for the API / app (headings, paragraphs and bullet lists). */
    public static function plain(string $slug, string $locale, array $values = []): ?string
    {
        $page = self::get($slug, $locale);
        if (! $page) {
            return null;
        }
        $out = [self::fill($page['intro'], $values)];
        foreach ($page['sections'] as $section) {
            $out[] = $section['h'];
            foreach ($section['p'] ?? [] as $paragraph) {
                $out[] = self::fill($paragraph, $values);
            }
            foreach ($section['ul'] ?? [] as $item) {
                $out[] = '• '.self::fill($item, $values);
            }
        }

        return implode("\n\n", $out);
    }

    /** Replace {placeholders}; a missing value is shown as an explicit "not provided yet" marker, never as made-up data. */
    public static function fill(string $text, array $values): string
    {
        return preg_replace_callback('/\{([a-z_]+)\}/', function ($m) use ($values) {
            $value = $values[$m[1]] ?? null;

            return filled($value) ? $value : ($values['_missing'] ?? '—');
        }, $text);
    }

    private static function tr(): array
    {
        $operator = [
            'id' => 'veri-sorumlusu', 'h' => 'Veri sorumlusu',
            'p' => ['6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) kapsamında veri sorumlusu SenMiydin? uygulamasını ve bu web sitesini işleten aşağıdaki kişi / kuruluştur.'],
            'ul' => ['Unvan: {operator_name}', 'Adres: {operator_address}', 'Sicil / MERSIS no: {operator_registration}', 'İletişim: {contact_email}'],
        ];

        return [
            'kvkk' => [
                'title' => 'KVKK Aydınlatma Metni',
                'intro' => 'Bu metin, SenMiydin? hizmeti kullanılırken işlenen kişisel verileri, neden ve nasıl işlendiklerini, kimlere aktarılabileceklerini ve KVKK kapsamındaki haklarını açıklar. İçerik uygulamanın gerçek veri akışına göre hazırlanmıştır.',
                'sections' => [
                    $operator,
                    ['id' => 'islenen-veriler', 'h' => 'İşlenen kişisel veriler', 'p' => ['Aşağıdaki kategoriler, kullandığın özelliklere göre işlenir.'],
                        'ul' => [
                            'Hesap bilgileri: ad, kullanıcı adı, e-posta adresi, şifrenin tek yönlü özeti (düz şifre saklanmaz), Google / Apple ile giriş yaptıysan bu sağlayıcıların verdiği kimlik tanımlayıcısı.',
                            'Doğum tarihi ve yaş: kayıt sırasında alınır; yaş sınırını denetlemek ve 16–17 yaş ile 18+ yaş gruplarını sunucu tarafında ayırmak için kullanılır. Yaş grubu doğum tarihinden otomatik hesaplanır, elle değiştirilemez.',
                            'Profil verileri: biyografi, meslek / okul, şehir, ilgi alanları, aradığın bağlantı türleri, profil ve kapak fotoğrafı, gizlilik ve bildirim tercihleri.',
                            'Kullanıcı içerikleri: paylaşımlar, yolculuk bilgileri, yorumlar ve yanıtlar, beğeniler, kaydedilenler ve koleksiyonlar, karşılaşma etiketleri ve ortak hikâyeler, Harita Notları ve yanıtları.',
                            'Fotoğraflar: paylaşımlara, profile ve özel mesajlara eklediğin görseller. Özel mesaj fotoğrafları herkese açık olmayan depolamada tutulur.',
                            'Mesajlar: özel mesaj istekleri, mesajlar, fotoğraf, konum, hediye ve sesli mesajlar (en fazla 2 dakika), okundu bilgisi. Sesli mesaj yalnız mikrofon düğmesine basıp kaydı gönderdiğinde yüklenir; herkese açık olmayan depolamada tutulur, reklam veya başka bir amaçla kullanılmaz. Mesaj içeriği bildirim metnine yazılmaz.',
                            'Yaklaşık konum: şehir keşfi, yakındaki kişiler ve paylaşımlar için cihazının konumu sunucuya gönderilir; diğer kullanıcılara yalnızca yaklaşık mesafe / bölge gösterilir. Konum mesajları yaklaşık bir noktaya yuvarlanarak saklanır. Harita Notu veya Anı eklerken haritada kendin seçtiğin nokta olduğu gibi saklanır ve içeriğin görünürlüğü kadar kişiye gösterilir (Anılar için görünürlüğü sen belirlersin).',
                            'Geçtiğim Yerler: yalnızca sen açarsan, yolunun geçtiği yaklaşık bölgeler kısa süreyle (varsayılan 7 gün) saklanır ve sonradan o bölgede paylaşılan hikâyeleri önermek için kullanılır.',
                            'Cihaz ve bildirim bilgisi: anlık bildirim (FCM) cihaz belirteci (şifreli saklanır), platform ve uygulama sürümü, son görülme zamanı (görünürlük tercihine bağlı).',
                            'Güvenlik ve denetim kayıtları: şikâyetler, engellemeler, moderasyon işlemleri, giriş denemeleri, yönetici işlem kayıtları.',
                            'Reklam verileri: reklamlar Google AdMob ile gösterilir. Reklam kimliği, cihaz ve reklam etkileşimi bilgileri Google tarafından, senin onay tercihine ve yaş grubuna göre işlenir. SenMiydin? konum verini ve konum geçmişini reklam hedeflemede kullanmaz ve reklam isteğine eklemez.',
                        ]],
                    ['id' => 'amaclar', 'h' => 'İşleme amaçları', 'ul' => [
                        'Üyeliği oluşturmak, kimliği doğrulamak, oturumu güvende tutmak.',
                        'Şehir akışı, harita, karşılaşma, mesajlaşma ve bildirim özelliklerini sunmak.',
                        'Yaş sınırını uygulamak ve 16–17 / 18+ yaş gruplarının birbirinden ayrı tutulmasını sağlamak.',
                        'Kötüye kullanımı, taciz, sahte hesap ve spam davranışını önlemek; şikâyetleri incelemek.',
                        'Destek taleplerini yanıtlamak, hukuki yükümlülükleri yerine getirmek.',
                        'Reklam göstermek ve reklam performansını ölçmek (onay ve yaş grubu kurallarına uygun olarak).',
                    ]],
                    ['id' => 'hukuki-sebepler', 'h' => 'Hukuki sebepler', 'p' => ['Veriler KVKK m. 5 ve m. 6 kapsamında şu sebeplere dayanılarak işlenir:'], 'ul' => [
                        'Sözleşmenin kurulması ve ifası (hesap, paylaşım, mesajlaşma, bildirimler).',
                        'Hukuki yükümlülüğün yerine getirilmesi (kayıt tutma, yetkili makam talepleri).',
                        'Veri sorumlusunun meşru menfaati (güvenlik, kötüye kullanımın önlenmesi, hizmetin geliştirilmesi); temel hak ve özgürlüklerine zarar vermemek şartıyla.',
                        'Açık rıza: isteğe bağlı konum özellikleri, Geçtiğim Yerler, cihaz bildirimleri ve kişiselleştirilmiş reklam onayı. Rızanı ayarlardan istediğin zaman geri alabilirsin.',
                    ]],
                    ['id' => 'alicilar', 'h' => 'Veri alıcıları ve hizmet sağlayıcılar', 'p' => ['Veriler satılmaz. Hizmetin işletilmesi için şu gruplarla, yalnızca gerekli ölçüde paylaşılabilir:'], 'ul' => [
                        'Barındırma ve altyapı sağlayıcısı (sunucu, veritabanı, depolama, e-posta gönderimi).',
                        'Google Firebase Cloud Messaging: anlık bildirim iletimi (cihaz belirteci ve bildirim türü; mesaj içeriği değil).',
                        'Google ve Apple: yalnızca bu yöntemle giriş yaparsan kimlik doğrulaması.',
                        'Google AdMob / User Messaging Platform: reklam gösterimi ve onay yönetimi.',
                        'Yetkili kamu kurum ve kuruluşları: mevzuattan doğan zorunlu talepler.',
                    ]],
                    ['id' => 'yurt-disi', 'h' => 'Yurt dışına aktarım', 'p' => ['Google (Firebase, AdMob) ve olası yurt dışı barındırma sağlayıcıları verileri Türkiye dışındaki sunucularda işleyebilir. Aktarım, KVKK m. 9 kapsamında açık rızana, standart sözleşmelere veya mevzuatın izin verdiği diğer güvencelere dayanılarak yapılır. Aktarım yapılan ülkeler ve güvenceler sağlayıcıların güncel sözleşmelerinde yer alır.']],
                    ['id' => 'saklama', 'h' => 'Saklama süreleri', 'ul' => [
                        'Hesap ve içerik verileri: hesabın açık olduğu sürece.',
                        'Geçtiğim Yerler geçmişi: varsayılan 7 gün; özelliği kapattığında geçmiş ve eşleşmeler silinir.',
                        'Harita Notları: haritada 7 gün görünür; süresi dolan not yalnızca sahibine arşiv olarak görünür, sen silene kadar saklanır.',
                        'Cihaz bildirim belirteci: oturum kapatıldığında veya hesap silindiğinde devre dışı bırakılır / silinir.',
                        'Güvenlik ve denetim kayıtları: kötüye kullanımın incelenmesi ve hukuki yükümlülükler için gerekli süre kadar.',
                    ]],
                    ['id' => 'hesap-silme', 'h' => 'Hesap silme', 'p' => ['Hesabını uygulamadan (Profil → Ayarlar → Hesabımı Sil) veya web sitesindeki Hesap Silme sayfasından talep edebilirsin. Silme sonrasında profilin ve içeriklerin erişime kapanır; oturumların, cihazların, konum verilerin ve özel mesaj medyan temizlenir; kimlik bilgilerin anonimleştirilir. Kişisel bilgi içermeyen ilişki kayıtları ve hukuken saklanması gereken sınırlı denetim kayıtları kalabilir.']],
                    ['id' => 'haklar', 'h' => 'İlgili kişinin hakları (KVKK m. 11)', 'ul' => [
                        'Kişisel verinin işlenip işlenmediğini öğrenme ve bilgi talep etme.',
                        'İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme.',
                        'Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme.',
                        'Eksik veya yanlış işlenmişse düzeltilmesini isteme.',
                        'KVKK m. 7 kapsamında silinmesini veya yok edilmesini isteme.',
                        'Düzeltme / silme işlemlerinin aktarılan üçüncü kişilere bildirilmesini isteme.',
                        'Otomatik sistemlerle analiz sonucu aleyhine bir sonuç doğmasına itiraz etme.',
                        'Kanuna aykırı işleme nedeniyle zarara uğrarsan zararın giderilmesini talep etme.',
                    ]],
                    ['id' => 'basvuru', 'h' => 'Başvuru yöntemi', 'p' => ['Haklarına ilişkin taleplerini {contact_email} adresine e-posta ile veya web sitesindeki İletişim / Hesap Silme formları üzerinden iletebilirsin. Başvurun, niteliğine göre en geç otuz gün içinde yanıtlanır. Kimliğin doğrulanamazsa ek bilgi istenebilir. Veri Koruma Kurulu’na şikâyet hakkın saklıdır.']],
                ],
            ],
            'gizlilik' => [
                'title' => 'Gizlilik Politikası',
                'intro' => 'SenMiydin? şehir odaklı bir paylaşım ve karşılaşma uygulamasıdır. Bu politika, hangi bilgileri neden topladığımızı, nasıl koruduğumuzu ve sana hangi kontrolleri verdiğimizi sade bir dille anlatır. Türkiye’deki kullanıcılar için KVKK Aydınlatma Metni de geçerlidir.',
                'sections' => [
                    ['id' => 'topladigimiz', 'h' => 'Topladığımız bilgiler', 'ul' => [
                        'Hesap: ad, kullanıcı adı, e-posta, doğum tarihi, şifre özeti; Google / Apple ile girişte sağlayıcının kimlik tanımlayıcısı.',
                        'Profil ve içerik: biyografi, şehir, ilgi alanları, fotoğraflar, paylaşımlar, yorumlar, beğeniler, kaydedilenler, Harita Notları.',
                        'Mesajlar: metin, fotoğraf, konum, hediye ve sesli mesajlar ile okundu bilgisi.',
                        'Konum: izin verirsen yaklaşık cihaz konumu; isteğe bağlı Geçtiğim Yerler ile yaklaşık geçmiş bölgeler.',
                        'Cihaz: anlık bildirim belirteci, platform ve uygulama sürümü.',
                        'Güvenlik: şikâyetler, engellemeler, moderasyon kayıtları.',
                    ]],
                    ['id' => 'konum', 'h' => 'Konum nasıl kullanılır?', 'p' => ['Konum izni isteğe bağlıdır; vermezsen şehrini elle seçerek uygulamayı kullanabilirsin. Cihazının kesin GPS koordinatı, açık adresin ve canlı rotan diğer kullanıcılara gösterilmez; yalnızca yaklaşık mesafe veya bölge görünür. Konum mesajları yaklaşık bir noktaya yuvarlanır. Harita Notu ve Anı için ise haritada bir nokta kendin seçersin; içerik seçtiğin noktada görünür (Anılar için kimlerin göreceğini sen belirlersin). Geçtiğim Yerler varsayılan olarak kapalıdır; açarsan yaklaşık bölgeler kısa süre (varsayılan 7 gün) saklanır ve kapattığında silinir.', 'Konum verin reklam hedeflemede kullanılmaz ve reklam isteklerine eklenmez.']],
                    ['id' => 'icerik-mesaj', 'h' => 'İçerikler ve mesajlar', 'p' => ['Paylaşımlar, yorumlar ve Harita Notları şehir akışında veya haritada başkalarına görünebilir; anonim paylaşımda adın ve profilin gösterilmez. Özel mesajlar yalnızca konuşmanın tarafları tarafından görülür; ilk mesaj bir istektir. Bildirimlerde mesajın içeriği yazılmaz. Şikâyet edilen içerik moderasyon için incelenebilir.']],
                    ['id' => 'genc', 'h' => '16–17 yaş grubu', 'p' => ['SenMiydin? 16 yaş ve üzeri için sunulur. 16–17 yaşındaki hesaplar kullanıcıya dönük sosyal özelliklerde (arama, profil, takip, yakındaki kişiler, karşılaşma, mesaj, Harita Notları, yorumlar, akış) yalnızca aynı yaş grubundaki hesaplarla etkileşir; 18+ hesaplarla etkileşemez. Bu ayrım sunucuda doğum tarihinden otomatik uygulanır. Genç hesaplarda “Yakındaki İnsanlar” varsayılan olarak kapalıdır ve genç hesaplara kişiselleştirilmiş reklam gösterilmez.']],
                    ['id' => 'hizmetler', 'h' => 'Kullandığımız hizmetler', 'ul' => [
                        'Sunucu barındırma ve depolama: verilerin işlendiği ve saklandığı altyapı.',
                        'Firebase Cloud Messaging (Google): anlık bildirim iletimi.',
                        'Google ile giriş / Apple ile giriş: yalnızca seçersen kimlik doğrulama.',
                        'Google AdMob ve User Messaging Platform: reklam gösterimi ve onay yönetimi.',
                    ]],
                    ['id' => 'reklam', 'h' => 'Reklamlar', 'p' => ['Akışta “Reklam” etiketiyle ayrılmış küçük yerel reklamlar gösterilebilir. Bölgene göre gerekli olduğunda Google’ın onay formu ile reklam tercihlerini sorarız; tercihlerini Ayarlar → Reklam Gizlilik Tercihleri bölümünden değiştirebilirsin. 16–17 yaşındaki hesaplarda yaş kısıtlı reklam işleme kuralları uygulanır. Google’ın veri işleme ayrıntıları Google’ın gizlilik politikasında yer alır.']],
                    ['id' => 'guvenlik', 'h' => 'Güvenlik', 'p' => ['Şifreler tek yönlü özet olarak saklanır; cihaz belirteçleri şifrelenir; özel mesaj fotoğrafları herkese açık olmayan depolamada tutulur ve gönderilen fotoğraflardan konum gibi gizli bilgiler temizlenir. Hiçbir sistem tamamen risksizdir; bir güvenlik sorunu fark edersen bize bildir.']],
                    ['id' => 'saklama-silme', 'h' => 'Saklama ve silme', 'p' => ['Verilerini hesabın açık olduğu sürece saklarız. Hesabını uygulamadan veya web sitesinden silebilirsin; silme sonrası kimlik bilgilerin anonimleştirilir, oturum, cihaz ve konum verilerin temizlenir. Sınırlı denetim kayıtları yasal gereklilik ve güvenlik için kalabilir.']],
                    ['id' => 'haklar', 'h' => 'Haklarını kullanma', 'p' => ['Verilerine erişme, düzeltme, silme ve itiraz hakların vardır. Taleplerini {contact_email} adresine veya İletişim / Hesap Silme sayfasına iletebilirsin. Türkiye’deki kullanıcılar için KVKK, Avrupa Ekonomik Alanı’ndaki kullanıcılar için GDPR kapsamındaki haklar ayrıca geçerlidir.']],
                    ['id' => 'degisiklik', 'h' => 'Değişiklikler ve iletişim', 'p' => ['Bu politika güncellendiğinde sayfadaki tarih değişir; önemli değişiklikleri uygulama içinde de duyururuz.', 'İşleten: {operator_name} · {operator_address} · {contact_email}']],
                ],
            ],
            'kullanim-kosullari' => [
                'title' => 'Kullanım Koşulları',
                'intro' => 'SenMiydin?’i kullanarak bu koşulları kabul etmiş olursun. Koşulların tamamını okumanı, özellikle yaş sınırı, içerik ve güvenlik bölümlerine dikkat etmeni öneririz.',
                'sections' => [
                    ['id' => 'uygunluk', 'h' => 'Kimler kullanabilir?', 'p' => ['SenMiydin? 16 yaş ve üzeri için sunulur. Kayıt sırasında doğru doğum tarihini vermelisin. 16–17 yaşındaki hesaplar yalnızca 16–17 yaş grubundaki hesaplarla; 18 yaş ve üzeri hesaplar yalnızca 18+ hesaplarla etkileşebilir. Yaş grubun doğum tarihinden otomatik belirlenir; 18 yaşına geldiğinde yetişkin grubuna geçersin.']],
                    ['id' => 'hesap', 'h' => 'Hesap sorumluluğu', 'ul' => ['Hesap bilgilerini ve şifreni gizli tut; hesabında olanlardan sen sorumlusun.', 'Başkası adına hesap açma, kimliğine bürünme ve sahte hesap kullanma.', 'Bir güvenlik sorunu fark edersen hemen bize bildir.']],
                    ['id' => 'icerik', 'h' => 'İçerikler ve anonim paylaşım', 'p' => ['Paylaştığın içeriklerin sorumluluğu sana aittir; yalnızca paylaşma hakkına sahip olduğun içerikleri yükle. İçeriğini hizmeti sunmak, göstermek ve güvenliğini sağlamak için kullanmamıza izin verirsin. Anonim paylaşımda adın ve profilin diğer kullanıcılara gösterilmez; ancak yasal yükümlülükler ve kötüye kullanımın önlenmesi için sistem kayıtları tutulabilir ve anonimlik moderasyon işlemini engellemez.']],
                    ['id' => 'ozellikler', 'h' => 'Harita Notları, karşılaşmalar ve mesajlar', 'ul' => ['Harita Notları 7 gün herkese açık kalır; notunda kişisel bilgi, kesin adres veya başkasını hedef alan içerik paylaşma.', 'Karşılaşma etiketi ve ortak hikâye karşı tarafın onayına bağlıdır; reddedilen isteği zorlama.', 'Mesajlaşma birebirdir; ilk mesaj bir istektir. Alıcının isteği reddetmesine veya seni engellemesine saygı göster.', 'Konum paylaşımı yaklaşıktır; kimsenin canlı konumunu takip etmek için hizmeti kullanma.']],
                    ['id' => 'yasaklar', 'h' => 'Yasak davranışlar', 'p' => ['Topluluk Kuralları’nda sayılan taciz, tehdit, nefret söylemi, cinsel içerik, reşit olmayanlara yönelik uygunsuz davranış, kişisel bilgi ifşası, spam / dolandırıcılık, taklit ve rıza dışı görüntü paylaşımı yasaktır. Hizmeti otomatik araçlarla kötüye kullanmak, güvenlik önlemlerini aşmaya çalışmak veya yaş grubu ayrımını dolanmak da yasaktır.']],
                    ['id' => 'moderasyon', 'h' => 'Moderasyon, askıya alma ve fesih', 'p' => ['Şikâyetleri inceleriz; kurallara aykırı içerikleri kaldırabilir, hesapları sınırlayabilir, askıya alabilir veya kapatabiliriz. Ciddi ihlallerde önceden bildirim yapılmayabilir. Kararlara itiraz için İletişim sayfasını kullanabilirsin.']],
                    ['id' => 'reklam', 'h' => 'Reklamlar', 'p' => ['Hizmet, “Reklam” etiketi taşıyan reklamlarla desteklenebilir. Reklamlar üçüncü taraflarca sunulur; reklamverenlerin ürün ve hizmetlerinden SenMiydin? sorumlu değildir. Reklam tercihlerini Ayarlar’dan yönetebilirsin.']],
                    ['id' => 'fikri', 'h' => 'Fikri mülkiyet', 'p' => ['SenMiydin? adı, logosu, tasarımı ve yazılımı işletene aittir. Sana hizmeti kişisel kullanım için sınırlı, devredilemez bir kullanım hakkı veririz. Kendi içeriklerinin hakları sende kalır.']],
                    ['id' => 'hizmet', 'h' => 'Hizmetin sürekliliği ve sorumluluk', 'p' => ['Hizmeti kesintisiz ve hatasız sunmayı hedefleriz ancak bakım, güncelleme veya mücbir sebeplerle kesinti olabilir. Kullanıcıların paylaştığı içeriklerin doğruluğundan ve kullanıcılar arasındaki gerçek hayat buluşmalarından işleten sorumlu tutulamaz; buluşurken kendi güvenliğine dikkat et. Yasaların izin verdiği ölçüde sorumluluğumuz sınırlıdır.']],
                    ['id' => 'silme', 'h' => 'Hesabı kapatma', 'p' => ['Hesabını istediğin zaman uygulamadan (Profil → Ayarlar → Hesabımı Sil) veya web sitesindeki Hesap Silme sayfasından kapatabilirsin. Silinen veriler Gizlilik Politikası ve KVKK Aydınlatma Metni’nde açıklanır.']],
                    ['id' => 'degisiklik', 'h' => 'Değişiklikler, uygulanacak hukuk ve iletişim', 'p' => ['Koşullar güncellenebilir; önemli değişiklikler duyurulur. Bu koşullara Türkiye Cumhuriyeti hukuku uygulanır. İşleten: {operator_name} · {operator_address} · {contact_email}']],
                ],
            ],
            'topluluk-kurallari' => [
                'title' => 'Topluluk Kuralları',
                'intro' => 'SenMiydin?’de karşılaşmalar iki tarafın da tercihine saygıyla yaşanır. Aşağıdaki davranışlar toplulukta kabul edilmez ve moderasyon işlemine yol açar.',
                'sections' => [
                    ['id' => 'saygi', 'h' => 'Saygı ve rıza', 'p' => ['Etiketlemek, mesaj istemek veya not yazmak başkasının cevap vermek zorunda olduğu anlamına gelmez. “Hayır” ya da sessizlik bir cevaptır; ısrar etme.']],
                    ['id' => 'yasaklar', 'h' => 'Yasak davranışlar', 'ul' => [
                        'Taciz ve zorbalık: aşağılama, hakaret, sürekli istenmeyen mesaj veya etiket.',
                        'Stalking ve takip: bir kişinin yerini, rutinini veya hareketlerini izlemeye çalışmak.',
                        'Tehdit ve şiddet: zarar vermekle korkutmak veya şiddeti övmek.',
                        'Nefret söylemi: kişi ya da grupları kimlikleri nedeniyle hedef almak.',
                        'Cinsel içerik: müstehcen, çıplak veya cinsel amaçlı içerik.',
                        'Reşit olmayanlara yönelik uygunsuz davranış: 18 yaş altı kullanıcılara cinsel, istismar edici veya uygunsuz yaklaşmak. Bu durum derhal hesap kapatma ve gerektiğinde yetkili makamlara bildirim ile sonuçlanır.',
                        'Kişisel bilgi ifşası (doxxing): başkasının adres, telefon, kimlik veya özel bilgisini izinsiz paylaşmak.',
                        'Kesin konum paylaşımı: başkasının kesin konumunu, ev veya iş adresini yayımlamak.',
                        'Spam ve dolandırıcılık: toplu mesaj, sahte vaat, kimlik avı, yanıltıcı bağlantı.',
                        'Taklit: başka biri gibi davranmak, sahte hesap açmak.',
                        'Rıza dışı görüntü: kişinin izni olmadan çekilmiş veya paylaşılmış fotoğraf / video.',
                        'Harita Notu kötüye kullanımı: kişiyi hedef alan, kesin adres içeren veya taciz amaçlı notlar ve yanıtlar.',
                        'Mesaj kötüye kullanımı: istenmeyen fotoğraf, baskı, şantaj veya tehdit içeren mesajlar.',
                        'Yaş grubu ayrımını aşmaya çalışmak: yanlış doğum tarihi vermek veya farklı yaş grubundaki kişilerle iletişim kurmanın yollarını aramak.',
                    ]],
                    ['id' => 'cocuk-guvenligi', 'h' => 'Çocuk güvenliği standartları (CSAE)', 'p' => ['SenMiydin? çocukların cinsel istismarına ve sömürüsüne (CSAE) karşı sıfır tolerans uygular. Çocuk cinsel istismarı materyali (CSAM) paylaşmak, istemek, saklamak veya bağlantısını vermek; reşit olmayanları cinsel amaçla kandırmak (grooming), şantajla görüntü istemek (sextortion), reşit olmayanlarla cinsel içerikli yazışmak veya buluşma ayarlamak kesinlikle yasaktır.', 'Bu tür içerik tespit edildiğinde veya bildirildiğinde içerik derhal kaldırılır, hesap kalıcı olarak kapatılır, ilgili kayıtlar delil olarak korunur ve durum gecikmeksizin yetkili makamlara (Türkiye’de Emniyet Genel Müdürlüğü / Cumhuriyet Başsavcılığı, gerektiğinde uluslararası raporlama kuruluşları) bildirilir. 16–17 yaşındaki hesaplar yalnızca aynı yaş grubuyla etkileşebilir ve 18+ hesaplardan ayrılır.', 'Uygulama içinde her paylaşım, yorum, mesaj, Harita Notu ve profil için Şikâyet Et seçeneği vardır; çocuk güvenliği şikâyetleri öncelikli incelenir. Çocuk güvenliğiyle ilgili endişelerini ve resmi taleplerini {contact_email} adresine iletebilirsin.']],
                    ['id' => 'bildirim', 'h' => 'Şikâyet ve engelleme', 'p' => ['Uygunsuz bir paylaşım, yorum, mesaj, Harita Notu veya profil gördüğünde ⋮ menüsünden veya profilden Şikâyet Et’i seç. İstemediğin kişiyi engelleyebilirsin; engellenen kişi sana mesaj gönderemez, paylaşımlarını ve bildirimlerini görmezsin. Şikâyet edenin kimliği karşı tarafa gösterilmez.']],
                    ['id' => 'sonuclar', 'h' => 'Yaptırımlar', 'p' => ['İhlalin ağırlığına göre içerik kaldırma, uyarı, özelliklerin kısıtlanması, geçici askıya alma veya kalıcı hesap kapatma uygulanır. Yasal suç unsuru taşıyan durumlar yetkili makamlara bildirilebilir. Kararlara itiraz için {contact_email} adresine yazabilirsin.']],
                ],
            ],
        ];
    }

    private static function en(): array
    {
        $operator = [
            'id' => 'controller', 'h' => 'Data controller',
            'p' => ['The controller of personal data for the SenMiydin? app and this website under Turkish Law No. 6698 on the Protection of Personal Data (KVKK) is:'],
            'ul' => ['Name: {operator_name}', 'Address: {operator_address}', 'Registration / MERSIS no.: {operator_registration}', 'Contact: {contact_email}'],
        ];

        return [
            'kvkk' => [
                'title' => 'KVKK Notice (Turkish data protection law)',
                'intro' => 'This notice explains, in line with Turkish Law No. 6698 (KVKK), which personal data SenMiydin? processes, why and how, who may receive it and which rights you have. It describes the real data flows of the app.',
                'sections' => [
                    $operator,
                    ['id' => 'data', 'h' => 'Personal data we process', 'ul' => [
                        'Account data: name, username, email, a one-way hash of your password (the password itself is never stored), and the provider identifier if you sign in with Google or Apple.',
                        'Date of birth and age: collected at registration to enforce the age limit and to keep the 16–17 and 18+ age groups apart on the server. The age group is derived from the date of birth and cannot be changed by hand.',
                        'Profile data: bio, occupation / school, city, interests, the connections you are looking for, profile and cover photos, privacy and notification settings.',
                        'User content: posts, journey details, comments and replies, likes, saved items and collections, encounter tags and shared stories, Map Notes and their replies.',
                        'Photos you add to posts, your profile or private messages. Private message photos are kept in non-public storage.',
                        'Messages: message requests, messages, photo, location, gift and voice messages (up to 2 minutes), read receipts. A voice message is uploaded only when you tap the microphone and send the recording; it is kept in non-public storage and is never used for advertising or any other purpose. Message content is never written into notification text.',
                        'Approximate location: your device location is sent to the server for city discovery, people and posts nearby; other users only see an approximate distance or area. Location messages and Map Notes are rounded to an approximate point.',
                        'Places I Passed: only if you turn it on, approximate areas you pass are stored for a short time (7 days by default) and used to suggest stories later shared there.',
                        'Device and push data: push (FCM) device token (stored encrypted), platform and app version, last seen time (depending on your visibility setting).',
                        'Safety and audit records: reports, blocks, moderation actions, sign-in attempts, administrator action logs.',
                        'Advertising data: ads are shown through Google AdMob. Advertising ID, device and ad interaction data are processed by Google according to your consent choice and age group. SenMiydin? does not use your location or location history for ad targeting and does not add it to ad requests.',
                    ]],
                    ['id' => 'purposes', 'h' => 'Purposes of processing', 'ul' => [
                        'Creating your membership, verifying identity and keeping sessions secure.',
                        'Providing the city feed, map, encounters, messaging and notifications.',
                        'Enforcing the age limit and keeping the 16–17 and 18+ age groups separate.',
                        'Preventing abuse, harassment, fake accounts and spam; reviewing reports.',
                        'Answering support requests and meeting legal obligations.',
                        'Showing ads and measuring their performance (in line with consent and age-group rules).',
                    ]],
                    ['id' => 'legal-bases', 'h' => 'Legal bases', 'p' => ['Under KVKK articles 5 and 6, data is processed on these bases:'], 'ul' => [
                        'Establishing and performing the contract (account, posts, messaging, notifications).',
                        'Compliance with legal obligations (record keeping, requests from competent authorities).',
                        'The controller’s legitimate interests (security, abuse prevention, service improvement), as long as your fundamental rights are not harmed.',
                        'Explicit consent: optional location features, Places I Passed, device notifications and personalized ads. You can withdraw consent in the settings at any time.',
                    ]],
                    ['id' => 'recipients', 'h' => 'Recipients and service providers', 'p' => ['Data is not sold. To run the service it may be shared, only as far as necessary, with:'], 'ul' => [
                        'Hosting and infrastructure providers (servers, database, storage, email delivery).',
                        'Google Firebase Cloud Messaging: push delivery (device token and notification type, not message content).',
                        'Google and Apple: authentication, only if you choose to sign in that way.',
                        'Google AdMob / User Messaging Platform: ad delivery and consent management.',
                        'Competent public authorities when required by law.',
                    ]],
                    ['id' => 'transfers', 'h' => 'Transfers abroad', 'p' => ['Google (Firebase, AdMob) and possible foreign hosting providers may process data on servers outside Türkiye. Transfers rely on your explicit consent, standard contractual safeguards or other safeguards permitted by KVKK article 9. The countries and safeguards are set out in the providers’ current terms.']],
                    ['id' => 'retention', 'h' => 'Retention', 'ul' => [
                        'Account and content data: while your account is open.',
                        'Places I Passed history: 7 days by default; when you turn the feature off, the history and matches are deleted.',
                        'Map Notes: public on the map for 7 days; an expired note stays only in the owner’s private archive until the owner deletes it.',
                        'Push device token: deactivated on sign-out and removed when the account is deleted.',
                        'Safety and audit records: for as long as needed to review abuse and meet legal obligations.',
                    ]],
                    ['id' => 'deletion', 'h' => 'Account deletion', 'p' => ['You can delete your account in the app (Profile → Settings → Delete My Account) or request it on the website’s Delete Account page. Afterwards your profile and content are no longer accessible; sessions, devices, location data and private message media are erased; identity details are anonymized. Records that contain no personal information and a limited set of audit records that must be kept by law may remain.']],
                    ['id' => 'rights', 'h' => 'Your rights (KVKK article 11)', 'ul' => [
                        'Learn whether your data is processed and request information.',
                        'Learn the purpose of processing and whether it is used accordingly.',
                        'Know the third parties it is transferred to, in Türkiye or abroad.',
                        'Request correction of incomplete or inaccurate data.',
                        'Request erasure or destruction under KVKK article 7.',
                        'Request that corrections and erasures be notified to recipients.',
                        'Object to a result against you produced solely by automated analysis.',
                        'Claim compensation if you suffer damage from unlawful processing.',
                    ]],
                    ['id' => 'apply', 'h' => 'How to apply', 'p' => ['Send your requests to {contact_email} or use the Contact / Delete Account forms on the website. Requests are answered within thirty days at the latest, depending on their nature. We may ask for additional information to verify your identity. Your right to complain to the Personal Data Protection Board remains.']],
                ],
            ],
            'gizlilik' => [
                'title' => 'Privacy Policy',
                'intro' => 'SenMiydin? is a city-focused sharing and encounters app. This policy explains in plain language what we collect and why, how we protect it and which controls you have. For users in Türkiye the KVKK Notice also applies.',
                'sections' => [
                    ['id' => 'collect', 'h' => 'What we collect', 'ul' => [
                        'Account: name, username, email, date of birth, password hash; the provider identifier when you sign in with Google or Apple.',
                        'Profile and content: bio, city, interests, photos, posts, comments, likes, saved items, Map Notes.',
                        'Messages: text, photo, location, gift and voice messages and read receipts.',
                        'Location: approximate device location if you allow it; approximate past areas if you turn on Places I Passed.',
                        'Device: push token, platform and app version.',
                        'Safety: reports, blocks, moderation records.',
                    ]],
                    ['id' => 'location', 'h' => 'How location is used', 'p' => ['Location permission is optional; without it you can pick your city by hand. Your exact GPS coordinates, address and live route are never shown to other users, only an approximate distance or area. Map Notes and location messages are rounded to an approximate point. Places I Passed is off by default; if you turn it on, approximate areas are kept for a short time (7 days by default) and deleted when you turn it off.', 'Your location is not used for ad targeting and is not added to ad requests.']],
                    ['id' => 'content', 'h' => 'Content and messages', 'p' => ['Posts, comments and Map Notes may be visible to others in the city feed or on the map; with anonymous posting your name and profile are hidden. Private messages are visible only to the people in the conversation; the first message is a request. Notifications never contain message content. Reported content may be reviewed for moderation.']],
                    ['id' => 'teens', 'h' => 'Ages 16–17', 'p' => ['SenMiydin? is offered to people aged 16 and over. Accounts aged 16–17 interact only with other 16–17 accounts across user-facing social features (search, profiles, follows, people nearby, encounters, messages, Map Notes, comments, feeds); they cannot interact with 18+ accounts. This separation is enforced on the server from the date of birth. For teen accounts “People Nearby” is off by default and personalized ads are not shown.']],
                    ['id' => 'services', 'h' => 'Services we use', 'ul' => [
                        'Server hosting and storage: the infrastructure where data is processed and stored.',
                        'Firebase Cloud Messaging (Google): push delivery.',
                        'Sign in with Google / Apple: authentication, only if you choose it.',
                        'Google AdMob and User Messaging Platform: ad delivery and consent management.',
                    ]],
                    ['id' => 'ads', 'h' => 'Ads', 'p' => ['Small native ads, clearly labelled “Ad”, may appear in the feed. Where required in your region we ask for your ad choices through Google’s consent form; you can change them under Settings → Ad privacy choices. Age-restricted ad treatment applies to accounts aged 16–17. Google’s data processing is described in Google’s privacy policy.']],
                    ['id' => 'security', 'h' => 'Security', 'p' => ['Passwords are stored as one-way hashes; device tokens are encrypted; private message photos are kept in non-public storage and hidden data such as location is stripped from photos you send. No system is entirely risk-free; if you notice a security problem, please tell us.']],
                    ['id' => 'retention', 'h' => 'Retention and deletion', 'p' => ['We keep your data while your account is open. You can delete your account in the app or on the website; afterwards identity details are anonymized and sessions, devices and location data are erased. A limited set of audit records may remain for legal and security reasons.']],
                    ['id' => 'rights', 'h' => 'Your rights', 'p' => ['You can access, correct, delete and object to the use of your data. Send requests to {contact_email} or use the Contact / Delete Account pages. Rights under KVKK (Türkiye) and GDPR (European Economic Area) apply where relevant.']],
                    ['id' => 'changes', 'h' => 'Changes and contact', 'p' => ['When this policy is updated the date on this page changes; important changes are also announced in the app.', 'Operator: {operator_name} · {operator_address} · {contact_email}']],
                ],
            ],
            'kullanim-kosullari' => [
                'title' => 'Terms of Use',
                'intro' => 'By using SenMiydin? you accept these terms. Please read them in full, especially the sections on age, content and safety.',
                'sections' => [
                    ['id' => 'eligibility', 'h' => 'Who can use SenMiydin?', 'p' => ['SenMiydin? is offered to people aged 16 and over. You must give your real date of birth when you register. Accounts aged 16–17 can interact only with accounts aged 16–17; accounts aged 18 and over only with 18+ accounts. Your age group is derived from your date of birth automatically; when you turn 18 you move to the adult group.']],
                    ['id' => 'account', 'h' => 'Account responsibility', 'ul' => ['Keep your account details and password secret; you are responsible for what happens on your account.', 'Do not open accounts in someone else’s name, impersonate people or use fake accounts.', 'If you notice a security problem, tell us right away.']],
                    ['id' => 'content', 'h' => 'Content and anonymous posts', 'p' => ['You are responsible for what you post; upload only content you have the right to share. You allow us to use your content to provide, display and secure the service. With anonymous posting your name and profile are hidden from other users, but system records may be kept for legal obligations and abuse prevention, and anonymity does not prevent moderation.']],
                    ['id' => 'features', 'h' => 'Map Notes, encounters and messages', 'ul' => ['Map Notes are public for 7 days; do not post personal details, exact addresses or content that targets someone.', 'Encounter tags and shared stories depend on the other person’s approval; do not push after a decline.', 'Messaging is one-to-one; the first message is a request. Respect a decline or a block.', 'Location sharing is approximate; do not use the service to track anyone’s live location.']],
                    ['id' => 'prohibited', 'h' => 'Prohibited behavior', 'p' => ['Harassment, threats, hate speech, sexual content, inappropriate behavior toward minors, disclosure of personal information, spam / scams, impersonation and non-consensual imagery as listed in the Community Guidelines are prohibited. So is abusing the service with automated tools, trying to bypass security measures or circumventing the age-group separation.']],
                    ['id' => 'moderation', 'h' => 'Moderation, suspension and termination', 'p' => ['We review reports and may remove content, restrict, suspend or close accounts that break the rules. For serious violations no prior notice may be given. You can contest decisions through the Contact page.']],
                    ['id' => 'ads', 'h' => 'Advertising', 'p' => ['The service may be supported by ads labelled “Ad”. Ads are served by third parties; SenMiydin? is not responsible for advertisers’ products or services. You can manage ad choices in Settings.']],
                    ['id' => 'ip', 'h' => 'Intellectual property', 'p' => ['The SenMiydin? name, logo, design and software belong to the operator. We give you a limited, non-transferable right to use the service for personal purposes. You keep the rights to your own content.']],
                    ['id' => 'availability', 'h' => 'Availability and liability', 'p' => ['We aim for an uninterrupted, error-free service but maintenance, updates or force majeure may cause interruptions. The operator cannot be held responsible for the accuracy of content users share or for real-life meetings between users; look after your own safety when meeting someone. Our liability is limited to the extent permitted by law.']],
                    ['id' => 'deletion', 'h' => 'Closing your account', 'p' => ['You can close your account at any time in the app (Profile → Settings → Delete My Account) or on the website’s Delete Account page. What is deleted is described in the Privacy Policy and the KVKK Notice.']],
                    ['id' => 'changes', 'h' => 'Changes, governing law and contact', 'p' => ['These terms may be updated; important changes are announced. The laws of the Republic of Türkiye apply. Operator: {operator_name} · {operator_address} · {contact_email}']],
                ],
            ],
            'topluluk-kurallari' => [
                'title' => 'Community Guidelines',
                'intro' => 'Encounters on SenMiydin? happen with respect for both people’s choices. The behaviors below are not accepted and lead to moderation.',
                'sections' => [
                    ['id' => 'respect', 'h' => 'Respect and consent', 'p' => ['Tagging someone, requesting a message or leaving a note does not oblige anyone to answer. “No” or silence is an answer; do not insist.']],
                    ['id' => 'prohibited', 'h' => 'Prohibited behavior', 'ul' => [
                        'Harassment and bullying: insults, humiliation, repeated unwanted messages or tags.',
                        'Stalking: trying to follow someone’s location, routine or movements.',
                        'Threats and violence: threatening harm or glorifying violence.',
                        'Hate speech: targeting people or groups for who they are.',
                        'Sexual content: obscene, nude or sexually explicit content.',
                        'Inappropriate behavior toward minors: approaching under-18 users sexually, abusively or inappropriately. This leads to immediate account closure and, where needed, a report to the authorities.',
                        'Doxxing: sharing someone’s address, phone number, ID or private information without permission.',
                        'Sharing exact location: publishing someone’s exact location or home / work address.',
                        'Spam and scams: bulk messages, false promises, phishing, misleading links.',
                        'Impersonation: pretending to be someone else or running fake accounts.',
                        'Non-consensual imagery: photos or videos taken or shared without the person’s consent.',
                        'Map Note abuse: notes and replies that target a person, contain an exact address or aim to harass.',
                        'Message abuse: unwanted photos, pressure, blackmail or threatening messages.',
                        'Bypassing the age-group separation: giving a false date of birth or looking for ways to contact people in the other age group.',
                    ]],
                    ['id' => 'child-safety', 'h' => 'Child safety standards (CSAE)', 'p' => ['SenMiydin? has zero tolerance for child sexual abuse and exploitation (CSAE). Sharing, requesting, storing or linking to child sexual abuse material (CSAM), grooming minors, sextortion, sexual conversations with minors or arranging to meet them are strictly prohibited.', 'When such content is detected or reported, it is removed immediately, the account is permanently closed, the relevant records are preserved as evidence and the case is reported without delay to the competent authorities (in Türkiye the General Directorate of Security / Public Prosecutor, and international reporting organizations where applicable). Accounts aged 16–17 can only interact with the same age group and are separated from 18+ accounts.', 'Every post, comment, message, Map Note and profile has a Report option in the app; child-safety reports are reviewed with priority. Send child-safety concerns and official requests to {contact_email}.']],
                    ['id' => 'reporting', 'h' => 'Reporting and blocking', 'p' => ['If you see an inappropriate post, comment, message, Map Note or profile, choose Report from the ⋮ menu or the profile. You can block anyone you do not want to hear from: a blocked person cannot message you and you will not see their posts or notifications. The identity of the person who reports is not shown to the other side.']],
                    ['id' => 'consequences', 'h' => 'Consequences', 'p' => ['Depending on severity we remove content, warn, restrict features, suspend temporarily or close the account permanently. Situations that involve a crime may be reported to the authorities. To contest a decision write to {contact_email}.']],
                ],
            ],
        ];
    }
}
