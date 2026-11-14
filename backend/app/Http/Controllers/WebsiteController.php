<?php

namespace App\Http\Controllers;

use App\Administration\Settings;
use App\Website\LegalContent;
use App\Website\Pages;
use App\Website\Site;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WebsiteController
{
    public function page(Pages $pages, Settings $settings, string $slug = '')
    {
        return $this->render($pages, $settings, $slug, 'tr');
    }

    /** English site under /en: the path segment is mapped back to the canonical Turkish slug. */
    public function pageEn(Pages $pages, Settings $settings, string $path = '')
    {
        $slug = Site::trSlug($path);
        abort_if($slug === null, 404);

        return $this->render($pages, $settings, $slug, 'en');
    }

    private function render(Pages $pages, Settings $settings, string $slug, string $locale)
    {
        $custom = isset(Pages::LEGAL[$slug]) ? DB::table('legal_pages')->where('slug', $slug)->first() : null;
        $structured = isset(Pages::LEGAL[$slug]) && ! ($custom && $locale === 'tr') ? LegalContent::get($slug, $locale) : null;
        $legal = $structured ? null : (isset(Pages::LEGAL[$slug]) ? $pages->legal()[$slug] : null);
        abort_unless($structured || $legal || isset(Pages::PUBLIC[$slug]), 404);
        $meta = Site::meta($slug, $locale);
        $title = $structured['title'] ?? $legal['title'] ?? $meta[0];
        $values = Site::operatorValues($settings->all(), $locale);
        $legalTitle = $locale === 'en' ? 'SenMiydin? information about %s.' : 'SenMiydin? %s hakkında bilgiler.';

        return view($locale === 'en' ? 'website.page_en' : 'website.page', [
            'slug' => $slug, 'settings' => $settings->all(), 'legal' => $legal, 'legalPage' => $structured, 'operator' => $values,
            'locale' => $locale, 'c' => Site::chrome($locale),
            'title' => $title,
            'description' => ($structured || $legal) ? sprintf($legalTitle, $title) : $meta[1],
            'canonical' => Site::url($slug, $locale),
            'alternate' => ['tr' => Site::url($slug, 'tr'), 'en' => Site::url($slug, 'en')],
            'operatorMissing' => ! Site::operatorComplete($settings->all()),
        ]);
    }

    public function submit(Request $request, string $slug)
    {
        return $this->handle($request, $slug, 'tr');
    }

    public function submitEn(Request $request, string $path)
    {
        $slug = Site::trSlug($path);
        abort_unless(in_array($slug, ['iletisim', 'hesap-silme'], true), 404);

        return $this->handle($request, $slug, 'en');
    }

    private function handle(Request $request, string $slug, string $locale)
    {
        $deletion = $slug === 'hesap-silme';
        $data = $request->validate([
            'name' => 'required|string|max:100', 'email' => 'required|email|max:254',
            'subject' => $deletion ? 'prohibited' : 'required|string|max:120',
            'message' => ($deletion ? 'nullable' : 'required').'|string|max:3000',
            'website' => 'prohibited',
        ]);
        $id = DB::table('web_requests')->insertGetId([
            'type' => $deletion ? 'deletion' : 'contact',
            'name' => $data['name'], 'email' => $data['email'],
            'subject' => $data['subject'] ?? null, 'message' => $data['message'] ?? null, 'created_at' => now(),
        ]);
        $support = app(Settings::class)->get('support_email');
        if (filled($support)) {
            \Illuminate\Support\Facades\Mail::to($support)->queue((new \App\Mail\SupportRequest($id))->afterCommit());
        }
        $status = $locale === 'en'
            ? ($deletion ? 'Your request was received. Account ownership is verified before anything is done.' : 'Your message was received.')
            : ($deletion ? 'Talebin alındı. İşlem öncesinde hesap sahipliği doğrulanır.' : 'Mesajın alındı.');

        return redirect(Site::path($slug, $locale))->with('status', $status);
    }

    public function sitemap()
    {
        return response()->view('website.sitemap', [
            'urls' => collect([...array_keys(Pages::PUBLIC), ...array_keys(Pages::LEGAL)])
                ->flatMap(fn ($slug) => [Site::url($slug, 'tr'), Site::url($slug, 'en')])->all(),
        ])->header('Content-Type', 'application/xml; charset=UTF-8')->header('Cache-Control', 'public, max-age=3600');
    }

    public function robots()
    {
        $rules = app()->environment('production') ? "Allow: /\nDisallow: /admin\nDisallow: /api/" : 'Disallow: /';
        return response("User-agent: *\n$rules\nSitemap: ".config('website.url')."/sitemap.xml\n")
            ->header('Content-Type', 'text/plain; charset=UTF-8')->header('Cache-Control', 'public, max-age=3600');
    }
}
