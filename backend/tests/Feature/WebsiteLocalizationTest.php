<?php

namespace Tests\Feature;

use App\Administration\Settings;
use App\Models\Admin;
use App\Website\LegalContent;
use App\Website\Site;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** Public website: Turkish source + English under /en, legal pages in the site design, honest operator identity. */
class WebsiteLocalizationTest extends TestCase
{
    use RefreshDatabase;

    private const EN_PAGES = ['', 'how-it-works', 'features', 'safety', 'privacy', 'kvkk', 'terms', 'community-guidelines', 'contact', 'delete-account'];

    public function test_every_english_page_renders_in_english_with_alternates_and_a_switch_back_to_turkish(): void
    {
        foreach (self::EN_PAGES as $path) {
            $url = $path === '' ? '/en' : '/en/'.$path;
            $html = $this->get($url)->assertOk()->getContent();
            $this->assertStringContainsString('<html lang="en">', $html, $url);
            $this->assertStringContainsString('hreflang="tr"', $html, $url);
            $this->assertStringContainsString('hreflang="en"', $html, $url);
            $this->assertStringContainsString('hreflang="x-default"', $html, $url);
            $this->assertStringContainsString('content="en_US"', $html, $url);
            $trSlug = Site::trSlug($path);
            $this->assertStringContainsString('rel="canonical" href="https://senmiydin.tr'.Site::path($trSlug, 'en').'"', $html, $url);
            $this->assertStringContainsString('class="lang-switch"', $html);
            $this->assertStringContainsString('href="https://senmiydin.tr'.($trSlug === '' ? '/' : '/'.$trSlug).'" hreflang="tr"', $html, "Switch to Turkish from $url");
            $this->assertStringContainsString('Skip to content', $html);
            $this->assertStringNotContainsString('İçeriğe geç', $html);
            $this->assertSame(1, substr_count($html, '<h1'), "Exactly one H1 on $url");
        }
    }

    public function test_the_turkish_site_stays_turkish_and_offers_the_english_switch(): void
    {
        foreach (['', 'nasil-calisir', 'gizlilik', 'kvkk'] as $slug) {
            $html = $this->get('/'.$slug)->assertOk()->getContent();
            $this->assertStringContainsString('<html lang="tr">', $html);
            $this->assertStringContainsString('hreflang="en"', $html);
            $this->assertStringContainsString('href="https://senmiydin.tr'.Site::path($slug, 'en').'" hreflang="en"', $html);
            $this->assertStringContainsString('İçeriğe geç', $html);
        }
    }

    public function test_english_home_tells_the_same_story_in_english_with_the_new_social_features(): void
    {
        $html = $this->get('/en')->assertOk()->getContent();
        $order = ['data-slider', 'id="nedir"', 'id="nasil-calisir"', 'id="sehir-akisi"', 'id="karsilasma"', 'id="harita"', 'id="harita-notlari"',
            'id="gectigim-yerler"', 'id="yolculuk"', 'id="mesajlasma"', 'id="guvenlik"', 'id="ekranlar"', 'id="indir"', 'site-footer'];
        $previous = -1;
        foreach ($order as $marker) {
            $position = strpos($html, $marker);
            $this->assertNotFalse($position, "Missing {$marker}");
            $this->assertGreaterThan($previous, $position);
            $previous = $position;
        }
        foreach (['Maybe the person you are looking for is', 'is not a dating app', 'Following', 'one-level comment conversation', 'collections that only you can see',
            'My Letters and archive', 'share an expired letter again', 'a small notification', 'Photo messages (from the gallery or the camera), emoji',
            'There are no group chats or calls', 'Accounts aged 16–17 only meet their own age group', 'Soon · App Store', 'Soon · Google Play'] as $expected) {
            $this->assertStringContainsString($expected, $html, "English home lacks: $expected");
        }
        foreach (['Takip ettiğin', 'Mektuplarım', 'Şehrinde'] as $turkish) {
            $this->assertStringNotContainsString($turkish, $html, "Turkish leftover: $turkish");
        }
        // No fake proof or dating copy in English either.
        $text = mb_strtolower(strip_tags($html));
        foreach (['swipe', 'premium', 'testimonial', 'million users', '5-star', 'dating app for'] as $banned) {
            $this->assertStringNotContainsString($banned, $text);
        }
    }

