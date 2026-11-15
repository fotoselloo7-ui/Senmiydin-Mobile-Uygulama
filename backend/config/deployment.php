<?php

return [
    'operator_name' => env('OPERATOR_NAME'),
    'operator_contact' => env('OPERATOR_CONTACT'),
    'legal_reviewed' => env('LEGAL_REVIEWED', false),
    'scheduler_configured' => env('SCHEDULER_CONFIGURED', false),
    'worker_configured' => env('QUEUE_WORKER_CONFIGURED', false),
    'allow_mail_relay' => env('MAIL_ALLOW_UNAUTHENTICATED_RELAY', false),
    'final_brand' => env('BRAND_FINAL', false),
    // Deep links: comma separated SHA-256 signing fingerprints of the release (and Play App Signing) certificate, and the
    // Apple Team ID. The verification files are only served when these are real values; nothing is guessed.
    'android_app_link_sha256' => env('ANDROID_APP_LINK_SHA256'),
    'apple_team_id' => env('APPLE_TEAM_ID'),
];
