<?php

namespace Tests\Feature;

use App\Models\Admin;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class WebsiteTest extends TestCase
{
    use RefreshDatabase;

    public function test_public_home_has_metadata_and_unconfigured_stores_remain_placeholders(): void
    {
        $this->get('/')->assertOk()->assertSee('Bazı karşılaşmalar')->assertSee('Nasıl çalıştığını keşfet')
            ->assertSee('Yolculuk Paylaşımları')->assertSee('Canlı kişi takibi yoktur')
            ->assertSee('Google Play')->assertSee('App Store')->assertSee('Temsili paylaşım')
            ->assertSee('name="description"', false)->assertSee('rel="canonical" href="https://senmiydin.tr/"', false)
            ->assertSee('property="og:image"', false)->assertSee('name="twitter:card"', false)
            ->assertSee('SoftwareApplication')->assertDontSee('aggregateRating')->assertDontSee('downloadUrl');
    }

    public function test_public_home_follows_the_final_story_flow_without_dating_copy_or_invented_proof(): void
    {
        $html = $this->get('/')->assertOk()->getContent();
        // Final story flow: hero, what, how, city, encounters, map, map notes, past places, journey, messages, safety, screens, CTA.
        $order = ['data-slider', 'id="nedir"', 'id="nasil-calisir"', 'id="sehir-akisi"', 'id="karsilasma"', 'id="harita"', 'id="harita-notlari"',
            'id="gectigim-yerler"', 'id="yolculuk"', 'id="anilar"', 'id="mesajlasma"', 'id="guvenlik"', 'id="ekranlar"', 'id="indir"', 'site-footer'];
        $previous = -1;
        foreach ($order as $marker) {
            $position = strpos($html, $marker);
            $this->assertNotFalse($position, "Missing {$marker}");
            $this->assertGreaterThan($previous, $position, "{$marker} is out of order");
            $previous = $position;
        }
        $this->assertGreaterThanOrEqual(5, substr_count($html, 'class="hs-slide'));
        $this->assertStringContainsString('Pamukkale · Ankara → Erzincan · 07 NM 365', $html);
        $this->assertStringContainsString('class="nav-toggle"', $html);
        foreach (['flört uygulaması değildir', 'Yakında · App Store', 'Yakında · Google Play'] as $expected) {
            $this->assertStringContainsString($expected, $html);
        }
        foreach (['aggregateRating', 'ratingValue', '100K', '50K', '4.9 ★', '★', 'yorum yapan', 'instagram.com', 'tiktok.com', 'youtube.com', 'eşleşme algoritma', 'swipe', 'Premium', 'flörtleş'] as $forbidden) {
            $this->assertStringNotContainsStringIgnoringCase($forbidden, $html, "Invented or off-product copy: {$forbidden}");
        }
    }

    public function test_home_tells_the_map_notes_story_as_its_own_section_and_accurately(): void
    {
        $html = $this->get('/')->assertOk()->getContent();
        $start = strpos($html, 'id="harita-notlari"');
        $end = strpos($html, 'id="gectigim-yerler"');
        $this->assertNotFalse($start);
        $this->assertGreaterThan($start, $end);
        $section = substr($html, $start, $end - $start);

        foreach (['Birini bulamadıysan, geçtiğiniz yere bir not bırak', 'dijital bir mektup', 'açık, istersen anonim', 'Cevaplanabilir',
            'Bir noktaya mektup bırak', 'O bölgedeki insanlar notu keşfetsin', 'Belki o kişi cevap versin',
            '@kullanıcıadı ile onaylanan karşılaşmadan ayrıdır'] as $expected) {
            $this->assertStringContainsString($expected, $section, "Map notes section lacks: {$expected}");
        }
        // The visible lifetime matches the product rule (config), not an invented number.
        $days = (int) config('map_notes.ttl_days');
        $this->assertSame(7, $days);
        $this->assertStringContainsString("{$days} gün", $section);
        $this->assertDoesNotMatchRegularExpression('/\b(14|30|90) gün/u', $section);
        // Real app screens only: the map-note screens exist on disk and are used by the section.
        foreach (['app-notes-map', 'app-notes-compose', 'app-notes-list', 'app-notes-replies'] as $screen) {
            $this->assertStringContainsString("web/screens/{$screen}.webp", $section);
            $this->assertFileExists(public_path("web/screens/{$screen}.webp"));
        }
        // The hero story is built on the real feature: a letter, the notification and the reply.
        $this->assertStringContainsString('Çok güzeldin kırmızı başlıklı kız', $html);
        $this->assertStringContainsString('Notuna bir cevap geldi.', $html);
        $this->assertStringContainsString('web/screens/story-letter-reply.webp', $html);
        $this->assertStringContainsString('Gerçek uygulama ekranı', $html);
        // Never presented as exact GPS or live tracking.
        $this->assertStringNotContainsString('kesin konum', mb_strtolower($section));
        $this->assertStringContainsString('Yaklaşık nokta', $section);
    }

    public function test_home_keeps_encounters_map_notes_and_past_places_apart_without_dating_copy_or_fake_proof(): void
    {
        $html = $this->get('/')->assertOk()->getContent();
        $text = mb_strtolower(strip_tags($html));
        foreach (['eşleşme', 'eşleşir', 'match', 'sevgili', 'randevu', 'flörtleş', 'tanışma uygulaması', 'swipe', 'premium', 'beğeni sayısı'] as $banned) {
            $this->assertStringNotContainsString($banned, $text, "Dating-style copy: {$banned}");
        }
        foreach (['yıldız', 'testimonial', 'basında', 'kullanıcı memnuniyeti', 'indirme sayısı', 'milyon'] as $fake) {
            $this->assertStringNotContainsString($fake, $text, "Invented proof: {$fake}");
        }
        $this->assertDoesNotMatchRegularExpression('/\d+(?:[.,]\d+)?\s?(?:k|b|bin|m)\+/iu', $text, 'Invented numbers such as 100K+');
        $this->assertDoesNotMatchRegularExpression('/\b4[.,][0-9]\b/u', $text);
        // Past places: opt-in, default off, approximate, 7 days, not exact route tracking.
        $from = strpos($html, 'id="gectigim-yerler"');
        $places = substr($html, $from, strpos($html, 'id="yolculuk"') - $from);
        foreach (['isteğe bağlı', 'Kapalı', 'Yaklaşık bölgeler', 'En fazla 7 gün', 'Kesin rota takibi', 'Yok'] as $expected) {
            $this->assertStringContainsString($expected, $places);
        }
        // Journeys never claim the system knows you share a vehicle.
        $this->assertStringContainsString('sistem aynı araçta bulunduğunuzu bilmez', $html);
        // City flow is the main model; no "only people within 500 m" framing.
        $this->assertStringContainsString('yalnızca çevrendeki insanları gösteren bir uygulama değildir', $html);
        $this->assertStringNotContainsString('500 metre', $html);
        // Messaging stays plain: no group chat or call promise, only the explicit absence.
        $this->assertStringContainsString('Grup sohbeti ve arama yoktur', $html);
        // No unverifiable security claims.
        foreach (['uçtan uca', 'banka seviyesi', 'bank-level', 'askeri', '256'] as $claim) {
            $this->assertStringNotContainsStringIgnoringCase($claim, $html);
        }
    }

    public function test_home_has_sane_headings_labels_images_and_working_internal_anchors(): void
    {
        $html = $this->get('/')->assertOk()->getContent();
        $document = new \DOMDocument();
        libxml_use_internal_errors(true);
        $document->loadHTML('<?xml encoding="utf-8"?>'.$html);
        libxml_clear_errors();
        $xpath = new \DOMXPath($document);

        $this->assertSame(1, $xpath->query('//h1')->length, 'Exactly one H1');
        $this->assertGreaterThanOrEqual(10, $xpath->query('//h2')->length);
        $previous = 0;
        foreach ($xpath->query('//h1|//h2|//h3|//h4') as $heading) {
            $level = (int) substr($heading->nodeName, 1);
            $this->assertLessThanOrEqual($previous + 1, $level, 'Heading level jumps to '.$heading->nodeName.': '.trim($heading->textContent));
            $previous = $level;
        }
        foreach ($xpath->query('//img') as $image) {
            $this->assertNotSame('', trim($image->getAttribute('alt')), 'Image without alt: '.$image->getAttribute('src'));
            $this->assertNotSame('', $image->getAttribute('width'), 'Image without intrinsic size: '.$image->getAttribute('src'));
            $path = parse_url($image->getAttribute('src'), PHP_URL_PATH);
            $this->assertFileExists(public_path(ltrim($path, '/')), 'Broken image: '.$path);
        }
        $ids = [];
        foreach ($xpath->query('//*[@id]') as $node) {
            $ids[] = $node->getAttribute('id');
        }
        foreach ($xpath->query('//a[starts-with(@href, "#")]') as $link) {
            $this->assertContains(substr($link->getAttribute('href'), 1), $ids, 'Dead anchor '.$link->getAttribute('href'));
        }
        foreach ($xpath->query('//*[@aria-labelledby]') as $node) {
            $this->assertContains($node->getAttribute('aria-labelledby'), $ids, 'Dangling aria-labelledby');
        }
        foreach ($xpath->query('//a[@href]') as $link) {
            $href = $link->getAttribute('href');
            $this->assertNotContains($href, ['', '#'], 'Placeholder link');
            if (str_starts_with($href, '/') && ! str_starts_with($href, '/#')) {
                $this->get($href)->assertOk();
            }
        }
        $this->assertSame(1, $xpath->query('//main')->length);
        $this->assertGreaterThan(0, $xpath->query('//a[@class="skip"]')->length);
    }

    public function test_home_seo_footer_links_and_no_private_data_leak(): void
    {
        $html = $this->get('/')->assertOk()->getContent();
        $this->assertStringContainsString('<title>SenMiydin? | Bazı karşılaşmalar yarım kalmasın</title>', $html);
        $this->assertMatchesRegularExpression('/<meta name="description" content="[^"]*dijital bir mektup bırak/u', $html);
        $this->assertSame(1, preg_match('/<script type="application\/ld\+json">(.*?)<\/script>/s', $html, $m));
        $schema = json_decode($m[1], true);
        $this->assertSame('SoftwareApplication', $schema['@type']);
        $this->assertContains('Harita Notları: 7 gün kalan dijital mektuplar', $schema['featureList']);
        $this->assertArrayNotHasKey('aggregateRating', $schema);
        foreach (['/gizlilik', '/kvkk', '/kullanim-kosullari', '/topluluk-kurallari', '/iletisim', '/hesap-silme'] as $legal) {
            $this->assertStringContainsString('href="'.$legal.'"', $html, "Footer lacks {$legal}");
            $this->get($legal)->assertOk();
        }
        foreach (['/admin', '/api/', 'Bearer ', 'admin@', 'sanctum', 'APP_KEY'] as $private) {
            $this->assertStringNotContainsString($private, $html, "Private reference on the public page: {$private}");
        }
        $this->assertStringNotContainsString('href="#"', $html);
        $this->assertStringNotContainsString('href=""', $html);
    }

    public function test_public_routes_sitemap_and_robots(): void
    {
        foreach (['nasil-calisir', 'ozellikler', 'guvenlik', 'gizlilik', 'kvkk', 'kullanim-kosullari', 'topluluk-kurallari', 'iletisim', 'hesap-silme'] as $slug) {
            $this->get('/'.$slug)->assertOk()->assertSee('https://senmiydin.tr/'.$slug);
        }
        $this->get('/sitemap.xml')->assertOk()->assertHeader('Content-Type', 'application/xml; charset=UTF-8')
            ->assertSee('<loc>https://senmiydin.tr/hesap-silme</loc>', false)->assertDontSee('/admin');
        $this->get('/robots.txt')->assertOk()->assertSee('Sitemap: https://senmiydin.tr/sitemap.xml');
    }

    public function test_public_forms_validate_and_queue_requests_without_deleting_accounts(): void
    {
        $this->from('/iletisim')->post('/iletisim', ['email' => 'invalid'])->assertSessionHasErrors(['name', 'email', 'subject', 'message']);
        $fields = ['name' => 'Ziyaretçi', 'email' => 'member@example.test', 'subject' => 'Destek', 'message' => 'Bir sorum var.'];
        $this->post('/iletisim', $fields + ['website' => 'spam'])->assertSessionHasErrors('website');
        $this->post('/iletisim', $fields)->assertRedirect('/iletisim');
        $this->post('/hesap-silme', ['name' => $fields['name'], 'email' => $fields['email']])->assertRedirect('/hesap-silme');
        $this->assertDatabaseHas('web_requests', ['type' => 'contact', 'email' => $fields['email']]);
        $this->assertDatabaseHas('web_requests', ['type' => 'deletion', 'email' => $fields['email'], 'handled_at' => null]);
    }

    public function test_legal_cms_escapes_scripts_in_public_pages(): void
    {
        $admin = Admin::create(['name' => 'Yönetici', 'email' => 'admin@example.test', 'password' => 'Secret1234!', 'role' => 'super_admin']);
        $this->actingAs($admin, 'admin')->get('/admin/legal')->assertOk()->assertSee('Gizlilik Politikası');
        $this->from('/admin/legal')->post('/admin/legal/gizlilik', ['title' => 'Gizlilik bilgileri', 'body' => '<script>alert(1)</script>'])
            ->assertRedirect('/admin/legal');
        $this->get('/gizlilik')->assertOk()->assertSee('Gizlilik bilgileri')->assertSee('&lt;script&gt;', false)
            ->assertDontSee('<script>alert(1)</script>', false);
    }
}
