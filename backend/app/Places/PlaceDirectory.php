<?php

namespace App\Places;

use App\Models\Place;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The single entry point for places: search, "where am I" and turning a chosen result into a stored place.
 *
 * Search results are not written to the database. Each result carries a signed token; only when somebody actually
 * chooses a result is it stored (`resolve`), together with the area it belongs to. Provider answers are cached, so the
 * same query or the same ~1 km cell never reaches the provider twice within the cache period.
 */
final class PlaceDirectory
{
    public function __construct(private readonly PlaceSearchProvider $provider) {}

    /** @return list<array{token:string,name:string,context:string,label:string,type:string,country_code:string}> */
    public function search(string $query, string $locale, ?string $country = null): array
    {
        $query = self::cleanQuery($query);
        if (mb_strlen($query) < 2) {
            return [];
        }
        $key = 'places:q:'.$locale.':'.sha1(mb_strtolower($query));
        $places = Cache::get($key);
        if (! is_array($places)) {
            $places = $this->withAreaKeys($this->provider->search($query, $locale, config('places.limit') + 4), $locale);
            // An empty answer may only mean "not mapped yet": it is remembered for a day, real answers much longer.
            Cache::put($key, $places, now()->addDays($places === [] ? 1 : config('places.cache_days')));
        }
        $items = [];
        foreach ($places as $place) {
            $item = $this->item($place, $locale);
            // The same place is often mapped twice (a boundary and a point); the first, better ranked one is kept.
            $items[mb_strtolower($item['name'].'|'.$item['context'])] ??= $item;
        }
        $items = array_values($items);
        if ($country !== null) {
            // Places in the person's own country first; the provider order is kept inside each group.
            usort($items, fn ($a, $b) => ($b['country_code'] === $country) <=> ($a['country_code'] === $country));
        }

        return array_slice($items, 0, config('places.limit'));
    }

    /** The neighbourhood / suburb level place around a device coordinate, which is rounded to ~550 m first. */
    public function reverse(float $latitude, float $longitude, string $locale): ?array
    {
        [$latitude, $longitude] = self::cell($latitude, $longitude, config('places.reverse_grid'));
        $key = "places:r:$locale:$latitude:$longitude";
        $place = Cache::get($key);
        if ($place === null) {
            $found = $this->provider->reverse($latitude, $longitude, $locale, 14);
            $place = $found ? ($this->withAreaKeys([$found], $locale)[0] ?? false) : false;
            Cache::put($key, $place, now()->addDays($place ? config('places.cache_days') : 1));
        }

        return $place ? $this->item($place, $locale) : null;
    }

    /** Stores the chosen search result (and its area, when new) and returns the place. */
    public function resolve(string $token): Place
    {
        $data = $this->open($token);

        return DB::transaction(function () use ($data) {
            $locale = $data['lc'];
            $city = Areas::findOrCreate([
                'key' => $data['k'], 'area' => $data['an'], 'country_code' => $data['cc'], 'country' => $data['c'],
                'admin1' => $data['a1'], 'admin2' => $data['a2'], 'lat' => $data['la'], 'lng' => $data['lo'],
                // The area gets a provider id only when the chosen place is the area itself.
                'id' => $data['n'] === $data['an'] ? $data['id'] : null,
            ], $locale);
            $text = Place::describe(['name' => $data['n'], 'suburb' => $data['s'], 'locality' => $data['l'],
                'admin1' => $data['a1'], 'country' => $data['c']]);
            $place = Place::where(['provider' => $data['p'], 'provider_place_id' => $data['id']])->first();
            if (! $place) {
                try {
                    return Place::create([
                        'provider' => $data['p'], 'provider_place_id' => $data['id'], 'city_id' => $city->id,
                        'type' => $data['t'], 'name' => $data['n'], 'country_code' => $data['cc'], 'country_name' => $data['c'],
                        'admin1' => $data['a1'], 'admin2' => $data['a2'], 'locality' => $data['l'], 'suburb' => $data['s'],
                        'neighbourhood' => $data['nb'], 'display_name' => mb_substr($text['label'], 0, 255),
                        'latitude' => $data['la'], 'longitude' => $data['lo'], 'labels' => [$locale => $text],
                    ]);
                } catch (UniqueConstraintViolationException) {
                    $place = Place::where(['provider' => $data['p'], 'provider_place_id' => $data['id']])->firstOrFail();
                }
            }
            if (! isset($place->labels[$locale])) {
                $place->forceFill(['labels' => ($place->labels ?? []) + [$locale => $text]])->save();
            }

            return $place;
        });
    }

