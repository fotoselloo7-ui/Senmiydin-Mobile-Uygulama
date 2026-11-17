<?php

namespace App\Http\Controllers;

use App\Accounts\EraseAccount;
use App\Auth\IdentityVerifier;
use App\Http\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AccountDeletionController
{
    /**
     * Deleting an account always needs a fresh proof of identity:
     *  - the app password, or
     *  - for an account that signs in with Google / Apple, a new sign-in with that same provider account.
     * The provider password is never asked for or seen by the app.
     */
    public function __invoke(Request $request, EraseAccount $erasure, IdentityVerifier $verifier)
    {
        $user = $request->user();
        if ($request->filled('id_token')) {
            $data = $request->validate([
                'confirmation' => 'required|in:SİL,DELETE',
                'provider' => 'required|in:google,apple',
                'id_token' => 'required|string|max:16384',
                'nonce' => 'nullable|string|size:64',
            ]);
            if ($data['provider'] === 'apple') {
                // The nonce must be one this server issued moments ago, and it is used up here.
                abort_unless(is_string($data['nonce'] ?? null) && Cache::pull('apple-nonce:'.hash('sha256', $data['nonce'])) === true, 422);
            }
            // verify() only accepts a token issued within the last ten minutes, so an old token cannot be replayed.
            $claims = $verifier->verify($data['provider'], $data['id_token'], $data['nonce'] ?? null);
            $own = DB::table('social_identities')->where([
                'user_id' => $user->id, 'provider' => $data['provider'], 'subject_hash' => hash('sha256', $claims['sub']),
            ])->exists();
            if (! $own) {
                throw ValidationException::withMessages(['id_token' => 'Bu doğrulama bu hesaba ait değil. Hesabına bağlı Google / Apple hesabıyla doğrula.']);
            }
        } else {
            $data = $request->validate(['password' => AuthController::currentPasswordRules(), 'confirmation' => 'required|in:SİL,DELETE']);
            if (! ($user->has_password ?? true) || ! Hash::check($data['password'], $user->password)) {
                throw ValidationException::withMessages(['password' => 'Şifren hatalı.']);
            }
        }
        $erasure->erase($user);
        // The persistent outbox retries failures without reopening access.
        \App\Jobs\CleanErasedMedia::dispatch()->onConnection('database')->afterCommit();

        return ApiResponse::ok(message: 'Hesabın silindi ve tüm oturumların kapatıldı.');
    }
}
