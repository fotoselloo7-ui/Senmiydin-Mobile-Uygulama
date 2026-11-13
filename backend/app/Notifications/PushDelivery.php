<?php

namespace App\Notifications;

use App\Models\User;
use App\Safety\Blocks;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PushDelivery
{
    public function send(int $id): void
    {
        $row = DB::table('app_notifications')->find($id);
        if (! $row || !isset(Inbox::TYPES[$row->type]) || $row->read_at || ($row->actor_id && Blocks::between($row->user_id, $row->actor_id))) {
            return;
        }
        $user = User::where('account_status', 'active')->find($row->user_id);
        if ($row->type === 'location_match' && !$user?->location_history_enabled) return;
        $category = str_starts_with($row->type, 'encounter_') ? 'encounter' : $row->type;
        if (! $user || ! (($user->push_preferences ?? []) + Inbox::DEFAULTS)[$category]) {
            return;
        }
        [$route, $message] = Inbox::TYPES[$row->type];
        $payload = [
            'type' => $row->type, 'route' => $route, 'entity_id' => (string) $row->entity_id,
            'notification_id' => (string) $id, 'recipient_id' => (string) $row->user_id,
        ];
        $devices = DB::table('user_devices')->where('user_id', $user->id)->where('is_active', true)
            ->whereExists(function ($tokens): void {
                $tokens->selectRaw('1')->from('personal_access_tokens')->whereColumn('id', 'user_devices.personal_access_token_id')
                    ->where(fn ($valid) => $valid->whereNull('expires_at')->orWhere('expires_at', '>', now()));
                if ($expiration = config('sanctum.expiration')) $tokens->where('created_at', '>', now()->subMinutes($expiration));
            })->get();
        foreach ($devices as $device) {
            if (config('push.driver') === 'log') {
                Log::info('Push notification', ['device_id' => $device->id, 'data' => $payload]);
            } elseif (config('push.driver') === 'fcm') {
                $this->deliver($device, $message, $payload);
            }
        }
    }

    private function deliver(object $device, string $message, array $payload): void
    {
        $project = config('push.project');
        if (! is_string($project) || ! preg_match('/^[a-z0-9-]+$/', $project)) {
            throw new \RuntimeException('Invalid FCM project configuration.');
        }
        $response = Http::timeout(10)->withToken($this->accessToken($project))
            ->post("https://fcm.googleapis.com/v1/projects/$project/messages:send", ['message' => [
                'token' => Crypt::decryptString($device->push_token),
                'notification' => ['title' => 'SenMiydin?', 'body' => $message],
                'data' => $payload,
                'android' => ['priority' => 'high'],
            ]]);
        if (in_array('UNREGISTERED', array_column($response->json('error.details') ?? [], 'errorCode'), true)) {
            DB::table('user_devices')->where('id', $device->id)->where('token_hash', $device->token_hash)
                ->update(['is_active' => false]);
        } elseif (! $response->successful()) {
            throw new \RuntimeException('FCM rejected push delivery with status '.$response->status());
        }
    }

    protected function accessToken(string $project): string
    {
        return Crypt::decryptString(Cache::remember('fcm-access-token:v2:'.$project, 3000, function (): string {
            $file = config('push.credentials');
            $account = is_string($file) && is_readable($file) ? json_decode(file_get_contents($file), true) : null;
            if (! isset($account['client_email'], $account['private_key']) || ($account['project_id'] ?? null) !== $project) {
                throw new \RuntimeException('Missing FCM service account.');
            }
            $encode = fn (string $value) => rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
            $endpoint = 'https://oauth2.googleapis.com/token';
            $now = time();
            $claims = json_encode(['iss' => $account['client_email'], 'aud' => $endpoint,
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging', 'iat' => $now, 'exp' => $now + 3600]);
            $jwt = $encode('{"alg":"RS256","typ":"JWT"}').'.'.$encode($claims);
            if (! openssl_sign($jwt, $signature, $account['private_key'], OPENSSL_ALGO_SHA256)) {
                throw new \RuntimeException('Invalid FCM service account key.');
            }
            $token = Http::timeout(10)->asForm()->post($endpoint, [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion' => $jwt.'.'.$encode($signature),
            ])->json('access_token');
            if (! is_string($token)) {
                throw new \RuntimeException('FCM authorization failed.');
            }

            return Crypt::encryptString($token);
        }));
    }
}
