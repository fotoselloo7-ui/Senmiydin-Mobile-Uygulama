<?php

return [
    'google' => [
        'audiences' => array_values(array_filter(array_map('trim', explode(',', env('GOOGLE_CLIENT_IDS', ''))))),
        'jwks' => 'https://www.googleapis.com/oauth2/v3/certs',
        'issuers' => ['https://accounts.google.com', 'accounts.google.com'],
    ],
    'apple' => [
        'audiences' => array_values(array_filter(array_map('trim', explode(',', env('APPLE_CLIENT_IDS', ''))))),
        'jwks' => 'https://appleid.apple.com/auth/keys',
        'issuers' => ['https://appleid.apple.com'],
        'team_id' => env('APPLE_TEAM_ID'),
        'key_id' => env('APPLE_KEY_ID'),
        'private_key_path' => env('APPLE_PRIVATE_KEY_PATH'),
    ],
];
