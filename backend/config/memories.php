<?php

return [
    // At most this many photos per memory (0–5).
    'max_media' => 5,
    'max_body' => 2000,
    // Profile "Anılar" list: 20 per page, newest event first.
    'page_size' => 20,
    // Longest edge of the list thumbnail the profile loads instead of the full photo.
    'thumb_edge' => 480,
    // A memory the owner deleted while it carried a report, and one an admin removed, stays reviewable for this many
    // days; after that it (and its files) is purged for good. Everything else is erased at once.
    'retention_days' => 30,
    // A memory is kept exactly where its owner put the pin (5 decimals, ~1 m: the column precision). Who may see it is
    // decided by its visibility (private / followers / public / area), not by blurring the point.
    'location_grid' => (float) env('MEMORY_LOCATION_GRID', 0.00001),
    'create_per_hour' => 30,
];
