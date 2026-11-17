<?php

namespace App\Places;

use App\Models\City;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Areas are the rows of `cities`: the unit a feed, the map and "nearby" are scoped to (a city, town or district).
 * The Turkish catalogue that existed before global places stays as it is; every other area is created the first time
 * somebody picks a place inside it. An area is identified by a language independent key, never by its display name.
 */
final class Areas
{
    public static function slug(?string $value): string
    {
        $value = trim((string) $value);
        if ($value === '') {
            return '';
        }
        $slug = Str::slug($value, '-', 'tr');

        return substr($slug !== '' ? $slug : sha1(mb_strtolower($value)), 0, 55);
    }

    /** The area a normalized place belongs to: its city / town, otherwise the smallest administrative unit it has. */
    public static function name(array $place): ?string
    {
        return $place['locality'] ?? $place['admin2'] ?? $place['admin1'] ?? null;
    }

    /** country | admin1 | (empty) | name. Province level places (no locality) use their own name twice, like the old rows. */
    public static function key(array $place): ?string
    {
        $name = self::name($place);
        if ($name === null) {
            return null;
        }
        // The county is not part of the key: one city can span several (New York City has five), and a part of the
        // city must land in the same area as the city itself. The empty slot keeps the key format of older rows.
        return implode('|', [$place['country_code'], self::slug($place['admin1'] ?? $name), '', self::slug($name)]);
    }

    /**
     * The area a place belongs to: ['key' => ..., 'name' => display name or null for "the place's own locality"].
     *
     * In Türkiye the original catalogue stays the feed structure: a place belongs to the catalogue row of its town
     * when there is one (Alanya), otherwise to the row of its province (Kadıköy -> İstanbul, Konyaaltı -> Antalya), so
     * new and existing people of one city keep meeting in one feed. Elsewhere the city / town is the area.
     */
    public static function areaFor(array $place): ?array
    {
        if (($place['country_code'] ?? '') === 'tr') {
            foreach ([$place['locality'] ?? null, $place['admin2'] ?? null, $place['admin1'] ?? null, $place['name'] ?? null] as $candidate) {
                $row = $candidate ? self::legacy($candidate) : null;
                if ($row) {
                    return ['key' => $row->area_key, 'name' => $row->name];
                }
            }
        }
        $key = self::key($place);

        return $key === null ? null : ['key' => $key, 'name' => null];
    }

    private static function legacy(string $name): ?object
    {
        static $rows = null;
        $rows ??= DB::table('cities')->whereNull('provider')->where('country_code', 'tr')->whereNotNull('area_key')
            ->get(['slug', 'name', 'area_key'])->keyBy('slug');

        return $rows[self::slug($name)] ?? null;
    }

    /**
     * Gives the catalogue rows that predate global places the same description as provider areas, without inventing
     * provider ids for them: they are Turkish provinces, plus Alanya, which is a district of Antalya.
     */
    public static function describeLegacy(): void
    {
        foreach (DB::table('cities')->whereNull('area_key')->whereNull('provider')->get(['id', 'name', 'slug']) as $city) {
            $admin1 = $city->slug === 'alanya' ? 'Antalya' : $city->name;
            $key = implode('|', ['tr', self::slug($admin1), '', self::slug($city->name)]);
            if (DB::table('cities')->where('area_key', $key)->exists()) {
                continue;
            }
            DB::table('cities')->where('id', $city->id)->update([
                'area_key' => $key, 'country_code' => 'tr', 'country_name' => 'Türkiye', 'admin1' => $admin1,
            ]);
        }
    }

    /**
     * @param  array{key:string,area:string,country_code:string,country:string,admin1:?string,admin2:?string,lat:float,lng:float,id?:?string}  $area
     */
    public static function findOrCreate(array $area, string $locale): City
    {
        $label = ['name' => $area['area'], 'admin1' => $area['admin1'], 'country' => $area['country']];
        $city = City::where('area_key', $area['key'])->first();
        if (! $city) {
            try {
                $city = City::create([
                    'name' => mb_substr($area['area'], 0, 100), 'slug' => self::freeSlug($area), 'is_active' => true,
                    'area_key' => $area['key'], 'provider' => 'osm', 'provider_place_id' => $area['id'] ?? null,
                    'country_code' => $area['country_code'], 'country_name' => $area['country'],
                    'admin1' => $area['admin1'], 'admin2' => $area['admin2'],
                    'latitude' => $area['lat'], 'longitude' => $area['lng'], 'labels' => [$locale => $label],
                ]);
                \Illuminate\Support\Facades\Cache::forget('catalog:cities:v1');

                return $city;
            } catch (UniqueConstraintViolationException) {
                $city = City::where('area_key', $area['key'])->firstOrFail();
            }
        }
        $labels = $city->labels ?? [];
        if (! isset($labels[$locale])) {
            $city->forceFill(['labels' => $labels + [$locale => $label]])->save();
        }

        return $city;
    }

    /**
     * May a point be used with this area? The bundled boundaries only know the original catalogue, so their answer
     * decides for those rows; a provider area accepts any point within reach of its own centre.
     */
    public static function accepts(int $cityId, float $latitude, float $longitude, ?int $resolved): bool
    {
        if ($resolved === null || $resolved === $cityId) {
            return true;
        }
        $city = DB::table('cities')->where('id', $cityId)->first(['provider', 'latitude', 'longitude']);
        if (! $city || $city->provider === null) {
            return false;
        }

        return $city->latitude === null
            || \App\Location\Geo::distance($latitude, $longitude, (float) $city->latitude, (float) $city->longitude) <= 80000;
    }

    private static function freeSlug(array $area): string
    {
        $base = implode('-', array_unique(array_filter([self::slug($area['area']), self::slug($area['admin1']), $area['country_code']])));
        $base = substr($base, 0, 90);
        for ($slug = $base, $i = 2; DB::table('cities')->where('slug', $slug)->exists(); $i++) {
            $slug = $base.'-'.$i;
        }

        return $slug;
    }
}
