<?php

return [
    'operator_name' => env('OPERATOR_NAME'),
    'operator_contact' => env('OPERATOR_CONTACT'),
    'legal_reviewed' => env('LEGAL_REVIEWED', false),
    'scheduler_configured' => env('SCHEDULER_CONFIGURED', false),
    'worker_configured' => env('QUEUE_WORKER_CONFIGURED', false),
    'allow_mail_relay' => env('MAIL_ALLOW_UNAUTHENTICATED_RELAY', false),
    'final_brand' => env('BRAND_FINAL', false),
];
