<?php

namespace App\Website;

use Illuminate\Support\Facades\DB;

final class Pages
{
    public const LEGAL = [
        'gizlilik' => ['Gizlilik Politikası', "SenMiydin? hesap, profil ve topluluk özellikleri için paylaştığın bilgileri işler. Bunlar hesap bilgileri, gönderiler, etkileşimler ve özel mesajlar gibi kullanım sırasında oluşan verileri kapsar.\n\nKonuma izin verdiğinde, uygulama keşif için konum verisini kullanır. Diğer kullanıcılara kesin GPS koordinatların yerine yaklaşık mesafe veya konum bilgisi gösterilir. Konum geçmişi ve görünürlük tercihlerini uygulama ayarlarından yönetebilirsin.\n\nVerilerinle ilgili talebini İletişim veya Hesap Silme sayfasından iletebilirsin."],
        'kvkk' => ['KVKK Aydınlatma', "Bu sayfada SenMiydin? hizmetinde kullanılan veri kategorileri açıklanır. Hesap ve profil verileri üyelik için, gönderi ve etkileşim verileri topluluk özellikleri için, güvenlik kayıtları ise kötüye kullanımın incelenmesi için kullanılır. Konum ve cihaz bildirimleri uygulamadaki izin ve tercihlerine bağlıdır.\n\nKişisel verilerine ilişkin bilgi alma, düzeltme ve silme taleplerini destek kanalı üzerinden iletebilirsin. Veri sorumlusunun kimliği, hukuki sebepler, aktarım yapılan alıcı grupları ve başvuru usulü hizmetin yayın ortamına ait bilgilerle tamamlanır."],
        'kullanim-kosullari' => ['Kullanım Koşulları', "SenMiydin? şehir içindeki paylaşımları ve gerçek hayattaki karşılaşmaları keşfetmek için tasarlanmıştır. Hesabının güvenliğini koru ve sadece paylaşma hakkına sahip olduğun içerikleri yükle.\n\nBaşkalarının kişisel bilgilerini izinsiz paylaşma. Taciz, tehdit, sahte hesap ve istenmeyen toplu mesajlar moderasyon işlemine neden olabilir. Topluluk Kuralları, uygulamadaki etkileşimlerin sınırlarını açıklar."],
        'topluluk-kurallari' => ['Topluluk Kuralları', "Karşılaşmalar iki tarafın da tercihine saygı gösterilerek paylaşılır. Etiketleme ve mesaj isteğine yanıt vermek herkesin kendi kararıdır.\n\nTaciz, tehdit, nefret söylemi, taklit ve spam toplulukta kabul edilmez. Bir başkasının kesin konumunu, iletişim bilgilerini veya özel konuşmasını izinsiz paylaşma.\n\nUygunsuz bir durumla karşılaşırsan uygulamadaki şikâyet ve engelleme seçeneklerini kullan."],
    ];

    public const PUBLIC = [
        '' => ['SenMiydin?', 'Birini gördün ama konuşamadın mı? Şehrinde karşılaştığın insanları yeniden bul, yolculuk anılarını paylaş ve geçtiğiniz yere 7 gün kalan dijital bir mektup bırak.'],
        'nasil-calisir' => ['Nasıl Çalışır?', 'Bir an bırak, karşılaştığın kişiyi bul ve birlikte doğrula.'],
        'ozellikler' => ['Özellikler', 'Şehir akışı, yolculuk paylaşımları, yakınlıkla keşif, karşılaşma hikâyeleri ve özel mesajlar.'],
        'guvenlik' => ['Güvenlik', 'Konum görünürlüğünü, mesaj isteklerini ve etkileşimlerini yönet.'],
        'iletisim' => ['İletişim', 'SenMiydin? hakkında destek talebi veya geri bildirim gönder.'],
        'hesap-silme' => ['Hesap Silme', 'SenMiydin? hesabın ve ilişkili kişisel verilerin için silme talebi oluştur.'],
    ];

    public const STEPS = [
        ['Bir an bırak', 'Şehrinde veya yolculukta aklında kalan bir karşılaşmayı, anıyı, düşünceyi ya da itirafı yaz. İstersen fotoğraf ekle.'],
        ['Yakınındakileri keşfet', 'Şehir içeriklerine göz at veya yaklaşık mesafeye göre konum temelli sosyal keşif yap.'],
        ['Karşılaştığın kişiyi bul', 'Yarım kalan bir karşılaşmada kullanıcı adını biliyorsan kişiyi etiketle veya aynı güzergâhtaki izleri keşfet.'],
        ['Birlikte doğrulayın', 'Karşılaşma, diğer kişi kabul ettiğinde doğrulanır. Ortak hikâye için ayrıca yayın onayı gerekir.'],
    ];

    public const FEATURES = [
        ['Şehir içerikleri ve akış', 'Düşünce, anı, itiraf ve fotoğraflı paylaşımlar yaşadığın şehrin akışında bir araya gelir.'],
        ['Yolculuk paylaşımları', 'Otobüs, tren, uçak veya feribot yolculuklarında aynı güzergâh ve seferdeki yarım kalan karşılaşmaları paylaş.'],
        ['Harita Notları', 'Haritada yaklaşık bir noktaya 7 gün kalan dijital bir mektup bırak. Açık ya da anonim olabilir; başkaları okuyabilir ve cevap yazabilir.'],
        ['Gerçek hayattaki karşılaşmalar', 'Karşılıklı onaydan sonra doğrulanan karşılaşmaları ortak bir hikâyeye dönüştürebilirsiniz.'],
        ['Konum temelli sosyal keşif', 'Yakındaki paylaşımları ve görünürlük tercihi açık profilleri canlı kişi takibi olmadan, yaklaşık mesafeyle keşfet.'],
        ['Anılar', 'Profilinde kendi seçtiğin anılardan bir koleksiyon oluştur: yer, tarih ve fotoğraf ekle, kimin göreceğine sen karar ver. Yakındaki Anılar haritada ve ana sayfada.'],
        ['Özel mesajlar', 'İlk mesaj bir istektir. Alıcı kabul ettiğinde sohbet devam eder; mesajı kendin için ya da gönderdiysen herkesten silebilir, balon renklerini ve sohbet arka planını Sohbet Teması ile değiştirebilirsin.'],
        ['Gizlilik kontrolleri', 'Konum görünürlüğünü, geçtiğin yerler tercihini ve mesaj izinlerini yönet. Gerektiğinde engelle veya şikâyet et.'],
    ];

    /**
     * Legal texts for the website fallback and the app API. A page the administrator edited keeps that text; otherwise
     * the structured, localized content (see LegalContent) is returned as plain text.
     */
    public function legal(): array
    {
        $saved = DB::table('legal_pages')->get()->keyBy('slug');
        $locale = app()->getLocale() === 'en' ? 'en' : 'tr';
        $values = Site::operatorValues(app(\App\Administration\Settings::class)->all(), $locale);

        return collect(self::LEGAL)->map(function ($default, $slug) use ($saved, $locale, $values) {
            $custom = $saved->get($slug);
            if ($custom && $locale === 'tr') {
                return ['title' => $custom->title, 'body' => $custom->body];
            }
            $page = LegalContent::get($slug, $locale);

            return [
                'title' => $page['title'] ?? $default[0],
                'body' => LegalContent::plain($slug, $locale, $values) ?? $default[1],
            ];
        })->all();
    }
}
