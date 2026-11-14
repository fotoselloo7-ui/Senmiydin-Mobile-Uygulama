<?php

return [
    'login_failed' => 'Your sign-in details are incorrect.',
    'logged_out' => 'You have been signed out.',
    'forgot_sent' => 'If an account exists for this address, a reset code will be sent to your email.',
    'password_max_bytes' => 'Your password can be at most 72 bytes.',
    'password_invalid_char' => 'Your password contains an invalid character.',
    'validation' => [
        'required' => 'This field is required.',
        'email.email' => 'Enter a valid email address.',
        'email.unique' => 'This email address is already in use.',
        'username.unique' => 'This username is already taken.',
        'username.regex' => 'Usernames can contain letters, numbers, dots and underscores.',
        'username.min' => 'Username must be at least 3 characters.',
        'username.max' => 'Username can be at most 24 characters.',
        'birth_date.before_or_equal' => 'You must be at least :age years old to continue.',
        'birth_date.*' => 'Enter a valid date of birth.',
        'city_id.exists' => 'Choose a city from the list.',
        'accepted_terms.accepted' => 'You must accept the terms to continue.',
        'password.confirmed' => 'The new passwords do not match.',
        'password.different' => 'The new password must differ from the current one.',
        'password.min' => 'Password must be at least 10 characters.',
        'password.letters' => 'Password must contain at least one letter.',
        'password.numbers' => 'Password must contain at least one number.',
    ],
    'content_unavailable' => 'This content is no longer available.',
    'message_locked' => 'New messages can not be sent in this chat.',
];
