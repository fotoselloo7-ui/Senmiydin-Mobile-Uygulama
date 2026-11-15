<?php

return [
    'url' => rtrim(env('PUBLIC_SITE_URL', 'https://senmiydin.com'), '/'),
    'support_email' => env('PUBLIC_SUPPORT_EMAIL'),
    // AdMob publisher id (pub-0000000000000000): published at /app-ads.txt so ad requests from the apps can be verified.
    'admob_publisher_id' => env('ADMOB_PUBLISHER_ID'),
];
