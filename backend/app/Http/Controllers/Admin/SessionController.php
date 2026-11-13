<?php

namespace App\Http\Controllers\Admin;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class SessionController
{
    public function create(Request $request)
    {
        return $request->user('admin')?->is_active
            ? redirect()->route('admin.dashboard')
            : response()->view('admin.login')->header('Cache-Control', 'private, no-store')->header('X-Robots-Tag', 'noindex, nofollow');
    }

    public function store(Request $request)
    {
        $data = $request->validate(['email' => 'required|email|max:254', 'password' => 'required|string|max:72']);
        if (app()->environment('production') && Str::lower($data['email']) === 'admin@senmiydin.local') {
            throw ValidationException::withMessages(['email' => 'E-posta veya parola hatalı.']);
        }
        if (! Auth::guard('admin')->attempt(['email' => Str::lower($data['email']), 'password' => $data['password'], 'is_active' => true])) {
            throw ValidationException::withMessages(['email' => 'E-posta veya parola hatalı.']);
        }
        $request->session()->regenerate();
        $request->session()->forget('url.intended');
        return redirect()->route('admin.dashboard');
    }

    public function destroy(Request $request)
    {
        Auth::guard('admin')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();
        return redirect()->route('admin.login');
    }
}
