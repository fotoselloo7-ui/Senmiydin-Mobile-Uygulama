<?php

namespace App\Http\Controllers;

use App\Administration\Settings;
use App\Auth\AppleTokens;
use App\Auth\IdentityVerifier;
use App\Http\ApiResponse;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class SocialAuthController
{
    public function appleCallback(Request $request)
    {
        $data = $request->validate([
            'state' => ['required', 'string', 'regex:/\\A[a-f0-9]{64}\\z/'],
            'code' => 'required_without:error|string|max:4096',
            'id_token' => 'required_without:error|string|max:16384',
            'error' => 'nullable|in:access_denied,user_cancelled_authorize,invalid_request',
        ]);
        abort_unless(Cache::has('apple-nonce:'.$data['state']), 422);
        $query = http_build_query($data, '', '&', PHP_QUERY_RFC3986);
        return redirect()->away('intent://callback?'.$query.'#Intent;package=com.senmiydin.app;scheme=signinwithapple;end', 303)
            ->header('Cache-Control', 'no-store')->header('Referrer-Policy', 'no-referrer');
    }

    public function challenge(IdentityVerifier $verifier)
    {
        abort_unless($verifier->configured('apple'), 503);
        $nonce = Str::random(64);
        Cache::put('apple-nonce:'.hash('sha256', $nonce), true, 300);
        return ApiResponse::ok(['nonce' => $nonce]);
    }

    public function login(Request $request, string $provider, IdentityVerifier $verifier, AppleTokens $apple, AuthController $auth)
    {
        abort_unless($verifier->configured($provider), 503);
        $data = $request->validate([
            'id_token' => 'required|string|max:16384', 'nonce' => 'nullable|string|size:64',
            'authorization_code' => 'nullable|string|max:4096',
        ]);
        $claims = $verifier->verify($provider, $data['id_token'], $data['nonce'] ?? null);
        $hash = hash('sha256', $claims['sub']);
        $identity = DB::table('social_identities')->where(['provider' => $provider, 'subject_hash' => $hash])->first();
        if (!$identity && !$request->filled('username')) {
            return ApiResponse::error('Hesabını tamamlamak için kayıt bilgilerini gir.', 412);
        }
        if (!$identity && !app(Settings::class)->get('registrations_enabled')) abort(503);
        if (!$identity && (!filter_var($claims['email'] ?? '', FILTER_VALIDATE_EMAIL) || !in_array($claims['email_verified'] ?? false, [true, 'true'], true))) {
            throw ValidationException::withMessages(['email' => 'Doğrulanmış e-posta gerekli. E-posta ile kayıt olabilirsin.']);
        }
        $refresh = null;
        if ($provider === 'apple') {
            abort_unless(is_string($data['authorization_code'] ?? null) && Cache::pull('apple-nonce:'.hash('sha256', $data['nonce'])) === true, 422);
            $tokens = $apple->exchange($data['authorization_code'], $claims['aud']);
            $confirmed = $verifier->verify('apple', $tokens['id_token'], $data['nonce']);
            abort_unless(hash_equals($claims['sub'], $confirmed['sub']), 422);
            $refresh = Crypt::encryptString($tokens['refresh_token']);
        }
        return DB::transaction(function () use ($request, $identity, $provider, $hash, $claims, $refresh, $auth) {
            if ($identity) {
                $user = User::lockForUpdate()->findOrFail($identity->user_id);
                abort_unless($user->account_status === 'active', 401);
                if ($refresh) DB::table('social_identities')->where('id', $identity->id)->update(['refresh_token' => $refresh, 'updated_at' => now()]);
                return $auth->issueToken($user);
            }
            // Never silently link an existing password account based only on a matching email.
            $email = Str::lower($claims['email']);
            if (User::where('email', $email)->exists()) {
                throw ValidationException::withMessages(['email' => 'Bu e-posta için mevcut şifrenle giriş yap.']);
            }
            $request->merge(['email' => $email]);
            $request->attributes->set('social_identity', [
                'provider' => $provider, 'subject_hash' => $hash, 'client_id' => $claims['aud'],
                'refresh_token' => $refresh,
            ]);
            return $auth->register($request);
        });
    }
}
