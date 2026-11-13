<?php

namespace App\Administration;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class Audit
{
    public static function label(string $action): string
    {
        [$target, $verb] = explode('.', $action, 2) + [1 => ''];
        $type = ['user'=>'Kullanıcı','post'=>'Paylaşım','comment'=>'Yorum','encounter'=>'Karşılaşma',
            'report'=>'Şikâyet','map_note'=>'Harita notu','map_note_reply'=>'Harita notu yanıtı','featured'=>'Öne çıkan','settings'=>'Ayarlar','interest'=>'Hobi',
            'city'=>'Şehir','legal'=>'Web içeriği','announcement'=>'Duyuru','support'=>'Destek talebi'][$target] ?? $target;
        $label = ['suspend'=>'askıya alındı','ban'=>'yasaklandı','restore'=>'geri açıldı','revoke'=>'oturumları kapatıldı',
            'remove'=>'kaldırıldı','note'=>'not eklendi','update'=>'güncellendi','create'=>'oluşturuldu',
            'resolved'=>'çözüldü','reviewing'=>'incelemeye alındı','rejected'=>'reddedildi','pending'=>'beklemeye alındı',
            'media_viewed'=>'görseli incelendi','message_viewed'=>'mesajı incelendi','handled'=>'incelendi'][$verb] ?? $verb;
        return trim($type.' · '.$label);
    }

    public static function record(Request $request, string $action, string $type, ?int $id, array $metadata = []): void
    {
        DB::table('admin_audit_logs')->insert([
            'admin_id' => $request->user('admin')->id,
            'action' => $action, 'target_type' => $type, 'target_id' => $id,
            'metadata' => $metadata ? json_encode($metadata, JSON_THROW_ON_ERROR) : null,
            'ip_address' => $request->ip(), 'created_at' => now(),
        ]);
    }
}