    /**
     * The area of a device coordinate that the bundled boundaries do not cover. Never waits behind other provider
     * calls and never throws: an unresolved coordinate simply keeps the manual choice.
     */
    public function areaIdForCoordinate(float $latitude, float $longitude): ?int
    {
        [$latitude, $longitude] = self::cell($latitude, $longitude, config('places.area_grid'));
        $key = "places:cell:$latitude:$longitude";
        $cached = Cache::get($key);
        if ($cached !== null) {
            return $cached ?: null;
        }
        try {
            $found = $this->provider->reverse($latitude, $longitude, 'en', 10, wait: false);
        } catch (PlaceProviderUnavailable) {
            return null;
        }
        $id = 0;
        if ($found && ($area = Areas::areaFor($found)) !== null && ($name = $area['name'] ?? Areas::name($found)) !== null) {
            $id = Areas::findOrCreate([
                'key' => $area['key'], 'area' => $name, 'country_code' => $found['country_code'],
                'country' => $found['country'], 'admin1' => $found['admin1'], 'admin2' => $found['admin2'],
                'lat' => $found['lat'], 'lng' => $found['lng'], 'id' => $found['name'] === $name ? $found['id'] : null,
            ], 'en')->id;
        }
        Cache::put($key, $id, now()->addDays($id ? config('places.cache_days') : 1));

        return $id ?: null;
    }

    public static function cleanQuery(string $query): string
    {
        return mb_substr(trim(preg_replace('/\s+/u', ' ', $query) ?? ''), 0, 80);
    }

    /** @return array{0:float,1:float} */
    private static function cell(float $latitude, float $longitude, float $grid): array
    {
        return [round(round($latitude / $grid) * $grid, 4), round(round($longitude / $grid) * $grid, 4)];
    }

    /**
     * Adds the language independent area key to each place and drops places without an area. Names outside Türkiye
     * can differ between languages (Londra / London), so their key is always taken from the English names.
     */
    private function withAreaKeys(array $places, string $locale): array
    {
        $foreign = $locale === 'en' ? [] : array_values(array_filter($places, fn ($place) => $place['country_code'] !== 'tr'));
        $english = [];
        if ($foreign !== []) {
            try {
                $english = $this->provider->lookup(array_column($foreign, 'id'), 'en');
            } catch (PlaceProviderUnavailable) {
                // The place can still be chosen; its area key then comes from the names in the request language.
            }
        }
        $ready = [];
        foreach ($places as $place) {
            $area = Areas::areaFor($english[$place['id']] ?? $place);
            $name = $area['name'] ?? Areas::name($place);
            if ($area !== null && $name !== null) {
                $ready[] = $place + ['key' => $area['key'], 'area' => $name];
            }
        }

        return $ready;
    }

    private function item(array $place, string $locale): array
    {
        $text = Place::describe(['name' => $place['name'], 'suburb' => $place['suburb'], 'locality' => $place['locality'],
            'admin1' => $place['admin1'], 'country' => $place['country']]);
        $payload = json_encode([
            'p' => $place['provider'], 'id' => $place['id'], 't' => $place['type'], 'n' => $place['name'],
            'cc' => $place['country_code'], 'c' => $place['country'], 'a1' => $place['admin1'], 'a2' => $place['admin2'],
            'l' => $place['locality'], 's' => $place['suburb'], 'nb' => $place['neighbourhood'],
            'la' => $place['lat'], 'lo' => $place['lng'], 'k' => $place['key'], 'an' => $place['area'],
            'lc' => $locale, 'exp' => now()->addDays(config('places.token_days'))->timestamp,
        ], JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
        $body = rtrim(strtr(base64_encode($payload), '+/', '-_'), '=');

        return ['token' => $body.'.'.self::sign($body), 'type' => $place['type'], 'country_code' => $place['country_code']] + $text;
    }

    private function open(string $token): array
    {
        [$body, $signature] = array_pad(explode('.', $token, 2), 2, '');
        $data = hash_equals(self::sign($body), $signature)
            ? json_decode((string) base64_decode(strtr($body, '-_', '+/'), true), true) : null;
        if (! is_array($data) || ($data['exp'] ?? 0) < now()->timestamp) {
            throw ValidationException::withMessages(['place' => 'Bu yer artık seçilemiyor. Yeniden ara.']);
        }

        return $data;
    }

    private static function sign(string $body): string
    {
        return hash_hmac('sha256', 'place|'.$body, (string) config('app.key'));
    }
}
