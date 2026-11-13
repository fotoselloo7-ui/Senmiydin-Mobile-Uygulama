<?php

namespace App\Location;

use Illuminate\Support\Facades\DB;

final class Geo
{
    private const EARTH_METERS = 6371008.8;

    public static function distance(float $lat, float $lng, float $otherLat, float $otherLng): float
    {
        $a = sin(deg2rad($otherLat - $lat) / 2) ** 2
            + cos(deg2rad($lat)) * cos(deg2rad($otherLat)) * sin(deg2rad($otherLng - $lng) / 2) ** 2;

        return 2 * self::EARTH_METERS * asin(sqrt(max(0, min(1, $a))));
    }

    /** Column names are supplied only by application code. */
    public static function expression(object $origin, string $lat, string $lng): array
    {
        $coordinates = [(float) $origin->latitude, (float) $origin->longitude];
        $connection = DB::connection();
        if ($connection->getDriverName() === 'sqlite') {
            // This PHP build lacks SQLite's optional math functions.
            $connection->getPdo()->sqliteCreateFunction('geo_distance', static fn ($a, $b, $c, $d) => $c === null || $d === null ? null : self::distance($a, $b, $c, $d), 4);

            return ["geo_distance(?, ?, $lat, $lng)", $coordinates];
        }

        // MariaDB and MySQL both support the SQL trigonometric functions.
        return [
            '12742017.6 * ASIN(SQRT(LEAST(1, POWER(SIN(RADIANS('.$lat.' - ?) / 2), 2)'
                .' + COS(RADIANS('.$lat.')) * POWER(SIN(RADIANS('.$lng.' - ?) / 2), 2) * COS(RADIANS(?)))))',
            [...$coordinates, $coordinates[0]],
        ];
    }

    public static function bound($query, object $origin, int $radius, string $lat, string $lng): void
    {
        $latitude = (float) $origin->latitude;
        $longitude = (float) $origin->longitude;
        $degrees = rad2deg($radius / self::EARTH_METERS) + 0.00001;
        $query->whereBetween($lat, [$latitude - $degrees, $latitude + $degrees]);
        $edge = abs($latitude) + $degrees;
        if ($edge >= 90) {
            return;
        }
        $delta = $degrees / cos(deg2rad($edge));
        if ($delta >= 180) {
            return;
        }
        $min = $longitude - $delta;
        $max = $longitude + $delta;
        if ($min < -180) {
            $query->where(fn ($box) => $box->where($lng, '<=', $max)->orWhere($lng, '>=', $min + 360));
        } elseif ($max > 180) {
            $query->where(fn ($box) => $box->where($lng, '>=', $min)->orWhere($lng, '<=', $max - 360));
        } else {
            $query->whereBetween($lng, [$min, $max]);
        }
    }

    public static function grid(float $coordinate, float $step): float
    {
        return round(round($coordinate / $step) * $step, 5);
    }

    public static function publicDistance(mixed $meters): ?int
    {
        return $meters === null ? null : max(100, (int) (round($meters / 100) * 100));
    }
}
