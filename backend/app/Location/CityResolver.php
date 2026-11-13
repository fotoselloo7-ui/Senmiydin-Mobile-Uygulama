<?php

namespace App\Location;

interface CityResolver
{
    public function resolve(float $latitude, float $longitude): ?int;
}
