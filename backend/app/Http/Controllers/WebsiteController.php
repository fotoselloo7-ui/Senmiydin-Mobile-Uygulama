<?php

namespace App\Http\Controllers;

use App\Administration\Settings;
use App\Website\Pages;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WebsiteController
{
    public function page(Pages $pages, Settings $settings, string $slug = '')
    {
        $legal = isset(Pages::LEGAL[$slug]) ? $pages->legal()[$slug] : null;
        abort_unless($legal || isset(Pages::PUBLIC[$slug]), 404);
        return view('website.page', [
            'slug' => $slug, 'settings' => $settings->all(), 'legal' => $legal,
            'title' => $legal['title'] ?? Pages::PUBLIC[$slug][0],
            'description' => $legal ? 'SenMiydin? '.$legal['title'].' hakkında bilgiler.' : Pages::PUBLIC[$slug][1],
            'canonical' => config('website.url').'/'.$slug,
        ]);
    }

    public function submit(Request $request, string $slug)
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
        return redirect('/'.$slug)->with('status', $deletion
            ? 'Talebin alındı. İşlem öncesinde hesap sahipliği doğrulanır.'
            : 'Mesajın alındı.');
    }

    public function sitemap()
    {
        return response()->view('website.sitemap', [
            'urls' => array_map(fn ($slug) => config('website.url').'/'.$slug, [...array_keys(Pages::PUBLIC), ...array_keys(Pages::LEGAL)]),
        ])->header('Content-Type', 'application/xml; charset=UTF-8')->header('Cache-Control', 'public, max-age=3600');
    }

    public function robots()
    {
        $rules = app()->environment('production') ? "Allow: /\nDisallow: /admin\nDisallow: /api/" : 'Disallow: /';
        return response("User-agent: *\n$rules\nSitemap: ".config('website.url')."/sitemap.xml\n")
            ->header('Content-Type', 'text/plain; charset=UTF-8')->header('Cache-Control', 'public, max-age=3600');
    }
}
