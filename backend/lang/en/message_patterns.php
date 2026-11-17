<?php

/**
 * English texts for Turkish API sentences that carry a number or a name, as regular expression => replacement.
 * ApiResponse tries these after the exact sentences in messages.php.
 */
return [
    '/^En fazla (\d+) fotoğraf ekleyebilirsin\.$/u' => 'You can add up to $1 photos.',
    '/^En fazla (\d+) koleksiyon oluşturabilirsin\.$/u' => 'You can create up to $1 collections.',
    '/^Koleksiyon adı en fazla (\d+) karakter olabilir\.$/u' => 'A collection name can be up to $1 characters.',
    '/^Notun en fazla (\d+) karakter olabilir\.$/u' => 'Your note can be up to $1 characters.',
    '/^Yanıtın en fazla (\d+) karakter olabilir\.$/u' => 'Your reply can be up to $1 characters.',
    '/^(.+) · Yaklaşık bölge$/u' => '$1 · Approximate area',
];
