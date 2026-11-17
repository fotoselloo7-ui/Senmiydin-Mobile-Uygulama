<?php

namespace App\Places;

/** PLACES_PROVIDER=none: search answers with nothing; places that were already chosen keep working. */
final class NoPlaceProvider implements PlaceSearchProvider
{
    public function search(string $query, string $locale, int $limit): array
    {
        return [];
    }

    public function reverse(float $latitude, float $longitude, string $locale, int $zoom, bool $wait = true): ?array
    {
        return null;
    }

    public function lookup(array $ids, string $locale): array
    {
        return [];
    }
}
