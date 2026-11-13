<?php

return [
    'avatar_disk' => env('AVATAR_DISK', 'local'),
    'post_media_disk' => env('POST_MEDIA_DISK', 'local'),
    'minimum_age' => 18,
    'connections' => ['friendship', 'encounters', 'chat', 'meet_people'],
];
