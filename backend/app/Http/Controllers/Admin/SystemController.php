<?php

namespace App\Http\Controllers\Admin;

use App\Administration\Announcements;
use App\Administration\Audit;
use App\Administration\Settings;
use App\Models\City;
use App\Models\Interest;
use App\Website\Pages;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class SystemController
{
    public function settings(Request $request, Settings $settings)
    {
        $rules = [
            'app_name' => 'sometimes|required|string|max:80', 'support_email' => 'sometimes|nullable|email|max:254',
            'app_store_url' => 'sometimes|nullable|url:https|max:250', 'play_store_url' => 'sometimes|nullable|url:https|max:250',
            'web_cta' => 'sometimes|required|string|max:120', 'web_announcement' => 'sometimes|nullable|string|max:300',
            'maintenance_message' => 'sometimes|required|string|max:200',
            'minimum_age' => 'sometimes|integer|between:16,25', 'max_post_photos' => 'sometimes|integer|between:1,10',
            'location_history_days' => 'sometimes|integer|between:1,30',
            'moderation_banned_words' => 'sometimes|nullable|string|max:4000',
            'moderation_blocked_domains' => 'sometimes|nullable|string|max:4000',
            'moderation_max_mentions' => 'sometimes|integer|between:1,30',
            'moderation_max_links' => 'sometimes|integer|between:1,20',
            'moderation_post_repeats' => 'sometimes|integer|between:2,20',
            'moderation_comment_repeats' => 'sometimes|integer|between:2,20',
            'moderation_repeat_seconds' => 'sometimes|integer|between:10,600',
            'feed_ad_interval' => 'sometimes|integer|between:8,30',
            'operator_name' => 'sometimes|nullable|string|max:160', 'operator_address' => 'sometimes|nullable|string|max:300',
            'operator_registration' => 'sometimes|nullable|string|max:80', 'operator_contact_email' => 'sometimes|nullable|email|max:254',
        ];
        foreach (Settings::SWITCHES as $key) {
            $rules[$key] = 'sometimes|boolean';
        }
        foreach (['android_min_version', 'android_latest_version', 'ios_min_version', 'ios_latest_version'] as $key) {
            $rules[$key] = ['sometimes', 'nullable', 'string', 'max:32', 'regex:/\\A(0|[1-9][0-9]{0,5})\\.(0|[1-9][0-9]{0,5})\\.(0|[1-9][0-9]{0,5})\\z/'];
        }
        $data = $request->validate($rules);
        $merged = $data + $settings->all();
        foreach (['android' => 'play_store_url', 'ios' => 'app_store_url'] as $platform => $url) {
            $minimum = $merged[$platform.'_min_version'];
            $latest = $merged[$platform.'_latest_version'];
            if (filled($minimum) && (!filled($merged[$url]) || (filled($latest) && version_compare($latest, $minimum, '<')))) {
                throw ValidationException::withMessages([$platform.'_min_version' => 'Minimum sürüm için resmî mağaza bağlantısı gerekli; güncel sürüm minimumdan eski olamaz.']);
            }
        }
        foreach (['app_store_url' => 'apps.apple.com', 'play_store_url' => 'play.google.com'] as $key => $host) {
            $store = $data[$key] ?? null;
            if (!filled($store)) continue;
            $valid = parse_url($store, PHP_URL_HOST) === $host
                && !parse_url($store, PHP_URL_USER) && !parse_url($store, PHP_URL_PASS);
            if ($key === 'play_store_url') {
                parse_str(parse_url($store, PHP_URL_QUERY) ?? '', $parameters);
                $valid = $valid && parse_url($store, PHP_URL_PATH) === '/store/apps/details'
                    && ($parameters['id'] ?? null) === 'com.senmiydin.app';
            } else {
                $valid = $valid && preg_match('/\\/id[0-9]+(?:\\/|$)/', parse_url($store, PHP_URL_PATH) ?? '');
            }
            if (!$valid) {
                throw ValidationException::withMessages([$key => 'Bu uygulamanın resmî mağaza bağlantısını gir.']);
            }
        }
        $data = collect($data)->map(fn ($value, $key) => in_array($key, Settings::SWITCHES, true)
            ? (bool) $value : (in_array($key, ['minimum_age', 'feed_ad_interval', 'max_post_photos', 'location_history_days', 'moderation_max_mentions', 'moderation_max_links', 'moderation_post_repeats', 'moderation_comment_repeats', 'moderation_repeat_seconds'], true) ? (int) $value : $value))->all();
        DB::transaction(function () use ($request, $settings, $data): void {
            $settings->save($data);
            Audit::record($request, 'settings.update', 'settings', null, $data);
        });
        return back()->with('status', 'Ayarlar kaydedildi.');
    }

    public function interest(Request $request, ?int $id = null)
    {
        $request->merge(['slug' => Str::slug($request->input('slug') ?: (string) $request->input('name'))]);
        $data = $request->validate([
            'name' => ['required', 'string', 'max:80'],
            'slug' => ['required', 'alpha_dash:ascii', 'max:100', Rule::unique('interests')->ignore($id)],
            'icon' => 'nullable|string|max:50', 'sort_order' => 'required|integer|min:0|max:65535', 'is_active' => 'required|boolean',
        ]);
        DB::transaction(function () use ($request, $id, $data): void {
            $entry = $id ? Interest::lockForUpdate()->findOrFail($id) : new Interest;
            $entry->forceFill([...$data, 'icon' => $data['icon'] ?? $entry->icon ?? 'star'])->save();
            Audit::record($request, $id ? 'interest.update' : 'interest.create', 'interest', $entry->id, $data);
        });
        \Illuminate\Support\Facades\Cache::forget('catalog:interests:v1');
        return back()->with('status', 'Hobi kaydedildi.');
    }

    public function city(Request $request, int $id)
    {
        $data = $request->validate(['is_active' => 'required|boolean']);
        DB::transaction(function () use ($request, $id, $data): void {
            City::lockForUpdate()->findOrFail($id)->forceFill($data)->save();
            Audit::record($request, 'city.update', 'city', $id, $data);
        });
        \Illuminate\Support\Facades\Cache::forget('catalog:cities:v1');
        return back()->with('status', 'Şehir durumu kaydedildi.');
    }

    public function legal(Request $request, string $slug)
    {
        abort_unless(isset(Pages::LEGAL[$slug]), 404);
        $data = $request->validate(['title' => 'required|string|max:120', 'body' => 'required|string|max:20000']);
        DB::transaction(function () use ($request, $slug, $data): void {
            DB::table('legal_pages')->updateOrInsert(['slug' => $slug], $data + ['updated_at' => now()]);
            Audit::record($request, 'legal.update', 'legal_page', null, ['slug' => $slug]);
        });
        return back()->with('status', 'Web içeriği kaydedildi.');
    }

    public function announcement(Request $request, Announcements $announcements)
    {
        $data = $request->validate([
            'title' => 'required|string|max:120', 'body' => 'required|string|max:2000',
            'title_en' => 'nullable|string|max:120', 'body_en' => 'nullable|string|max:2000',
            // all = everyone, city = people whose city is the chosen one, location = people currently near an approximate point.
            'target_type' => 'sometimes|in:all,city,location',
            'target_latitude' => 'required_if:target_type,location|nullable|numeric|between:-90,90',
            'target_longitude' => 'required_if:target_type,location|nullable|numeric|between:-180,180',
            'target_radius_m' => ['required_if:target_type,location', 'nullable', 'integer', Rule::in([500, 1000, 5000])],
            'city_id' => ['nullable', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
            'publish_at' => 'nullable|date_format:Y-m-d\TH:i',
            'expires_at' => 'nullable|date_format:Y-m-d\TH:i',
            'send_push' => 'required|boolean', 'show_in_app' => 'required|boolean',
            'is_active' => 'sometimes|boolean',
        ]);
        if (! $data['send_push'] && ! $data['show_in_app']) {
            throw ValidationException::withMessages(['show_in_app' => 'En az bir yayın kanalı seç.']);
        }
        $target = $data['target_type'] ?? (empty($data['city_id']) ? 'all' : 'city');
        if ($target === 'city' && empty($data['city_id'])) {
            throw ValidationException::withMessages(['city_id' => 'Şehir hedefi için bir şehir seç.']);
        }
        // The stored target is an approximate point on the dedicated grid (~55 m), never anything more precise.
        // An announcement's point is an area an administrator marks, not a note: it keeps the coarse placement grid.
        $grid = (float) config('map_notes.announcement_grid');
        $publishAt = empty($data['publish_at']) ? now() : Carbon::parse($data['publish_at'], 'Europe/Istanbul')->utc();
        $expiresAt = empty($data['expires_at']) ? null : Carbon::parse($data['expires_at'], 'Europe/Istanbul')->utc();
        if ($expiresAt && $expiresAt->lte($publishAt)) {
            throw ValidationException::withMessages(['expires_at' => 'Bitiş zamanı yayın zamanından sonra olmalı.']);
        }
        $id = DB::transaction(function () use ($request, $data, $publishAt, $expiresAt, $target, $grid): int {
            $id = DB::table('announcements')->insertGetId([
                'title' => $data['title'], 'body' => $data['body'],
                'title_en' => filled($data['title_en'] ?? null) ? $data['title_en'] : null,
                'body_en' => filled($data['body_en'] ?? null) ? $data['body_en'] : null,
                'target_type' => $target,
                'target_latitude' => $target === 'location' ? \App\Location\Geo::grid((float) $data['target_latitude'], $grid) : null,
                'target_longitude' => $target === 'location' ? \App\Location\Geo::grid((float) $data['target_longitude'], $grid) : null,
                'target_radius_m' => $target === 'location' ? (int) $data['target_radius_m'] : null,
                'city_id' => $target === 'all' ? null : ($data['city_id'] ?? null), 'admin_id' => $request->user('admin')->id,
                'publish_at' => $publishAt, 'expires_at' => $expiresAt,
                'send_push' => (bool) $data['send_push'], 'show_in_app' => (bool) $data['show_in_app'],
                'is_active' => (bool) ($data['is_active'] ?? true),
                'created_at' => now(), 'updated_at' => now(),
            ]);
            Audit::record($request, 'announcement.create', 'announcement', $id, [
                'city_id' => $data['city_id'] ?? null, 'target_type' => $target,
                'target_radius_m' => $target === 'location' ? (int) $data['target_radius_m'] : null,
                'is_active' => (bool) ($data['is_active'] ?? true),
            ]);
            return $id;
        });
        $announcements->publishBatch($id);
        return back()->with('status', 'Duyuru kaydedildi.');
    }

    public function updateAnnouncement(Request $request, int $id, Announcements $announcements)
    {
        $data = $request->validate([
            'is_active' => 'required|boolean',
            'expires_at' => 'nullable|date_format:Y-m-d\TH:i',
        ]);
        DB::transaction(function () use ($request, $id, $data): void {
            $entry = DB::table('announcements')->lockForUpdate()->find($id) ?? abort(404);
            $expiresAt = array_key_exists('expires_at', $data)
                ? (empty($data['expires_at']) ? null : Carbon::parse($data['expires_at'], 'Europe/Istanbul')->utc())
                : $entry->expires_at;
            if ($expiresAt && Carbon::parse($expiresAt)->lte(Carbon::parse($entry->publish_at))) {
                throw ValidationException::withMessages(['expires_at' => 'Bitiş zamanı yayın zamanından sonra olmalı.']);
            }
            DB::table('announcements')->where('id', $id)->update([
                'is_active' => (bool) $data['is_active'],
                'expires_at' => $expiresAt,
                'updated_at' => now(),
            ]);
            Audit::record($request, 'announcement.update', 'announcement', $id, [
                'is_active' => (bool) $data['is_active'],
                'expires_at' => $expiresAt ? Carbon::parse($expiresAt)->toIso8601String() : null,
            ]);
        });
        $announcements->publishBatch($id);
        return back()->with('status', 'Duyuru güncellendi.');
    }

    public function support(Request $request, int $id)
    {
        DB::transaction(function () use ($request, $id): void {
            $entry = DB::table('web_requests')->lockForUpdate()->find($id) ?? abort(404);
            if (! $entry->handled_at) {
                DB::table('web_requests')->where('id', $id)->update(['handled_at' => now()]);
                Audit::record($request, 'support.handled', 'web_request', $id);
            }
        });
        return back()->with('status', 'Talep incelendi olarak işaretlendi.');
    }
}
