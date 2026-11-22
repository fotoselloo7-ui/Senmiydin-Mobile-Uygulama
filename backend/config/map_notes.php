<?php

return [
    // FINAL V1 decision: every note is publicly visible for exactly 7 days from creation. Replies never extend it.
    'ttl_days' => 7,
    // Soft-deleted / expired rows stay available to admins for this many days, then are purged for good.
    'retention_days' => 30,
    'max_body' => 700,
    'max_reply' => 500,
    'page_size' => 20,
    'reply_page_size' => 20,
    'max_markers' => 150,
    // A note is left exactly where the writer put the pin: the grid is the column precision (5 decimals, ~1 m).
    // Notes created earlier on the coarser 0.0005 grid stay valid points. (location.post_grid still protects ordinary posts.)
    'location_grid' => (float) env('MAP_NOTE_LOCATION_GRID', 0.00001),
    // Admin announcements ("Haritada Gör" areas) stay on the coarse 0.0005 deg grid (~36 m).
    'announcement_grid' => (float) env('MAP_ANNOUNCEMENT_GRID', 0.0005),
    // "Someone left a note near you": same city, recent location within this many meters of the (approximate) note.
    'nearby_notification_meters' => (int) env('MAP_NOTE_NEARBY_METERS', 1000),
    'nearby_notification_limit' => 200,
    'create_per_hour' => 8,
];
