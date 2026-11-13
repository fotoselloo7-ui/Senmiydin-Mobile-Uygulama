<?php

namespace App\Http\Controllers;

use App\Notifications\Inbox;

use App\Http\ApiResponse;
use App\Http\Resources\ProfileResource;
use App\Models\User;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password as PasswordRule;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        self::normalize($request, 'username');
        self::normalize($request, 'email');
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'username' => [...self::usernameRules(), Rule::unique('users')],
            'email' => ['required', 'email', 'max:254', Rule::unique('users')],
            'password' => self::newPasswordRules(),
            'birth_date' => ['required', 'date_format:Y-m-d', 'after_or_equal:1900-01-01',
                'before_or_equal:'.now('Europe/Istanbul')->subYearsNoOverflow(app(\App\Administration\Settings::class)->get('minimum_age'))->toDateString()],
            'city_id' => ['required', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
            'accepted_terms' => ['accepted'],
        ], self::validationMessages());

        try {
            return DB::transaction(function () use ($data, $request) {
                unset($data['accepted_terms']);
                $data['password'] = Hash::make($data['password']);
                $user = User::create($data);
                if ($identity = $request->attributes->get('social_identity')) {
                    DB::table('social_identities')->insert($identity + ['user_id' => $user->id, 'created_at' => now(), 'updated_at' => now()]);
                }

                return $this->issueToken($user, 201);
            });
        } catch (UniqueConstraintViolationException $exception) {
            foreach (['email', 'username'] as $field) {
                if (User::where($field, $data[$field])->exists()) {
                    throw ValidationException::withMessages([$field => self::validationMessages()[$field.'.unique']]);
                }
            }
            throw $exception;
        }
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'identifier' => ['required', 'string', 'max:254'],
            'password' => ['required', 'string', 'max:72', self::bcryptInput()],
        ], self::validationMessages());

        $identifier = Str::lower(trim($data['identifier']));
        $field = str_contains($identifier, '@') ? 'email' : 'username';

        return DB::transaction(function () use ($field, $identifier, $data) {
            $user = User::where($field, $identifier)->lockForUpdate()->first();
            $hash = $user?->password ?? '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.';
            $valid = Hash::check($data['password'], $hash);
            if (! $user || ! $valid || $user->account_status !== 'active') {
                return ApiResponse::error('Giriş bilgilerin hatalı.', 401);
            }
            if (Hash::needsRehash($user->password)) {
                $user->password = Hash::make($data['password']);
            }

            return $this->issueToken($user);
        });
    }

    public function logout(Request $request): JsonResponse
    {
        $token = $request->user()->currentAccessToken();
        DB::transaction(function () use ($token): void {
            DB::table('user_devices')->where('personal_access_token_id', $token->id)->update(['is_active' => false]);
            $token->delete();
        });

        return ApiResponse::ok(message: 'Oturum kapatıldı.');
    }

    public function forgot(Request $request): JsonResponse
    {
        self::normalize($request, 'email');
        $data = $request->validate(['email' => ['required', 'email', 'max:254']], self::validationMessages());
        Password::sendResetLink([...$data, 'account_status' => 'active']);

        return ApiResponse::ok(message: 'Bu adresle kayıtlı bir hesap varsa sıfırlama kodu e-postana gönderilir.');
    }

    public function reset(Request $request): JsonResponse
    {
        self::normalize($request, 'email');
        $data = $request->validate([
            'email' => ['required', 'email', 'max:254'],
            'token' => ['required', 'string', 'size:64'],
            'password' => [...self::newPasswordRules(), 'confirmed'],
            'password_confirmation' => ['required', 'string'],
        ], self::validationMessages());

        $status = DB::transaction(function () use ($data) {
            User::where('email', $data['email'])->lockForUpdate()->first();

            return Password::reset([...$data, 'account_status' => 'active'], function (User $user, string $password): void {
                $user->forceFill(['password' => Hash::make($password), 'remember_token' => Str::random(60)])->save();
                $user->tokens()->delete();
                event(new PasswordReset($user));
                \Illuminate\Support\Facades\Mail::to($user->email)->queue((new \App\Mail\SecurityNotice('Hesabının şifresi sıfırlandı.'))->afterCommit());
            });
        });

        if ($status !== Password::PASSWORD_RESET) {
            throw ValidationException::withMessages(['token' => 'Sıfırlama kodu geçersiz veya süresi dolmuş.']);
        }

        return ApiResponse::ok(message: 'Şifren güncellendi.');
    }

    public function changePassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'current_password' => ['required', 'string', 'max:72', self::bcryptInput()],
            'password' => [...self::newPasswordRules(), 'confirmed', 'different:current_password'],
            'password_confirmation' => ['required', 'string'],
        ], self::validationMessages());

        DB::transaction(function () use ($request, $data): void {
            $user = User::lockForUpdate()->findOrFail($request->user()->id);
            if (! Hash::check($data['current_password'], $user->password)) {
                throw ValidationException::withMessages(['current_password' => 'Mevcut şifren hatalı.']);
            }
            $user->forceFill(['password' => Hash::make($data['password']), 'remember_token' => Str::random(60)])->save();
            $user->tokens()->whereKeyNot($request->user()->currentAccessToken()->id)->delete();
            DB::table('password_reset_tokens')->where('email', $user->email)->delete();
            Inbox::add($user->id, null, 'system');
            \Illuminate\Support\Facades\Mail::to($user->email)->queue((new \App\Mail\SecurityNotice('Hesabının şifresi değiştirildi.'))->afterCommit());
        });

        return ApiResponse::ok(message: 'Şifren güncellendi.');
    }

    public function issueToken(User $user, int $status = 200): JsonResponse
    {
        $user->forceFill(['last_seen_at' => now()])->save();

        return ApiResponse::ok([
            'token' => $user->createToken('mobile')->plainTextToken,
            'user' => new ProfileResource($user->fresh(['city', 'interests'])),
        ], $status === 201 ? 'Hesabın oluşturuldu.' : 'Giriş yapıldı.', $status);
    }

    public static function usernameRules(): array
    {
        return ['required', 'string', 'min:3', 'max:24', 'regex:/\A[a-z0-9_.]+\z/'];
    }

    private static function newPasswordRules(): array
    {
        return ['required', 'string', PasswordRule::min(10)->letters()->numbers(), self::bcryptInput()];
    }

    private static function normalize(Request $request, string $key): void
    {
        $value = $request->input($key);
        if (is_string($value)) {
            $request->merge([$key => Str::lower(trim($value))]);
        }
    }

    public static function currentPasswordRules(): array
    {
        return ['required', 'string', 'max:72', self::bcryptInput()];
    }

    private static function bcryptInput(): \Closure
    {
        return function (string $attribute, mixed $value, \Closure $fail): void {
            if (! is_string($value)) {
                return;
            }
            if (strlen($value) > 72) {
                $fail('Şifren en fazla 72 bayt olabilir.');
            } elseif (str_contains($value, "\0")) {
                $fail('Şifren geçersiz bir karakter içeriyor.');
            }
        };
    }

    public static function validationMessages(): array
    {
        return [
            'required' => 'Bu alan zorunlu.',
            'email.email' => 'Geçerli bir e-posta adresi gir.',
            'email.unique' => 'Bu e-posta adresi kullanımda.',
            'username.unique' => 'Bu kullanıcı adı kullanımda.',
            'username.regex' => 'Kullanıcı adında harf, rakam, nokta ve alt çizgi kullanabilirsin.',
            'username.min' => 'Kullanıcı adı en az 3 karakter olmalı.',
            'username.max' => 'Kullanıcı adı en fazla 24 karakter olabilir.',
            'birth_date.before_or_equal' => 'Devam etmek için '.app(\App\Administration\Settings::class)->get('minimum_age').' yaşını doldurmalısın.',
            'birth_date.*' => 'Geçerli bir doğum tarihi gir.',
            'city_id.exists' => 'Listeden bir şehir seç.',
            'accepted_terms.accepted' => 'Devam etmek için koşulları kabul etmelisin.',
            'password.confirmed' => 'Yeni şifreler eşleşmiyor.',
            'password.different' => 'Yeni şifre mevcut şifreden farklı olmalı.',
            'password.min' => 'Şifre en az 10 karakter olmalı.',
            'password.letters' => 'Şifre en az bir harf içermeli.',
            'password.numbers' => 'Şifre en az bir rakam içermeli.',
        ];
    }
}
