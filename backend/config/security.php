<?php

return [
    // Only addresses of proxies that actually terminate TLS for this application.
    'trusted_proxies' => array_values(array_filter(array_map('trim', explode(',', env('TRUSTED_PROXIES', ''))))),
    'cors_origins' => array_values(array_filter(array_map('trim', explode(',', env('CORS_ALLOWED_ORIGINS', 'https://senmiydin.tr'))))),
];
