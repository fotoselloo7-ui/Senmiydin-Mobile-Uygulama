<?php

namespace App\Places;

/**
 * A source of real places (OpenStreetMap data today). Everything else in the app sees only the normalized arrays this
 * returns, never the provider URL or response format, so the provider can be replaced through configuration.
 *
 * A normalized place:
 *   provider, id, type, rank, name, country_code, country, admin1, admin2, locality, suburb, neighbourhood, lat, lng
 */
interface PlaceSearchProvider
{
    /** @return list<array<string,mixed>> settlements and administrative areas only, best match first */
    public function search(string $query, string $locale, int $limit): array;

    /** The settlement / area around a coordinate; null when there is none. $wait = false never queues behind other calls. */
    public function reverse(float $latitude, float $longitude, string $locale, int $zoom, bool $wait = true): ?array;

    /**
     * The same places in another language.
     *
     * @param  list<string>  $ids
     * @return array<string,array<string,mixed>> keyed by place id
     */
    public function lookup(array $ids, string $locale): array;
}
