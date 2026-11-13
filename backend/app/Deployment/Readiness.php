<?php

namespace App\Deployment;

use App\Administration\Settings;
use App\Website\Pages;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

final class Readiness
{
    public function checks(): array
    {
        $rows = [];
        $add = function (string $name, bool $ok, string $category = 'configuration', string $missing = 'MISSING') use (&$rows): void {
            $rows[] = ['check' => $name, 'status' => $ok ? 'OK' : $missing, 'category' => $category];
        };
        $https = fn ($url) => filter_var($url, FILTER_VALIDATE_URL) && parse_url($url, PHP_URL_SCHEME) === 'https'
            && !parse_url($url, PHP_URL_USER) && !parse_url($url, PHP_URL_PASS)
            && !preg_match('/^(localhost|127\.|10\.0\.2\.2)|(^|\.)example\.|\.(local|invalid|test)$/i', parse_url($url, PHP_URL_HOST) ?? '');
        $realEmail = fn ($email) => filter_var($email, FILTER_VALIDATE_EMAIL)
            && !preg_match('/^(test|demo|example)@|@(example\.|.*\.local$|.*\.invalid$)|@example\.test$/i', $email);
        $add('APP_ENV production', app()->environment('production'));
        $add('APP_DEBUG disabled', config('app.debug') === false);
        $add('APP_URL HTTPS', (bool) $https(config('app.url')), 'external');
        $add('Public website matches APP_URL', config('website.url') === rtrim(config('app.url'), '/'));
        $key = config('app.key', '');
        $bytes = str_starts_with($key, 'base64:') ? base64_decode(substr($key, 7), true) : $key;
        $add('APP_KEY valid length', is_string($bytes) && strlen($bytes) === (str_contains(config('app.cipher', ''), '128') ? 16 : 32), 'credential');
        $connection = config('database.default');
        $add('Database connection configured', filled($connection) && is_array(config("database.connections.$connection")));
        $database = false;
        try {
            DB::connection()->getPdo();
            DB::select('SELECT ROW_NUMBER() OVER () AS supported');
            $database = collect(['system_settings', 'users', 'admins', 'legal_pages', 'posts', 'post_travel_details', 'location_matches'])
                ->every(fn ($table) => Schema::hasTable($table))
                && Schema::hasColumn('posts', 'occurred_at') && Schema::hasColumn('location_matches', 'score');
        } catch (\Throwable) {}
        $add('Database reachable and migrations installed', $database, 'runtime');
        $add('Persistent cache driver', in_array(config('cache.default'), ['database', 'file', 'redis', 'memcached'], true));
        $add('Persistent queue driver', in_array(config('queue.default'), ['database', 'redis'], true));
        $add('Queue timeout below retry_after', config('queue.connections.database.retry_after', 0) > 90);
        $add('Secure encrypted HTTP-only session', config('session.secure') && config('session.http_only') && config('session.encrypt'));
        $add('Session same-site policy', in_array(config('session.same_site'), ['lax', 'strict'], true));
        $add('Explicit CORS origins', count(config('cors.allowed_origins', [])) > 0 && !in_array('*', config('cors.allowed_origins', []), true));
        foreach (['avatar_disk', 'post_media_disk'] as $diskKey) {
            $disk = config("mobile.$diskKey");
            $add("Private $diskKey", filled($disk) && config("filesystems.disks.$disk.visibility") !== 'public'
                && $disk !== 'public' && is_array(config("filesystems.disks.$disk")));
        }
        $add('Default filesystem configured', is_array(config('filesystems.disks.'.config('filesystems.default'))));
        $add('Storage and bootstrap cache writable', is_writable(storage_path()) && is_writable(base_path('bootstrap/cache')), 'runtime');
        $add('Public storage link absent or audited', !is_link(public_path('storage')) && !is_dir(public_path('storage')), 'configuration', 'WARNING');
        $add('Cron scheduler installed (operator confirmation)', (bool) config('deployment.scheduler_configured'), 'external');
        $add('Queue worker installed (operator confirmation)', (bool) config('deployment.worker_configured'), 'external');
        $smtp = config('mail.mailers.smtp');
        $mailHost = $smtp['host'] ?? '';
        $add('Production SMTP', config('mail.default') === 'smtp' && filled($mailHost)
            && !in_array($mailHost, ['127.0.0.1', 'localhost', 'mailpit'], true)
            && $realEmail(config('mail.from.address'))
            && (config('deployment.allow_mail_relay') || (filled($smtp['username'] ?? null) && filled($smtp['password'] ?? null))), 'credential');
        $fcm = null;
        if (is_readable(config('push.credentials') ?? '')) {
            $fcm = json_decode(file_get_contents(config('push.credentials')), true);
        }
        $add('Firebase FCM live provider', config('push.driver') === 'fcm' && is_array($fcm)
            && ($fcm['type'] ?? '') === 'service_account' && filled($fcm['private_key'] ?? null)
            && ($fcm['project_id'] ?? null) === config('push.project') && filled(config('push.project')), 'credential');
        $add('Google OAuth audiences', count(config('social.google.audiences', [])) > 0, 'credential');
        $add('Apple OAuth audiences and signing', count(config('social.apple.audiences', [])) > 0
            && filled(config('social.apple.team_id')) && filled(config('social.apple.key_id'))
            && is_readable(config('social.apple.private_key_path') ?? ''), 'credential');
        $add('Final brand supplied', (bool) config('deployment.final_brand'), 'brand');
        if ($database) {
            $settings = app(Settings::class);
            $add('Real support email', (bool) $realEmail($settings->get('support_email')), 'external');
            foreach (['app_store_url' => 'apps.apple.com', 'play_store_url' => 'play.google.com'] as $name => $host) {
                $url = $settings->get($name);
                $validStore = (bool) $https($url) && parse_url($url, PHP_URL_HOST) === $host;
                if ($name === 'play_store_url') {
                    parse_str(parse_url($url ?? '', PHP_URL_QUERY) ?? '', $parameters);
                    $validStore = $validStore && parse_url($url, PHP_URL_PATH) === '/store/apps/details'
                        && ($parameters['id'] ?? null) === 'com.senmiydin.app';
                } else {
                    $validStore = $validStore && preg_match('/\/id[0-9]+(?:\/|$)/', parse_url($url ?? '', PHP_URL_PATH) ?? '');
                }
                $add($name, (bool) $validStore, 'external');
            }
            $legal = DB::table('legal_pages')->get()->keyBy('slug');
            $ready = (bool) config('deployment.legal_reviewed')
                && !preg_match('/lorem ipsum|\bDemo\b|example\.(com|test)|@.*\.local/i',
                    (config('deployment.operator_name') ?? '').' '.(config('deployment.operator_contact') ?? ''))
                && filled(config('deployment.operator_name'))
                && filled(config('deployment.operator_contact'));
            foreach (Pages::LEGAL as $slug => $default) {
                $body = $legal->get($slug)?->body ?? '';
                $ready = $ready && filled($body) && trim($body) !== trim($default[1])
                    && !preg_match('/lorem ipsum|example\.com|example\.test|@.*\.local/i', $body);
            }
            $add('Operator identity and reviewed legal CMS', $ready, 'external');
            $add('No development administrator', !DB::table('admins')->where('email', 'like', '%@senmiydin.local')->exists(), 'data');
            $add('No demo or QA member data', !DB::table('users')->where(fn ($q) => $q
                ->where('email', 'like', '%@senmiydin.local')->orWhere('email', 'like', '%@example.test'))->exists(), 'data');
            $add('Production super administrator exists', DB::table('admins')->where('is_active', true)->where('role', 'super_admin')
                ->where('email', 'not like', '%@senmiydin.local')->exists(), 'external');
        } else {
            $add('Database-backed stores, legal and demo audit', false, 'runtime');
        }
        return $rows;
    }
}
