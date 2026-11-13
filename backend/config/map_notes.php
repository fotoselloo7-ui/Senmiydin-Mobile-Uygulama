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
    // Dedicated placement grid (degrees). The writer deliberately picks the spot, so the snap must stay close
    // to it: 0.0005 deg is ~55 m north-south (~45 m east-west at 36 N), i.e. at most ~36 m from the chosen point.
    // Independent from location.post_grid (0.005, ~555 m) which protects ordinary posts. Notes already stored
    // on the coarser grid stay valid points; only newly created notes use this value.
    'location_grid' => (float) env('MAP_NOTE_LOCATION_GRID', 0.0005),
    // "Someone left a note near you": same city, recent location within this many meters of the (approximate) note.
    'nearby_notification_meters' => (int) env('MAP_NOTE_NEARBY_METERS', 1000),
    'nearby_notification_limit' => 200,
    'create_per_hour' => 8,
];
