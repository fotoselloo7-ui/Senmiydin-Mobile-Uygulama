<?php

namespace App\Http\Controllers;

use App\Administration\Announcements;
use App\Administration\Settings;
use App\Http\ApiResponse;
use App\Models\User;
use Illuminate\Support\Facades\Auth;

class AppConfigController
{
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
            'featured_enabled' => $data['featured_enabled'] && $data['encounters_enabled'],
            'announcement' => $data['announcements_enabled'] && $user instanceof User && $user->account_status === 'active'
                ? $announcements->banner($user) : null,
        ])->header('Cache-Control', 'private, no-store');
    }
}
