<?php

namespace App\Memories;

use App\Location\Geo;
use App\Models\Memory;
use Illuminate\Support\Str;

/**
 * "Haritada Gör": the AREA of a memory for the app's own map, never a point somebody stood on.
 *
 * The centre is the point the owner picked, else the public centre of the picked place, else the middle of the city
 * (only that last one is rounded to a coarse 0.01° grid); it comes with a radius so the app can draw a circle. A memory
 * without any place / area has none (the action then does not appear).
 */
final class MapArea
{
    private const GRID = 0.01;

    /** A point the owner picked (or a known place) is shown where it is; only a whole city falls back to its coarse centre. */
    private const EXACT = 0.00001;

    private const EXACT_RADIUS = 200;

    private static ?array $features = null;

    /** @return array{lat:float,lng:float,radius_m:int}|null */
    public static function of(Memory $memory): ?array
    {
        $point = self::raw($memory);
        if ($point === null) {
            return null;
        }
        $grid = $point[2] <= self::EXACT_RADIUS ? self::EXACT : self::GRID;

        return ['lat' => Geo::grid($point[0], $grid), 'lng' => Geo::grid($point[1], $grid), 'radius_m' => $point[2]];
    }

    /**
     * Where the memory's photo marker stands on the map: the memory's own approximate point (already snapped to the
     * ~550 m memory grid), else the public centre of its place, else the middle of its city (~1 km grid). Never a raw
     * coordinate, and null for a memory without any place.
     *
     * @return array{lat:float,lng:float}|null
     */
    public static function marker(Memory $memory): ?array
    {
        $point = self::raw($memory);
        if ($point === null) {
            return null;
        }
        $grid = $point[2] <= self::EXACT_RADIUS ? self::EXACT : self::GRID;

        return ['lat' => Geo::grid($point[0], $grid), 'lng' => Geo::grid($point[1], $grid)];
    }

    /** @return array{0:float,1:float,2:int}|null latitude, longitude, radius of the area it stands for */
    private static function raw(Memory $memory): ?array
    {
        if ($memory->approx_latitude !== null && $memory->approx_longitude !== null) {
            return [(float) $memory->approx_latitude, (float) $memory->approx_longitude, 60];
        }
        if ($memory->place_id && $memory->place) {
            return [(float) $memory->place->latitude, (float) $memory->place->longitude, 150];
        }
        if ($memory->city_id && $memory->city && ($centre = self::cityCentre($memory->city)) !== null) {
            return [$centre[0], $centre[1], 5000];
        }

        return null;
    }

    /** @return array{0:float,1:float}|null */
    private static function cityCentre(\App\Models\City $city): ?array
    {
        if ($city->latitude !== null && $city->longitude !== null) {
            return [(float) $city->latitude, (float) $city->longitude];
        }
        $path = config('location.boundaries_file');
        if (! is_string($path) || ! is_readable($path)) {
            return null;
        }
        self::$features ??= json_decode((string) file_get_contents($path), true)['features'] ?? [];
        foreach (self::$features as $feature) {
            if (Str::slug($feature['properties']['name'] ?? '', '-', 'tr') === $city->slug && isset($feature['bbox'])) {
                [$west, $south, $east, $north] = $feature['bbox'];

                return [($south + $north) / 2, ($west + $east) / 2];
            }
        }

        return null;
    }
}
