<?php

namespace App\Places;

use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Nominatim (OpenStreetMap). The usage policy of the public server is enforced here for every call from every process:
 * one request at a time, at least PLACES_MIN_INTERVAL_MS apart, an identifying User-Agent, no bulk or grid queries.
 * Results are cached by the caller, and the app never searches while the user is still typing.
 */
final class NominatimProvider implements PlaceSearchProvider
{
    /**
     * Address levels a person may pick: from a province / state (city-states such as Berlin are rank 7) down to a
     * neighbourhood. No whole countries, no streets, no buildings.
     */
    private const MIN_RANK = 5;

    private const MAX_RANK = 22;

    public function search(string $query, string $locale, int $limit): array
    {
        $items = $this->call('/search', [
            'q' => $query, 'format' => 'jsonv2', 'addressdetails' => 1, 'layer' => 'address', 'dedupe' => 1,
            'limit' => min(20, $limit * 2), 'accept-language' => $locale,
        ]);

        return array_slice(array_values(array_filter(array_map($this->normalize(...), $items))), 0, $limit);
    }

    public function reverse(float $latitude, float $longitude, string $locale, int $zoom, bool $wait = true): ?array
    {
        $item = $this->call('/reverse', [
            'lat' => $latitude, 'lon' => $longitude, 'format' => 'jsonv2', 'addressdetails' => 1, 'layer' => 'address',
            'zoom' => $zoom, 'accept-language' => $locale,
        ], $wait);

        return isset($item['error']) ? null : $this->normalize($item);
    }

    public function lookup(array $ids, string $locale): array
    {
        if ($ids === []) {
            return [];
        }
        $items = $this->call('/lookup', [
            'osm_ids' => implode(',', array_slice($ids, 0, 50)), 'format' => 'jsonv2', 'addressdetails' => 1,
            'accept-language' => $locale,
        ]);
        $found = [];
        foreach ($items as $item) {
            if ($place = $this->normalize($item)) {
                $found[$place['id']] = $place;
            }
        }

        return $found;
    }

    private function call(string $path, array $query, bool $wait = true): array
    {
        $config = config('places.nominatim');
        if (filled($config['email'])) {
            $query['email'] = $config['email'];
        }
        $lock = Cache::lock('places:nominatim', 30);
        try {
            if ($wait) {
                $lock->block($config['max_wait']);
            } elseif (! $lock->get()) {
                throw new PlaceProviderUnavailable('busy');
            }
        } catch (LockTimeoutException) {
            throw new PlaceProviderUnavailable('busy');
        }
        try {
            $gap = $config['min_interval_ms'] - (microtime(true) - (float) Cache::get('places:nominatim:last', 0)) * 1000;
            if ($gap > 0) {
                usleep((int) ($gap * 1000));
            }
            try {
                $response = Http::withHeaders(['User-Agent' => $config['user_agent'], 'Accept' => 'application/json'])
                    ->timeout($config['timeout'])->connectTimeout(4)->get($config['url'].$path, $query);
            } finally {
                Cache::put('places:nominatim:last', microtime(true), 300);
            }
        } catch (\Throwable $error) {
            throw new PlaceProviderUnavailable($error->getMessage(), 0, $error);
        } finally {
            $lock->release();
        }
        if (! $response->successful() || ! is_array($response->json())) {
            throw new PlaceProviderUnavailable('status '.$response->status());
        }

        return $response->json();
    }

    /** One Nominatim result as a normalized place, or null when it is not a settlement / administrative area. */
    private function normalize(mixed $item): ?array
    {
        if (! is_array($item) || ! isset($item['osm_type'], $item['osm_id'], $item['lat'], $item['lon'])) {
            return null;
        }
        $address = array_filter((array) ($item['address'] ?? []), 'is_string');
        $rank = (int) ($item['place_rank'] ?? 30);
        $category = $item['category'] ?? $item['class'] ?? '';
        $code = strtolower($address['country_code'] ?? '');
        if (! in_array($category, ['boundary', 'place'], true) || $rank < self::MIN_RANK || $rank > self::MAX_RANK
            || strlen($code) !== 2 || ! isset($address['country'])) {
            return null;
        }
        $type = (string) ($item['addresstype'] ?? $item['type'] ?? 'place');
        $name = trim((string) ($item['name'] ?? '')) ?: trim((string) ($address[$type] ?? ''));
        if ($name === '') {
            return null;
        }
        $pick = function (string ...$keys) use ($address): ?string {
            foreach ($keys as $key) {
                if (isset($address[$key]) && trim($address[$key]) !== '') {
                    return mb_substr(trim($address[$key]), 0, 120);
                }
            }

            return null;
        };
        // "region" (for example a geographic region of Türkiye) is not an administrative level people recognise.
        $admin1 = $pick('state', 'province');
        $admin2 = $pick('county', 'state_district') ?? (isset($address['state'], $address['province']) ? $pick('province') : null);
        $town = $pick('city', 'town');
        $village = $pick('village', 'hamlet');
        // A village is its own locality; a municipality / township only when there is nothing smaller.
        $locality = $town ?? $village ?? $pick('municipality');
        // In Türkiye a "mahalle" is mapped as a village inside its town: it is the part below the locality.
        $suburb = $pick('suburb', 'city_district', 'borough') ?? ($town !== null ? $village : null);
        $neighbourhood = $pick('neighbourhood', 'quarter');

        return [
            'provider' => 'osm',
            'id' => strtoupper($item['osm_type'][0]).$item['osm_id'],
            'type' => mb_substr($type, 0, 30),
            'rank' => $rank,
            'name' => mb_substr($name, 0, 120),
            'country_code' => $code,
            'country' => mb_substr($address['country'], 0, 100),
            'admin1' => $admin1, 'admin2' => $admin2, 'locality' => $locality,
            'suburb' => $suburb, 'neighbourhood' => $neighbourhood,
            // The public centre of the place itself, ~100 m.
            'lat' => round((float) $item['lat'], 3), 'lng' => round((float) $item['lon'], 3),
        ];
    }
}
