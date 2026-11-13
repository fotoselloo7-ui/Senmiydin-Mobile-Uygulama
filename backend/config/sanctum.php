<?php

return [
    'guard' => [],
    'expiration' => (int) env('SANCTUM_EXPIRATION', 43200),
    'token_prefix' => env('SANCTUM_TOKEN_PREFIX', ''),
];