    public function test_turkish_home_carries_the_new_social_features_inside_the_existing_story(): void
    {
        $html = $this->get('/')->assertOk()->getContent();
        foreach (['Takip ettiğin insanların paylaşımları', 'tek seviyeli bir yorum sohbeti', 'koleksiyonlarda saklarsın', 'Mektuplarım ve arşiv',
            'yeniden paylaşabilirsin', 'küçük bir bildirim alırsın', 'galeriden ya da kameradan', 'canlı konum paylaşımı yoktur', 'Yaş grupları'] as $expected) {
            $this->assertStringContainsString($expected, $html, "Turkish home lacks: $expected");
        }
    }

    public function test_every_internal_link_on_the_english_pages_resolves(): void
    {
        foreach (self::EN_PAGES as $path) {
            $html = $this->get($path === '' ? '/en' : '/en/'.$path)->assertOk()->getContent();
            $document = new \DOMDocument();
            libxml_use_internal_errors(true);
            $document->loadHTML('<?xml encoding="utf-8"?>'.$html);
            libxml_clear_errors();
            $xpath = new \DOMXPath($document);
            $ids = array_map(fn ($n) => $n->getAttribute('id'), iterator_to_array($xpath->query('//*[@id]')));
            foreach ($xpath->query('//a[@href]') as $link) {
                $href = $link->getAttribute('href');
                if (str_starts_with($href, '#')) {
                    $this->assertContains(substr($href, 1), $ids, "Dead anchor $href on /en/$path");
                } elseif (str_starts_with($href, '/') && ! str_starts_with($href, '/#') && ! str_contains($href, '#')) {
                    $this->get($href)->assertOk();
                }
            }
            foreach ($xpath->query('//img') as $image) {
                $this->assertNotSame('', trim($image->getAttribute('alt')), 'Image without alt on '.$path);
                $this->assertFileExists(public_path(ltrim(parse_url($image->getAttribute('src'), PHP_URL_PATH), '/')));
            }
        }
    }

    public function test_kvkk_covers_the_real_data_flows_in_turkish_and_english(): void
    {
        $topics = [
            'tr' => ['Veri sorumlusu', 'İşlenen kişisel veriler', 'Hesap bilgileri', 'Doğum tarihi ve yaş', 'Profil verileri', 'Kullanıcı içerikleri', 'Fotoğraflar', 'Mesajlar',
                'Yaklaşık konum', 'Geçtiğim Yerler', 'Cihaz ve bildirim bilgisi', 'Güvenlik ve denetim kayıtları', 'AdMob', 'İşleme amaçları', 'Hukuki sebepler',
                'Veri alıcıları ve hizmet sağlayıcılar', 'Yurt dışına aktarım', 'Saklama süreleri', 'Hesap silme', 'İlgili kişinin hakları', 'Başvuru yöntemi'],
            'en' => ['Data controller', 'Personal data we process', 'Account data', 'Date of birth and age', 'Profile data', 'User content', 'Photos', 'Messages',
                'Approximate location', 'Places I Passed', 'Device and push data', 'Safety and audit records', 'AdMob', 'Purposes of processing', 'Legal bases',
                'Recipients and service providers', 'Transfers abroad', 'Retention', 'Account deletion', 'Your rights', 'How to apply'],
        ];
        foreach (['tr' => '/kvkk', 'en' => '/en/kvkk'] as $locale => $url) {
            $html = $this->get($url)->assertOk()->getContent();
            foreach ($topics[$locale] as $topic) {
                $this->assertStringContainsString($topic, $html, "$locale KVKK lacks: $topic");
            }
        }
    }

    public function test_privacy_terms_and_community_pages_cover_their_required_topics(): void
    {
        $expect = [
            '/gizlilik' => ['Firebase Cloud Messaging', 'AdMob', 'Google ile giriş', 'Apple', 'Konum nasıl kullanılır', 'Saklama ve silme', '16–17 yaş grubu', 'Konum verin reklam hedeflemede kullanılmaz'],
            '/en/privacy' => ['Firebase Cloud Messaging', 'AdMob', 'Sign in with Google', 'Apple', 'How location is used', 'Retention and deletion', 'Ages 16–17', 'not used for ad targeting'],
            '/kullanim-kosullari' => ['16 yaş ve üzeri', 'Hesap sorumluluğu', 'anonim', 'Harita Notları', 'Reklamlar', 'Fikri mülkiyet', 'Hesabı kapatma', 'askıya alma'],
            '/en/terms' => ['aged 16 and over', 'Account responsibility', 'anonymous', 'Map Notes', 'Advertising', 'Intellectual property', 'Closing your account', 'suspension'],
            '/topluluk-kurallari' => ['Taciz', 'Stalking', 'Tehdit', 'Nefret', 'Cinsel içerik', 'Reşit olmayanlara', 'Kişisel bilgi ifşası', 'Kesin konum', 'Spam', 'Taklit', 'Rıza dışı', 'Harita Notu', 'Mesaj kötüye'],
            '/en/community-guidelines' => ['Harassment', 'Stalking', 'Threats', 'Hate speech', 'Sexual content', 'minors', 'Doxxing', 'exact location', 'Spam', 'Impersonation', 'Non-consensual', 'Map Note abuse', 'Message abuse'],
        ];
        $missing = [];
        foreach ($expect as $url => $needles) {
            $html = $this->get($url)->assertOk()->getContent();
            foreach ($needles as $needle) {
                if (! str_contains($html, $needle)) {
                    $missing[] = "$url lacks: $needle";
                }
            }
        }
        $this->assertSame([], $missing);
    }

