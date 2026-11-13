<?php

namespace App\Auth;

use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Http;

class AppleTokens
{
    private function secret(string $client): string
    {
        $path = config('social.apple.private_key_path');
        if (!is_string($path) || !is_readable($path)) throw new \RuntimeException('Apple signing configuration missing.');
        return JWT::encode([
            'iss' => config('social.apple.team_id'), 'iat' => time(), 'exp' => time() + 300,
            'aud' => 'https://appleid.apple.com', 'sub' => $client,
        ], file_get_contents($path), 'ES256', config('social.apple.key_id'));
    }

    public function exchange(string $code, string $client): array
    {
        $response = Http::timeout(10)->asForm()->post('https://appleid.apple.com/auth/token', [
            'client_id' => $client, 'client_secret' => $this->secret($client),
            'code' => $code, 'grant_type' => 'authorization_code',
        ]);
        if (!$response->successful() || !is_string($response->json('refresh_token')) || !is_string($response->json('id_token'))) {
            abort(422, 'Apple girişi doğrulanamadı.');
        }
        return $response->json();
    }

    public function revoke(string $token, string $client): void
    {
        $response = Http::timeout(10)->asForm()->post('https://appleid.apple.com/auth/revoke', [
            'client_id' => $client, 'client_secret' => $this->secret($client),
            'token' => $token, 'token_type_hint' => 'refresh_token',
        ]);
        if (!$response->successful()) throw new \RuntimeException('Apple token revocation failed.');
    }
}
