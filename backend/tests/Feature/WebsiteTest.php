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
