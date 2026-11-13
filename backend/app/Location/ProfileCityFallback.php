<?php

namespace App\Location;

class ProfileCityFallback implements CityResolver
{
    public function resolve(float $latitude, float $longitude): ?int
    {
        // Compatibility null resolver; an unresolved coordinate must use manual city selection.
        return null;
    }
}
