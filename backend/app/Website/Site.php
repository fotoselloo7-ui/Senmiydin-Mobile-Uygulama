<?php

namespace App\Website;

/**
 * Public website localization: Turkish is the source language and lives at the root; English lives under /en.
 * Pages are always identified by their canonical Turkish slug; this class maps them to the English path.
 */
final class Site
{
    public const EN_PATHS = [
        '' => '', 'nasil-calisir' => 'how-it-works', 'ozellikler' => 'features', 'guvenlik' => 'safety',
        'gizlilik' => 'privacy', 'kvkk' => 'kvkk', 'kullanim-kosullari' => 'terms',
        'topluluk-kurallari' => 'community-guidelines', 'iletisim' => 'contact', 'hesap-silme' => 'delete-account',
    ];

    public static function enSlug(string $tr): string
    {
        return self::EN_PATHS[$tr] ?? $tr;
    }

    /** Canonical Turkish slug for an English path segment, or null. */
    public static function trSlug(string $en): ?string
    {
        $found = array_search($en, self::EN_PATHS, true);

        return $found === false ? null : (string) $found;
    }

    public static function path(string $trSlug, string $locale): string
    {
        if ($locale === 'en') {
            $slug = self::enSlug($trSlug);

            return $slug === '' ? '/en' : '/en/'.$slug;
        }

        return '/'.$trSlug;
    }

    public static function url(string $trSlug, string $locale): string
    {
        return config('website.url').self::path($trSlug, $locale);
    }

    /** Texts shared by every page of the site (navigation, footer, language switch). */
    public static function chrome(string $locale): array
    {
        return $locale === 'en' ? [
            'skip' => 'Skip to content', 'menu_open' => 'Open menu', 'main_nav' => 'Main menu', 'cta' => 'Discover the app',
            'nav' => [['how-it-works', 'How it works', 'nasil-calisir'], ['#harita-notlari', 'Map Notes', null], ['features', 'Features', 'ozellikler'], ['safety', 'Safety', 'guvenlik'], ['contact', 'Contact', 'iletisim']],
            'footer_tagline' => 'Find the people you crossed paths with in your city; leave a letter where you passed.',
            'footer_home' => 'Home', 'footer_how' => 'How it works', 'footer_notes' => 'Map Notes', 'footer_features' => 'Features', 'footer_safety' => 'Safety',
            'footer_legal' => [['gizlilik', 'Privacy Policy'], ['kvkk', 'KVKK Notice'], ['kullanim-kosullari', 'Terms of Use'], ['topluluk-kurallari', 'Community Guidelines'], ['iletisim', 'Contact'], ['hesap-silme', 'Delete Account']],
            'rights' => 'All rights reserved.', 'switch_label' => 'Türkçe', 'switch_aria' => 'Türkçe oku', 'lang' => 'en', 'og_locale' => 'en_US',
            'title_home' => ' | Some encounters should not stay unfinished',
            'stores_aria' => 'App stores', 'stores_from' => 'Get it on', 'stores_soon' => 'Soon', 'stores_download' => 'Download',
        ] : [
            'skip' => 'İçeriğe geç', 'menu_open' => 'Menüyü aç', 'main_nav' => 'Ana menü', 'cta' => 'Uygulamayı Keşfet',
            'nav' => [['nasil-calisir', 'Nasıl Çalışır', 'nasil-calisir'], ['#harita-notlari', 'Harita Notları', null], ['ozellikler', 'Özellikler', 'ozellikler'], ['guvenlik', 'Güvenlik', 'guvenlik'], ['iletisim', 'İletişim', 'iletisim']],
            'footer_tagline' => 'Şehrinde karşılaştığın insanları yeniden bul; geçtiğiniz yere bir mektup bırak.',
            'footer_home' => 'Ana Sayfa', 'footer_how' => 'Nasıl Çalışır', 'footer_notes' => 'Harita Notları', 'footer_features' => 'Özellikler', 'footer_safety' => 'Güvenlik',
            'footer_legal' => [['gizlilik', 'Gizlilik Politikası'], ['kvkk', 'KVKK Aydınlatma'], ['kullanim-kosullari', 'Kullanım Koşulları'], ['topluluk-kurallari', 'Topluluk Kuralları'], ['iletisim', 'İletişim'], ['hesap-silme', 'Hesap Silme']],
            'rights' => 'Tüm hakları saklıdır.', 'switch_label' => 'English', 'switch_aria' => 'Read in English', 'lang' => 'tr', 'og_locale' => 'tr_TR',
            'title_home' => ' | Bazı karşılaşmalar yarım kalmasın',
            'stores_aria' => 'Uygulama mağazaları', 'stores_from' => '', 'stores_soon' => 'Yakında', 'stores_download' => 'İndirin',
        ];
    }

    /** English meta for the pages that have an in-code title and description. */
    public static function meta(string $slug, string $locale): array
    {
        $tr = Pages::PUBLIC[$slug] ?? ['SenMiydin?', ''];
        if ($locale !== 'en') {
            return $tr;
        }

        return match ($slug) {
            '' => ['SenMiydin?', 'Did you see someone but never got to talk? Find the people you crossed paths with in your city, share journey memories and leave a digital letter where you passed that stays for 7 days.'],
            'nasil-calisir' => ['How it works', 'Leave a moment, find the person you met and verify it together.'],
            'ozellikler' => ['Features', 'City feed, journey posts, nearby discovery, encounter stories and private messages.'],
            'guvenlik' => ['Safety', 'Manage your location visibility, message requests and interactions.'],
            'iletisim' => ['Contact', 'Send a support request or feedback about SenMiydin?.'],
            'hesap-silme' => ['Delete Account', 'Create a deletion request for your SenMiydin? account and the personal data tied to it.'],
            default => $tr,
        };
    }

    /** Values that fill the {placeholders} of the legal texts; nothing is invented when the operator left a field empty. */
    public static function operatorValues(array $settings, string $locale): array
    {
        $contact = $settings['operator_contact_email'] ?? null;

        return [
            'operator_name' => $settings['operator_name'] ?? null,
            'operator_address' => $settings['operator_address'] ?? null,
            'operator_registration' => $settings['operator_registration'] ?? null,
            'contact_email' => filled($contact) ? $contact : ($settings['support_email'] ?? null),
            '_missing' => $locale === 'en' ? '— (to be completed by the operator)' : '— (işletici tarafından tamamlanacak)',
        ];
    }

    public static function operatorComplete(array $settings): bool
    {
        $values = self::operatorValues($settings, 'tr');

        return filled($values['operator_name']) && filled($values['operator_address'])
            && filled($values['operator_registration']) && filled($values['contact_email']);
    }
}
