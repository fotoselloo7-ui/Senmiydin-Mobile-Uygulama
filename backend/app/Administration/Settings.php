<?php

namespace App\Administration;

use Illuminate\Support\Facades\DB;

final class Settings
{
    public const LABELS = [
        'moderation_banned_words' => 'Engellenen ifadeler (her satırda bir ifade)',
        'moderation_blocked_domains' => 'Engellenen bağlantı alan adları (her satırda bir alan adı)',
        'moderation_max_mentions' => 'En fazla kişi etiketi', 'moderation_max_links' => 'En fazla bağlantı',
        'moderation_post_repeats' => 'Tekrarlanan paylaşım sınırı', 'moderation_comment_repeats' => 'Tekrarlanan yorum sınırı',
        'moderation_repeat_seconds' => 'Tekrar kontrol süresi (saniye)',
        'app_name' => 'Uygulama adı', 'support_email' => 'Destek e-postası',
        'app_store_url' => 'App Store bağlantısı', 'play_store_url' => 'Google Play bağlantısı',
        'web_cta' => 'Web çağrı metni', 'web_announcement' => 'Public site duyurusu', 'minimum_age' => 'Minimum kayıt yaşı',
        'max_post_photos' => 'Paylaşım başına fotoğraf sınırı', 'location_history_days' => 'Konum geçmişi saklama süresi (gün)',
        'maintenance_mode' => 'Bakım modu', 'maintenance_message' => 'Bakım mesajı',
        'registrations_enabled' => 'Yeni kayıtlar', 'anonymous_posts_enabled' => 'Anonim paylaşımlar',
        'encounters_enabled' => 'Karşılaşmalar', 'nearby_enabled' => 'Yakınındaki İnsanlar modülü',
        'featured_enabled' => 'Öne Çıkan Karşılaşmalar modülü', 'messaging_enabled' => 'Mesajlaşma',
        'announcements_enabled' => 'Ana sayfa duyuru alanı',
        'android_min_version' => 'Android minimum sürüm', 'android_latest_version' => 'Android güncel sürüm',
        'ios_min_version' => 'iOS minimum sürüm', 'ios_latest_version' => 'iOS güncel sürüm',
    ];

    public const SWITCHES = [
        'maintenance_mode', 'registrations_enabled', 'anonymous_posts_enabled', 'encounters_enabled',
        'nearby_enabled', 'featured_enabled', 'messaging_enabled', 'announcements_enabled',
    ];

    private ?array $values = null;

    public function all(): array
    {
        return $this->values ??= DB::table('system_settings')->pluck('value', 'key')
            ->map(fn ($value) => json_decode($value, true))->all() + [
                'app_name' => 'SenMiydin?', 'support_email' => config('website.support_email'),
                'app_store_url' => '', 'play_store_url' => '', 'web_cta' => 'Şehrinde seni bekleyen karşılaşmaları keşfet.', 'web_announcement' => '',
                'android_min_version' => '', 'android_latest_version' => '', 'ios_min_version' => '', 'ios_latest_version' => '',
                'moderation_banned_words' => '', 'moderation_blocked_domains' => '',
                'moderation_max_mentions' => 8, 'moderation_max_links' => 4,
                'moderation_post_repeats' => 5, 'moderation_comment_repeats' => 3, 'moderation_repeat_seconds' => 120,
                'minimum_age' => config('mobile.minimum_age'), 'max_post_photos' => 10,
                'location_history_days' => config('location.history_days'), 'maintenance_mode' => false,
                'maintenance_message' => 'Kısa bir bakım çalışması yürütüyoruz. Biraz sonra tekrar dene.',
                'registrations_enabled' => true, 'anonymous_posts_enabled' => true, 'encounters_enabled' => true,
                'nearby_enabled' => true, 'featured_enabled' => true, 'messaging_enabled' => true, 'announcements_enabled' => true,
            ];
    }

    public function get(string $key): mixed
    {
        return $this->all()[$key];
    }

    public function save(array $values): void
    {
        foreach ($values as $key => $value) {
            DB::table('system_settings')->updateOrInsert(['key' => $key], [
                'value' => json_encode($value, JSON_THROW_ON_ERROR), 'updated_at' => now(),
            ]);
        }
        $this->values = null;
    }
}