    public function test_the_account_deletion_page_explains_the_app_path_the_web_request_and_what_stays(): void
    {
        $tr = $this->get('/hesap-silme')->assertOk()->getContent();
        foreach (['Profil → Ayarlar → Hesabımı Sil', 'SİL', 'Adımlar', 'Talep hangi verileri kapsar', 'moderasyon', 'yedek'] as $needle) {
            $this->assertStringContainsString($needle, $tr);
        }
        $en = $this->get('/en/delete-account')->assertOk()->getContent();
        foreach (['Profile → Settings → Delete My Account', 'DELETE', 'Steps', 'What does a request cover', 'moderation', 'backups', 'private message photos'] as $needle) {
            $this->assertStringContainsString($needle, $en);
        }
    }

    public function test_operator_identity_comes_from_admin_settings_and_is_never_invented(): void
    {
        $missing = $this->get('/kvkk')->assertOk()->getContent();
        $this->assertStringContainsString('henüz tamamlanmadı', $missing);
        $this->assertStringContainsString('işletici tarafından tamamlanacak', $missing);
        $this->assertDoesNotMatchRegularExpression('/Unvan: (?!—)[A-Z]/u', $missing);
        $this->assertStringContainsString('not been completed yet', $this->get('/en/kvkk')->assertOk()->getContent());

        app(Settings::class)->save(['operator_name' => 'Örnek Teknoloji A.Ş.', 'operator_address' => 'Barbaros Bulvarı 1, Beşiktaş / İstanbul',
            'operator_registration' => 'MERSIS 0123456789012345', 'operator_contact_email' => 'kvkk@ornek.test']);
        $filled = $this->get('/kvkk')->assertOk()->getContent();
        foreach (['Örnek Teknoloji A.Ş.', 'Barbaros Bulvarı 1', 'MERSIS 0123456789012345', 'kvkk@ornek.test'] as $value) {
            $this->assertStringContainsString($value, $filled);
        }
        $this->assertStringNotContainsString('henüz tamamlanmadı', $filled);
        $english = $this->get('/en/privacy')->assertOk()->getContent();
        $this->assertStringContainsString('Örnek Teknoloji A.Ş.', $english);
        $this->assertStringContainsString('kvkk@ornek.test', $english);
    }

    public function test_production_readiness_fails_until_the_operator_identity_is_complete(): void
    {
        $row = function (): array {
            Artisan::call('senmiydin:production-check', ['--json' => true]);
            $report = json_decode(Artisan::output(), true, flags: JSON_THROW_ON_ERROR);

            return collect($report['checks'])->keyBy('check')['Operator identity and reviewed legal CMS'];
        };
        config(['deployment.operator_name' => 'Gerçek A.Ş.', 'deployment.operator_contact' => 'destek@gercek-isletme.com.tr', 'deployment.legal_reviewed' => true]);
        $this->assertSame('MISSING', $row()['status'], 'No operator identity in the admin settings yet.');
        app(Settings::class)->save(['operator_name' => 'Gerçek A.Ş.', 'operator_address' => 'Gerçek Mah. 1 İstanbul', 'operator_registration' => '123456']);
        $this->assertSame('MISSING', $row()['status'], 'Contact email still missing.');
        app(Settings::class)->save(['operator_contact_email' => 'kvkk@gercek-isletme.com.tr']);
        $this->assertSame('OK', $row()['status']);
        app(Settings::class)->save(['operator_name' => 'Demo İşletme']);
        $this->assertSame('MISSING', $row()['status'], 'Placeholder / demo identities fail.');
    }

