<?php

namespace App\Auth;

use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;

class IdentityVerifier
{
    public function configured(string $provider): bool
    {
        if (! config("social.$provider.audiences")) return false;
        return $provider !== 'apple' || (filled(config('social.apple.team_id')) && filled(config('social.apple.key_id'))
            && is_readable(config('social.apple.private_key_path') ?? ''));
    }

    public function verify(string $provider, string $token, ?string $nonce = null): array
    {
        abort_unless($this->configured($provider), 503);
        try {
            $key = "oidc-jwks:$provider";
            $fetch = fn () => Http::timeout(10)->get(config("social.$provider.jwks"))->throw()->json();
            $set = Cache::remember($key, 3600, $fetch);
            $set['keys'] = array_values(array_filter($set['keys'] ?? [], fn ($key) => ($key['kty'] ?? '') === 'RSA' && ($key['alg'] ?? 'RS256') === 'RS256'));
            try {
                $claims = (array) JWT::decode($token, JWK::parseKeySet($set, 'RS256'));
            } catch (\UnexpectedValueException $error) {
                // Providers rotate signing keys. Retry once with the current fixed HTTPS JWKS.
                Cache::forget($key);
                $set = $fetch();
                $set['keys'] = array_values(array_filter($set['keys'] ?? [], fn ($key) => ($key['kty'] ?? '') === 'RSA' && ($key['alg'] ?? 'RS256') === 'RS256'));
                $claims = (array) JWT::decode($token, JWK::parseKeySet($set, 'RS256'));
            }
            if (! in_array($claims['iss'] ?? null, config("social.$provider.issuers"), true)
                || ! in_array($claims['aud'] ?? null, config("social.$provider.audiences"), true)
                || ! is_string($claims['sub'] ?? null) || $claims['sub'] === ''
                || ! is_int($claims['exp'] ?? null) || $claims['exp'] <= time()
                || ! is_int($claims['iat'] ?? null) || $claims['iat'] < time() - 600
                || ($provider === 'apple' && (! $nonce || ! hash_equals(hash('sha256', $nonce), $claims['nonce'] ?? '')))) {
                throw new \UnexpectedValueException;
            }
            return $claims;
        } catch (\Throwable) {
            throw ValidationException::withMessages(['id_token' => 'Giriş doğrulanamadı. Yeniden dene.']);
        }
    }
}
