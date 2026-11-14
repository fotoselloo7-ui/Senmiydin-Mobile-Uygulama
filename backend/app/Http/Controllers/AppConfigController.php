<?php

namespace App\Http\Controllers;

use App\Administration\Announcements;
use App\Administration\Settings;
use App\Http\ApiResponse;
use App\Models\User;
use Illuminate\Support\Facades\Auth;

class AppConfigController
{
    /** The banner follows the request language; English falls back to the Turkish text when it was left empty. */
    private function localized(?object $banner): ?object
    {
        if (! $banner) {
            return null;
        }
        $english = app()->getLocale() === 'en';

        return (object) [
            'id' => $banner->id,
            'title' => $english && filled($banner->title_en ?? null) ? $banner->title_en : $banner->title,
            'body' => $english && filled($banner->body_en ?? null) ? $banner->body_en : $banner->body,
        ];
    }

    public function __invoke(Settings $settings, Announcements $announcements)
    {
        $data = $settings->all();
        $user = Auth::guard('sanctum')->user();
        return ApiResponse::ok([
            'versions' => [
                'android' => ['minimum' => $data['android_min_version'], 'latest' => $data['android_latest_version'], 'url' => $data['play_store_url']],
                'ios' => ['minimum' => $data['ios_min_version'], 'latest' => $data['ios_latest_version'], 'url' => $data['app_store_url']],
            ],
            'maintenance' => $data['maintenance_mode'],
            'maintenance_message' => $data['maintenance_mode'] ? $data['maintenance_message'] : null,
            'nearby_enabled' => $data['nearby_enabled'],
            'nearby_notes_enabled' => $data['nearby_notes_enabled'],
            'minimum_age' => (int) $data['minimum_age'],
            // Native feed ads: the admin switch and the interval between ads (organic posts), nothing else.
            'ads_enabled' => (bool) $data['ads_enabled'],
            'feed_ad_interval' => (int) $data['feed_ad_interval'],
            'featured_enabled' => $data['featured_enabled'] && $data['encounters_enabled'],
            'announcement' => $data['announcements_enabled'] && $user instanceof User && $user->account_status === 'active'
                ? $this->localized($announcements->banner($user)) : null,
        ])->header('Cache-Control', 'private, no-store');
    }
}
