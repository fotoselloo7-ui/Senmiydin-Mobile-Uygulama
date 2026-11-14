<?php

return [
    'avatar_disk' => env('AVATAR_DISK', 'local'),
    'post_media_disk' => env('POST_MEDIA_DISK', 'local'),
    // Single source of truth for the registration age gate. 16 is the production minimum now that the TEEN / ADULT
    // age-band separation (App\Safety\AgeSafety, docs/AGE_AND_STORE_READINESS.md) is enforced server-side; the value
    // flows to backend validation, /app-config and the app UI.
    'minimum_age' => (int) env('MINIMUM_AGE', 16),
    'connections' => ['friendship', 'encounters', 'chat', 'meet_people'],
];
