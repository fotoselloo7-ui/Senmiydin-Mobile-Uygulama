<?php

namespace App\Safety;

use App\Administration\Settings;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class ContentGuard
{
    public static function fingerprint(string $body): string
    {
        return hash('sha256', mb_strtolower(preg_replace('/\s+/u', ' ', trim($body)), 'UTF-8'));
    }

    public function check(int $user, string $body, string $table, ?int $except = null): void
    {
        $settings = app(Settings::class);
        $deny = fn (string $message) => throw ValidationException::withMessages(['body' => $message]);
        $list = fn ($value) => array_values(array_filter(array_map('trim', preg_split('/[\r\n,]+/u', (string)$value))));
        foreach ($list($settings->get('moderation_banned_words')) as $word) {
            if (preg_match('/(?<![\pL\pN])'.preg_quote($word, '/').'(?![\pL\pN])/iu', $body)) {
                $deny('Paylaşımında topluluk kurallarına uygun olmayan bir ifade var.');
            }
        }
        preg_match_all('/(?<![\pL\pN])@[\pL\pN_\.]+/u', $body, $mentions);
        if (count($mentions[0]) > $settings->get('moderation_max_mentions')) $deny('Daha az kişiyi etiketleyerek tekrar dene.');
        preg_match_all('~(?:https?://|www\.)[^\s<>]+~iu', $body, $links);
        if (count($links[0]) > $settings->get('moderation_max_links')) $deny('Çok fazla bağlantı var. Bağlantı sayısını azalt.');
        foreach ($links[0] as $link) {
            $host = strtolower(rtrim((string)parse_url(str_starts_with(strtolower($link), 'www.') ? 'https://'.$link : $link, PHP_URL_HOST), '.'));
            foreach ($list($settings->get('moderation_blocked_domains')) as $blocked) {
                $blocked = strtolower(trim($blocked, '. '));
                if ($host === $blocked || str_ends_with($host, '.'.$blocked)) $deny('Bu bağlantı topluluk kuralları nedeniyle paylaşılamıyor.');
            }
        }
        if ($body === '') return;
        $limit = $settings->get($table === 'posts' ? 'moderation_post_repeats' : 'moderation_comment_repeats');
        $q = DB::table($table)->where('user_id', $user)->where('content_hash', self::fingerprint($body))
            ->where('created_at', '>=', now()->subSeconds($settings->get('moderation_repeat_seconds')));
        if ($except) $q->where('id', '<>', $except);
        if ($q->count() >= $limit) $deny('Bu içerik kısa süre önce paylaşıldı. Biraz bekleyip tekrar dene.');
    }
}
