<?php

return [
    'avatar_disk' => env('AVATAR_DISK', 'local'),
    'post_media_disk' => env('POST_MEDIA_DISK', 'local'),
    // Single source of truth for the registration age gate. 16 is the production minimum now that the TEEN / ADULT
    // age-band separation (App\Safety\AgeSafety, docs/AGE_AND_STORE_READINESS.md) is enforced server-side; the value
    // flows to backend validation, /app-config and the app UI.
    'minimum_age' => (int) env('MINIMUM_AGE', 16),
    // Voice messages (AAC in an MP4/M4A container). One place for the limits the app and the server share.
    'voice' => [
        'max_seconds' => (int) env('VOICE_MAX_SECONDS', 120),
        'min_ms' => 1000,
        // 120 s of 64 kbit/s AAC is ~1 MB; this leaves room for higher bit rates and container overhead.
        'max_bytes' => (int) env('VOICE_MAX_BYTES', 3 * 1024 * 1024),
        'brands' => ['M4A ', 'M4B ', 'mp41', 'mp42', 'isom', 'iso2', 'iso5', 'dash'],
    ],
    'connections' => ['friendship', 'encounters', 'chat', 'meet_people'],
];
