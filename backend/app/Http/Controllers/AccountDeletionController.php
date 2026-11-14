<?php

namespace App\Http\Controllers;

use App\Accounts\EraseAccount;
use App\Http\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AccountDeletionController
{
    public function __invoke(Request $request, EraseAccount $erasure)
    {
        $data = $request->validate(['password' => AuthController::currentPasswordRules(), 'confirmation' => 'required|in:SİL,DELETE']);
        if (! Hash::check($data['password'], $request->user()->password)) {
            throw ValidationException::withMessages(['password' => 'Şifren hatalı.']);
        }
        $erasure->erase($request->user());
        // The persistent outbox retries failures without reopening access.
        \App\Jobs\CleanErasedMedia::dispatch()->onConnection('database')->afterCommit();
        return ApiResponse::ok(message: 'Hesabın silindi ve tüm oturumların kapatıldı.');
    }
}
