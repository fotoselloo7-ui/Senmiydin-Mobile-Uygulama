<?php

namespace Tests\Support;

/**
 * Finds the Turkish sentences the mobile API can send to a person: every single quoted PHP string in the API code
 * that reads like a sentence (has a space and ends with . ! ? or …). Admin panel, website, mail and console code is
 * not part of the mobile API and is left out.
 */
final class ApiSentences
{
    private const ROOTS = ['Http/Controllers', 'Http/Middleware', 'Http/Resources', 'Location', 'Places', 'Auth', 'Safety', 'Encounters',
        'Media', 'MapNotes', 'Notifications', 'Sharing', 'Accounts', 'Policies', 'Models', 'Exceptions'];

    private const SKIP = ['/Admin/', 'WebsiteController', 'PublicShareController', 'sync-conflict', 'Notifications/PasswordResetCode'];

    /** @return array<string,string> sentence => file */
    public static function all(): array
    {
        $found = [];
        foreach (self::ROOTS as $root) {
            $directory = app_path($root);
            if (! is_dir($directory)) {
                continue;
            }
            foreach (new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($directory)) as $file) {
                $path = str_replace('\\', '/', (string) $file);
                if (! str_ends_with($path, '.php') || array_filter(self::SKIP, fn ($skip) => str_contains($path, $skip))) {
                    continue;
                }
                foreach (token_get_all((string) file_get_contents($path)) as $token) {
                    if (! is_array($token) || $token[0] !== T_CONSTANT_ENCAPSED_STRING || $token[1][0] !== "'") {
                        continue;
                    }
                    $text = stripcslashes(substr($token[1], 1, -1));
                    if (preg_match('/\s/u', $text) && preg_match('/[.!?…]$/u', $text) && preg_match('/\p{L}{3}/u', $text)
                        && ! preg_match('/^(select|update|delete|insert|\(|[a-z_]+\.)/i', $text)) {
                        $found[$text] ??= basename($path);
                    }
                }
            }
        }

        return $found;
    }
}
