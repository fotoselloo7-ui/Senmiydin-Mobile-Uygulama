<?php

return [
    'driver' => env('PUSH_DRIVER', 'log'),
    'project' => env('FCM_PROJECT_ID'),
    'credentials' => env('FCM_CREDENTIALS'),
];