    public function test_the_admin_can_edit_the_operator_fields_and_they_are_validated(): void
    {
        $admin = Admin::create(['name' => 'Yönetici', 'email' => 'admin@example.test', 'password' => 'Secret1234!', 'role' => 'super_admin']);
        $this->actingAs($admin, 'admin')->get('/admin/settings')->assertOk()->assertSee('Operatör unvanı')->assertSee('KVKK / yasal iletişim e-postası');
        $this->from('/admin/settings')->post('/admin/settings', ['operator_name' => 'Gerçek A.Ş.', 'operator_address' => 'Adres 1', 'operator_registration' => '42',
            'operator_contact_email' => 'kvkk@gercek.test'])->assertRedirect('/admin/settings')->assertSessionHasNoErrors();
        $this->assertSame('Gerçek A.Ş.', app(Settings::class)->get('operator_name'));
        $this->post('/admin/settings', ['operator_contact_email' => 'not-an-email'])->assertSessionHasErrors('operator_contact_email');
    }

    public function test_english_forms_post_to_english_paths_and_answer_in_english(): void
    {
        $this->from('/en/contact')->post('/en/contact', ['email' => 'invalid'])->assertSessionHasErrors(['name', 'email', 'subject', 'message']);
        $this->post('/en/contact', ['name' => 'Visitor', 'email' => 'visitor@example.test', 'subject' => 'Help', 'message' => 'A question.'])
            ->assertRedirect('/en/contact')->assertSessionHas('status', 'Your message was received.');
        $this->post('/en/delete-account', ['name' => 'Visitor', 'email' => 'visitor@example.test'])
            ->assertRedirect('/en/delete-account')->assertSessionHas('status');
        $this->assertDatabaseHas('web_requests', ['type' => 'deletion', 'email' => 'visitor@example.test']);
        $this->get('/en/contact')->assertSee('action="/en/contact"', false);
        $this->get('/en/nonexistent')->assertNotFound();
    }

    public function test_sitemap_lists_both_languages_and_the_legal_api_follows_the_request_language(): void
    {
        $sitemap = $this->get('/sitemap.xml')->assertOk()->getContent();
        foreach (['/hesap-silme', '/en/delete-account', '/en', '/en/privacy', '/en/community-guidelines', '/kvkk', '/en/kvkk'] as $path) {
            $this->assertStringContainsString('<loc>https://senmiydin.tr'.$path.'</loc>', $sitemap);
        }
        $this->assertStringNotContainsString('/admin', $sitemap);
        $turkish = $this->getJson('/api/v1/legal/gizlilik')->assertOk()->json('data');
        $this->assertSame('Gizlilik Politikası', $turkish['title']);
        $this->assertStringContainsString('Firebase Cloud Messaging', $turkish['body']);
        $english = $this->withHeader('Accept-Language', 'en')->getJson('/api/v1/legal/gizlilik')->assertOk()->json('data');
        $this->assertSame('Privacy Policy', $english['title']);
        $this->assertStringContainsString('Firebase Cloud Messaging', $english['body']);
        $this->assertStringContainsString('What we collect', $english['body']);
    }

    public function test_an_administrator_edited_turkish_legal_page_still_wins_and_stays_escaped(): void
    {
        DB::table('legal_pages')->insert(['slug' => 'gizlilik', 'title' => 'Özel Gizlilik', 'body' => "Kendi metnim\n<script>alert(1)</script>", 'updated_at' => now()]);
        $html = $this->get('/gizlilik')->assertOk()->getContent();
        $this->assertStringContainsString('Özel Gizlilik', $html);
        $this->assertStringContainsString('&lt;script&gt;', $html);
        $this->assertStringNotContainsString('<script>alert(1)</script>', $html);
        $this->assertStringNotContainsString('legal-toc', $html, 'The CMS text is shown as the administrator wrote it.');
        // English always uses the maintained structured text.
        $this->assertStringContainsString('legal-toc', $this->get('/en/privacy')->assertOk()->getContent());
    }

    public function test_legal_content_helpers_never_leave_raw_placeholders(): void
    {
        $values = Site::operatorValues([], 'tr');
        foreach (['tr', 'en'] as $locale) {
            foreach (LegalContent::titles($locale) as $slug => $title) {
                $text = LegalContent::plain($slug, $locale, Site::operatorValues([], $locale));
                $this->assertNotNull($text);
                $this->assertDoesNotMatchRegularExpression('/\{[a-z_]+\}/', $text, "$locale/$slug leaves a raw placeholder");
            }
        }
        $this->assertSame('—', LegalContent::fill('{operator_name}', ['_missing' => '—']));
        $this->assertFalse(Site::operatorComplete([]));
        $this->assertArrayHasKey('contact_email', $values);
    }
}
