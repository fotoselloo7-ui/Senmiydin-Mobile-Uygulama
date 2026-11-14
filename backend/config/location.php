<?php

return [
    'active_minutes' => 30,
    'minimum_movement_meters' => 150,
    'refresh_seconds' => 600,
    'history_days' => max(1, (int) env('LOCATION_HISTORY_DAYS', 7)),
    'history_grid' => 0.005,
    'post_grid' => 0.005,
    'match_radius' => 650,
    'city_provider' => env('LOCATION_CITY_PROVIDER', 'boundaries'),
    'boundaries_file' => resource_path('geography/cities.geojson'),
    // "Yakınında yeni bir paylaşım var": notify people who are near a new post's place right now.
    'current_nearby' => [
        'radius_meters' => (int) env('NEARBY_POST_RADIUS_METERS', 1000),
        'freshness_minutes' => (int) env('NEARBY_POST_FRESHNESS_MINUTES', 30),
        'max_recipients' => 200,
    ],
    // Private location messages are snapped to this grid (degrees, ~55 m) before they are stored.
    'message_grid' => (float) env('MESSAGE_LOCATION_GRID', 0.0005),
    'matching' => [
        'strong_meters' => 500, 'strong_seconds' => 3600, 'strong_score' => 90,
        'medium_meters' => 2000, 'medium_seconds' => 14400, 'medium_score' => 60,
        'weak_meters' => 5000, 'weak_score' => 25,
        'travel_seconds' => 3600,
        'boost_hours' => 8, 'boost_days' => 7,
    ],
];
