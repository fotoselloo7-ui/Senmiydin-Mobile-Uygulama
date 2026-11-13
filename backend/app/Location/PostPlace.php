<?php

namespace App\Location;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class PostPlace
{
    public function resolve(User $user, array $data): ?array
    {
        $source = $data['location_source'] ?? (($data['attach_location'] ?? false) ? 'current' : null);
        if (!$source || ($data['visibility'] ?? 'city') !== 'city') return null;
        $point = null;
        if ($source === 'history') {
            if (!$user->location_history_enabled) $this->fail('Önce Geçtiğim Yerler özelliğini aç.');
            $point = DB::table('user_location_history')->where('user_id', $user->id)
                ->where('recorded_at', '>=', LocationData::cutoff())->where('id', $data['history_id'] ?? null)->first();
            if (!$point) $this->fail('Bu geçmiş yer artık kullanılamıyor.');
        } elseif ($source === 'map') {
            if (!isset($data['place_latitude'], $data['place_longitude'])) $this->fail('Haritadan yaklaşık bir yer seç.');
            $point = (object) ['latitude' => $data['place_latitude'], 'longitude' => $data['place_longitude'], 'city_id' => $data['city_id']];
            $resolved = app(CityResolver::class)->resolve($point->latitude, $point->longitude);
            if ($resolved && (int)$resolved !== (int)$data['city_id']) $this->fail('Seçtiğin yerin şehrini seç.');
        } else {
            $point = LocationData::active($user);
            if (!$point || $point->accuracy > 5000 || !$point->city_id || (int)$point->city_id !== (int)$data['city_id']) {
                if (isset($data['location_source'])) $this->fail('Güncel konum hazır değil. Şehir veya haritadan yer seçebilirsin.');
                return null; // Backward-compatible attach_location.
            }
        }
        return ['city_id' => $point->city_id,
            'approx_latitude' => Geo::grid((float)$point->latitude, config('location.post_grid')),
            'approx_longitude' => Geo::grid((float)$point->longitude, config('location.post_grid')),
            'place_label' => DB::table('cities')->where('id', $point->city_id)->value('name').(isset($data['location_source']) ? ' · Yaklaşık bölge' : '')];
    }

    private function fail(string $message): never
    {
        throw ValidationException::withMessages(['location_source' => $message]);
    }
}
