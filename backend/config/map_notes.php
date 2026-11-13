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
    // "Someone left a note near you": same city, recent location within this many meters of the (approximate) note.
    'nearby_notification_meters' => (int) env('MAP_NOTE_NEARBY_METERS', 1000),
    'nearby_notification_limit' => 200,
    'create_per_hour' => 8,
];
