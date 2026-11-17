<?php

/**
 * Place search (city / district / neighbourhood, worldwide). The app only talks to this backend; which provider answers
 * is decided here, so it can be replaced without a code or app change.
 */
return [
    // nominatim = any Nominatim compatible server (the public OpenStreetMap one by default); none = search is off.
    'provider' => env('PLACES_PROVIDER', 'nominatim'),

    'nominatim' => [
        'url' => rtrim((string) env('PLACES_NOMINATIM_URL', 'https://nominatim.openstreetmap.org'), '/'),
        // The public server requires an identifying User-Agent and at most one request per second.
        'user_agent' => env('PLACES_USER_AGENT', 'SenMiydin/1.0 (+https://senmiydin.tr; destek@senmiydin.tr)'),
        'email' => env('PLACES_CONTACT_EMAIL'),
        'min_interval_ms' => (int) env('PLACES_MIN_INTERVAL_MS', 1100),
        'timeout' => (int) env('PLACES_TIMEOUT', 6),
        // How long a request may wait for its turn before the user is told to try again.
        'max_wait' => (int) env('PLACES_MAX_WAIT', 6),
    ],

    'limit' => 8,
    'cache_days' => (int) env('PLACES_CACHE_DAYS', 30),
    'token_days' => 7,
    // "Use my current location": the device coordinate is rounded to this grid (degrees, ~550 m) before it is sent to
    // the provider, enough to find the right neighbourhood without sending a precise position. Nothing is stored.
    'reverse_grid' => 0.005,
    // Device samples resolved to an area (outside the bundled boundaries) use a coarser ~1 km grid.
    'area_grid' => 0.01,
    // A coordinate outside the bundled city boundaries may be resolved to an area through the provider.
    'resolve_device_area' => (bool) env('PLACES_RESOLVE_DEVICE_AREA', true),
    'attribution' => '© OpenStreetMap',
];
