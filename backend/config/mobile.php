<?php

return [
    'avatar_disk' => env('AVATAR_DISK', 'local'),
    'post_media_disk' => env('POST_MEDIA_DISK', 'local'),
    // Single source of truth for the registration age gate. Production stays 18 until the 16+ safeguards in
    // docs/AGE_AND_STORE_READINESS.md are implemented; the value flows to backend validation, /app-config and the app UI.
    'minimum_age' => (int) env('MINIMUM_AGE', 18),
    'connections' => ['friendship', 'encounters', 'chat', 'meet_people'],
];
