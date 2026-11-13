<?php

namespace App\Notifications;

use App\Jobs\DeliverPush;
use App\Safety\Blocks;
use Illuminate\Support\Facades\DB;

final class Inbox
{
    public const DEFAULTS = [
        'message' => true, 'message_request' => true, 'encounter' => true,
        'like' => true, 'comment' => true, 'follow' => true, 'nearby_activity' => false, 'location_match' => false, 'system' => true,
        'map_note_nearby' => true, 'map_note_reply' => true,
    ];

    public const TYPES = [
        'like' => ['/post', 'Paylaşımın beğenildi.'],
        'comment' => ['/comments', 'Paylaşımına yorum yapıldı.'],
        'comment_reply' => ['/comments', 'Yorumuna bir cevap geldi.'],
        'follow' => ['/profile', 'Bir kullanıcı seni takip etmeye başladı.'],
        'message' => ['/conversation', 'Yeni bir mesajın var.'],
        'message_request' => ['/conversation', 'Yeni bir mesaj isteğin var.'],
        'encounter_request' => ['/encounter', 'Bir karşılaşmada etiketlendin.'],
        'encounter_accepted' => ['/encounter', 'Karşılaşma isteğin onaylandı.'],
        'encounter_rejected' => ['/encounter', 'Karşılaşma isteğin reddedildi.'],
        'encounter_story' => ['/encounter', 'Ortak karşılaşma hikâyen güncellendi.'],
        'encounter_story_approval' => ['/encounter', 'Ortak hikâye yayın onayı bekliyor.'],
        'encounter_story_published' => ['/encounter', 'Ortak karşılaşma hikâyen yayınlandı.'],
        'location_match' => ['/post', 'Birine denk gelmiş olabilirsin 👀'],
        'nearby_activity' => ['/post', 'Geçtiğin bölgede bir paylaşım var.'],
        'system' => ['/notifications', 'Yeni bir SenMiydin? duyurusu var.'],
        'map_note_nearby' => ['/map-note', 'Yakınına bir not bırakıldı.'],
        'map_note_reply' => ['/map-note', 'Notuna bir cevap geldi.'],
    ];

    /** Optional second line shown under the notification text. Never carries identity. */
    public const SUBTITLES = ['map_note_nearby' => 'Birisi bulunduğun bölgede dijital bir not bıraktı.'];

    public static function add(int $user, ?int $actor, string $type, ?int $entity = null, bool $inApp = true, bool $push = true, ?int $announcement = null): void
    {
        $recipient = \App\Models\User::where('account_status', 'active')->find($user);
        if (!$recipient || !self::permitted($recipient, $type) ||
            ($actor !== null && !\App\Models\User::whereKey($actor)->where('account_status', 'active')->exists()) ||
            $user === $actor || ($actor !== null && Blocks::between($user, $actor))) {
            return;
        }

        $id = DB::table('app_notifications')->insertGetId([
            'user_id' => $user, 'actor_id' => $actor, 'type' => $type, 'entity_id' => $entity, 'created_at' => now(),
            'in_app' => $inApp, 'announcement_id' => $announcement,
        ]);
        if (! $push) {
            return;
        }
        if (config('push.driver') === 'log') {
            DB::afterCommit(fn () => rescue(fn () => app(PushDelivery::class)->send($id)));
        } elseif (config('push.driver') === 'fcm') {
            DeliverPush::dispatch($id)->onConnection('database')->afterCommit();
        }
    }

    public static function permitted(\App\Models\User $user, string $type): bool
    {
        // Replies share the existing "comment" preference; no extra settings row.
        $category = str_starts_with($type, 'encounter_') ? 'encounter' : ($type === 'comment_reply' ? 'comment' : $type);
        return isset(self::DEFAULTS[$category]) &&
            (($user->push_preferences ?? []) + self::DEFAULTS)[$category] &&
            (! in_array($type, ['location_match', 'nearby_activity'], true) || $user->location_history_enabled) &&
            // Automatic recommendations are opt-in: strong matches follow encounter suggestions, nearby discovery follows city discovery.
            ($type !== 'location_match' || $user->encounter_suggestions) &&
            ($type !== 'nearby_activity' || $user->city_discovery);
    }

    public static function query(int $user, bool $includePushOnly = false)
    {
        $query = DB::table('app_notifications')->where('user_id', $user)
            ->when(! $includePushOnly, fn ($items) => $items->where('in_app', true));
        return Blocks::exclude($query, $user, 'app_notifications.actor_id');
    }
}
