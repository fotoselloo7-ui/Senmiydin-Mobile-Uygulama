<?php

namespace App\Location;

use App\Models\City;
use Illuminate\Support\Str;

final class BoundaryCityResolver implements CityResolver
{
    private static array $datasets = [];

    public function resolve(float $latitude, float $longitude): ?int
    {
        if (config('location.city_provider') !== 'boundaries') return null;
        $path = config('location.boundaries_file');
        if (!is_string($path) || !is_readable($path)) return null;
        $features = self::$datasets[$path] ??= json_decode(file_get_contents($path), true)['features'] ?? [];
        $found = [];
        foreach ($features as $feature) {
            [$west, $south, $east, $north] = $feature['bbox'];
            if ($longitude < $west || $longitude > $east || $latitude < $south || $latitude > $north) continue;
            $polygons = $feature['geometry']['type'] === 'Polygon'
                ? [$feature['geometry']['coordinates']] : $feature['geometry']['coordinates'];
            foreach ($polygons as $rings) {
                if (! $this->inside($longitude, $latitude, $rings[0])) continue;
                foreach (array_slice($rings, 1) as $hole) {
                    if ($this->inside($longitude, $latitude, $hole)) continue 2;
                }
                $found[$feature['properties']['priority']][] = Str::slug($feature['properties']['name'], '-', 'tr');
                break;
            }
        }
        if (!$found) return null;
        krsort($found);
        $names = reset($found);
        // Simplified boundary overlaps / edges are ambiguous, never guess.
        if (count($names) !== 1) return null;
        return City::where('slug', $names[0])->where('is_active', true)->value('id');
    }

    private function inside(float $x, float $y, array $ring): bool
    {
        $inside = false;
        for ($i = 0, $j = count($ring) - 1; $i < count($ring); $j = $i++) {
            [$xi, $yi] = $ring[$i]; [$xj, $yj] = $ring[$j];
            if (($yi > $y) !== ($yj > $y) && $x < ($xj - $xi) * ($y - $yi) / ($yj - $yi) + $xi) $inside = !$inside;
        }
        return $inside;
    }
}
