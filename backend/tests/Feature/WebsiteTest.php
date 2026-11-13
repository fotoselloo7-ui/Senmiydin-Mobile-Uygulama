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
            ->assertSee('name="description"', false)->assertSee('rel="canonical" href="https://senmiydin.com/"', false)
            ->assertSee('property="og:image"', false)->assertSee('name="twitter:card"', false)
            ->assertSee('SoftwareApplication')->assertDontSee('aggregateRating')->assertDontSee('downloadUrl');
    }

    public function test_public_home_follows_the_final_story_flow_without_dating_copy_or_invented_proof(): void
    {
        $html = $this->get('/')->assertOk()->getContent();
        $order = ['story-slider', 'id="nedir"', 'id="nasil-calisir"', 'id="sehir-akisi"', 'id="harita"', 'id="paylasim"',
            'id="karsilasma"', 'id="yolculuk"', 'id="mesajlasma"', 'id="guvenlik"', 'id="ekranlar"', 'id="indir"', 'site-footer'];
        $previous = -1;
        foreach ($order as $marker) {
            $position = strpos($html, $marker);
            $this->assertNotFalse($position, "Missing {$marker}");
            $this->assertGreaterThan($previous, $position, "{$marker} is out of order");
            $previous = $position;
        }
        $this->assertGreaterThanOrEqual(5, substr_count($html, 'class="story-slide'));
        $this->assertStringContainsString('Pamukkale · Ankara → Erzincan · 07 NM 365', $html);
        $this->assertStringContainsString('class="nav-toggle"', $html);
        foreach (['flört uygulaması değildir', 'Yakında · App Store', 'Yakında · Google Play'] as $expected) {
            $this->assertStringContainsString($expected, $html);
        }
        foreach (['aggregateRating', 'ratingValue', '100K', '50K', '4.9 ★', '★', 'yorum yapan', 'instagram.com', 'tiktok.com', 'youtube.com', 'eşleşme algoritma', 'swipe', 'Premium', 'flörtleş'] as $forbidden) {
            $this->assertStringNotContainsStringIgnoringCase($forbidden, $html, "Invented or off-product copy: {$forbidden}");
        }
    }

    public function test_public_routes_sitemap_and_robots(): void
    {
        foreach (['nasil-calisir', 'ozellikler', 'guvenlik', 'gizlilik', 'kvkk', 'kullanim-kosullari', 'topluluk-kurallari', 'iletisim', 'hesap-silme'] as $slug) {
            $this->get('/'.$slug)->assertOk()->assertSee('https://senmiydin.com/'.$slug);
        }
        $this->get('/sitemap.xml')->assertOk()->assertHeader('Content-Type', 'application/xml; charset=UTF-8')
            ->assertSee('<loc>https://senmiydin.com/hesap-silme</loc>', false)->assertDontSee('/admin');
        $this->get('/robots.txt')->assertOk()->assertSee('Sitemap: https://senmiydin.com/sitemap.xml');
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
