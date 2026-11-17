<?php

namespace App\Places;

use App\Location\BoundaryCityResolver;
use App\Location\CityResolver;

/**
 * Device coordinate -> area. The bundled boundaries answer first (they cover the original Turkish catalogue offline,
 * so nothing changes for existing users); any other coordinate is resolved through the place provider, cached per
 * ~1 km cell. An unresolved coordinate returns null and the manual choice stays in effect.
 */
final class PlaceCityResolver implements CityResolver
{
    public function __construct(private readonly BoundaryCityResolver $boundaries, private readonly PlaceDirectory $places) {}

    public function resolve(float $latitude, float $longitude): ?int
    {
        return $this->boundaries->resolve($latitude, $longitude)
            ?? (config('places.resolve_device_area') ? $this->places->areaIdForCoordinate($latitude, $longitude) : null);
    }
}
