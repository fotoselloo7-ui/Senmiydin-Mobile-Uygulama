<?php

namespace App\Http\Controllers;

use App\Http\ApiResponse;
use App\Http\Resources\ProfileResource;
use App\Location\LocationData;
use App\Models\User;
use App\Notifications\Inbox;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

class ProfileController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        return $this->profile($request->user());
    }

    public function update(Request $request): JsonResponse
    {
        if (is_string($username = $request->input('username'))) {
            $request->merge(['username' => Str::lower(trim($username))]);
        }

        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:100'],
            'username' => ['sometimes', ...AuthController::usernameRules(), Rule::unique('users')->ignore($request->user()->id)],
            'bio' => ['sometimes', 'nullable', 'string', 'max:160'],
            'occupation_school' => ['sometimes', 'nullable', 'string', 'max:120'],
            'city_id' => ['sometimes', 'required', 'integer', Rule::exists('cities', 'id')->where('is_active', true)],
            'connections' => ['sometimes', 'array', 'list', 'max:4'],
            'connections.*' => ['distinct', Rule::in(config('mobile.connections'))],
            'nearby_visible' => ['sometimes', 'boolean'],
            'encounter_suggestions' => ['sometimes', 'boolean'],
            'city_discovery' => ['sometimes', 'boolean'],
            'location_history_enabled' => ['sometimes', 'boolean'],
            'message_privacy' => ['sometimes', Rule::in(['everyone', 'following', 'encounters'])],
            'show_activity' => ['sometimes', 'boolean'],
            'preferred_locale' => ['sometimes', Rule::in(['tr', 'en'])],
            'push_preferences' => ['sometimes', 'array:'.implode(',', array_keys(Inbox::DEFAULTS))],
            'push_preferences.*' => ['boolean'],
            'complete_profile' => ['sometimes', 'boolean'],
            'finish_setup' => ['sometimes', 'boolean'],
        ], AuthController::validationMessages());

        try {
            $user = DB::transaction(function () use ($request, $data) {
                $user = User::lockForUpdate()->findOrFail($request->user()->id);
                foreach (['bio', 'occupation_school'] as $field) {
                    if (array_key_exists($field, $data)) {
                        $data[$field] ??= '';
                    }
                }
                if (isset($data['push_preferences'])) {
                    $data['push_preferences'] += $user->push_preferences ?? [];
                }
                $user->fill(Arr::except($data, ['complete_profile', 'finish_setup']));
                if ($data['complete_profile'] ?? false) {
                    $user->onboarding_step = max(1, $user->onboarding_step);
                }
                if ($data['finish_setup'] ?? false) {
                    if ($user->onboarding_step < 2) {
                        throw ValidationException::withMessages(['finish_setup' => 'Önce profilini ve ilgi alanlarını tamamla.']);
                    }
                    $user->onboarding_step = 3;
                }
                $user->save();
                if (array_key_exists('location_history_enabled', $data) && ! $user->location_history_enabled) {
                    LocationData::clearHistory($user->id);
                }
                if ($user->wasChanged('city_id')) {
                    DB::table('user_locations')->where('user_id', $user->id)->delete();
                } elseif (array_key_exists('nearby_visible', $data) && ! $user->nearby_visible) {
                    DB::table('user_locations')->where('user_id', $user->id)->update(['visibility' => false]);
                }

                return $user;
            });
        } catch (UniqueConstraintViolationException $exception) {
            if (isset($data['username']) && User::where('username', $data['username'])->whereKeyNot($request->user()->id)->exists()) {
                throw ValidationException::withMessages(['username' => 'Bu kullanıcı adı kullanımda.']);
            }
            throw $exception;
        }

        return $this->profile($user, 'Profilin güncellendi.');
    }

    public function interests(Request $request): JsonResponse
    {
        return ApiResponse::ok($request->user()->interests()->get(['interests.id', 'name', 'slug', 'icon', 'is_active'])->makeHidden('pivot'));
    }

    public function saveInterests(Request $request): JsonResponse
    {
        $data = $request->validate([
            'interest_ids' => ['required', 'array', 'list', 'min:5', 'max:100'],
            'interest_ids.*' => ['required', 'integer', 'distinct', Rule::exists('interests', 'id')->where('is_active', true)],
        ], [
            'interest_ids.min' => 'En az 5 ilgi alanı seç.',
            'interest_ids.*.exists' => 'Seçtiğin ilgi alanlarından biri artık kullanılmıyor.',
        ]);

        $user = DB::transaction(function () use ($request, $data) {
            $user = User::lockForUpdate()->findOrFail($request->user()->id);
            $user->interests()->sync($data['interest_ids']);
            if ($user->onboarding_step === 1) {
                $user->forceFill(['onboarding_step' => 2])->save();
            }

            return $user;
        });

        return $this->profile($user, 'İlgi alanların kaydedildi.');
    }

    public function uploadAvatar(Request $request): JsonResponse
    {
        $request->validate([
            'avatar' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png,webp',
                'extensions:jpg,jpeg,png,webp', 'max:5120', 'dimensions:max_width=2048,max_height=2048'],
        ], ['avatar.*' => '2048 pikseli ve 5 MB boyutu aşmayan bir JPEG, PNG veya WebP fotoğrafı seç.']);

        $content = $this->reencode($request->file('avatar')->get(), 'avatar');

        $disk = Storage::disk(config('mobile.avatar_disk'));
        $path = 'avatars/'.Str::uuid().'.jpg';
        abort_unless($disk->put($path, $content), 500);

        try {
            [$user, $previous] = DB::transaction(function () use ($request, $path) {
                $user = User::lockForUpdate()->findOrFail($request->user()->id);
                $previous = $user->avatar;
                $user->forceFill(['avatar' => $path])->save();

                return [$user, $previous];
            });
        } catch (\Throwable $error) {
            $disk->delete($path);
            throw $error;
        }
        if ($previous !== null) {
            $disk->delete($previous);
        }

        return $this->profile($user, 'Profil fotoğrafın güncellendi.');
    }

    public function uploadCover(Request $request): JsonResponse
    {
        $request->validate([
            'cover' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png,webp',
                'extensions:jpg,jpeg,png,webp', 'max:8192', 'dimensions:min_width=320,min_height=120,max_width=4096,max_height=4096'],
        ], ['cover.*' => 'En az 320 piksel genişliğinde, 4096 pikseli ve 8 MB boyutu aşmayan bir JPEG, PNG veya WebP fotoğrafı seç.']);

        $content = $this->reencode($request->file('cover')->get(), 'cover');
        $disk = Storage::disk(config('mobile.avatar_disk'));
        $path = 'covers/'.Str::uuid().'.jpg';
        abort_unless($disk->put($path, $content), 500);

        try {
            [$user, $previous] = DB::transaction(function () use ($request, $path) {
                $user = User::lockForUpdate()->findOrFail($request->user()->id);
                $previous = $user->cover_image;
                $user->forceFill(['cover_image' => $path])->save();

                return [$user, $previous];
            });
        } catch (\Throwable $error) {
            $disk->delete($path);
            throw $error;
        }
        $this->forgetCover($previous);

        return $this->profile($user, 'Kapak fotoğrafın güncellendi.');
    }

    public function removeCover(Request $request): JsonResponse
    {
        [$user, $previous] = DB::transaction(function () use ($request) {
            $user = User::lockForUpdate()->findOrFail($request->user()->id);
            $previous = $user->cover_image;
            $user->forceFill(['cover_image' => null])->save();

            return [$user, $previous];
        });
        $this->forgetCover($previous);

        return $this->profile($user, 'Kapak fotoğrafın kaldırıldı.');
    }

    public function cover(string $filename): Response
    {
        $disk = Storage::disk(config('mobile.avatar_disk'));
        $path = 'covers/'.$filename;
        abort_unless(User::where('cover_image', $path)->where('account_status', 'active')->exists() && $disk->exists($path), 404);

        return $disk->response($path, $filename, [
            'Content-Type' => 'image/jpeg',
            'X-Content-Type-Options' => 'nosniff',
            'Cache-Control' => 'no-store',
        ]);
    }

    /** Only files this endpoint created are ever deleted; legacy values are left untouched. */
    private function forgetCover(?string $previous): void
    {
        if ($previous !== null && str_starts_with($previous, 'covers/')) {
            Storage::disk(config('mobile.avatar_disk'))->delete($previous);
        }
    }

    /** Re-encode so the original metadata (EXIF/GPS) and any embedded payload are never served. */
    private function reencode(string $binary, string $field): string
    {
        $image = @imagecreatefromstring($binary);
        if ($image === false) {
            throw ValidationException::withMessages([$field => 'Fotoğraf okunamadı.']);
        }
        $image = \App\Media\PrivateImage::upright($image, \App\Media\PrivateImage::orientation($binary));
        $flat = imagecreatetruecolor(imagesx($image), imagesy($image));
        imagefill($flat, 0, 0, imagecolorallocate($flat, 255, 255, 255));
        imagecopy($flat, $image, 0, 0, 0, 0, imagesx($image), imagesy($image));

        ob_start();
        try {
            $encoded = imagejpeg($flat, null, 88);
        } finally {
            $content = ob_get_clean();
        }
        abort_unless($encoded && is_string($content) && $content !== '', 500);

        return $content;
    }

    public function image(string $filename): Response
    {
        $disk = Storage::disk(config('mobile.avatar_disk'));
        $path = 'avatars/'.$filename;
        abort_unless(User::where('avatar', $path)->where('account_status', 'active')->exists() && $disk->exists($path), 404);

        return $disk->response($path, $filename, [
            'Content-Type' => 'image/jpeg',
            'X-Content-Type-Options' => 'nosniff',
            'Cache-Control' => 'no-store',
        ]);
    }

    private function profile(User $user, string $message = 'İşlem tamamlandı.'): JsonResponse
    {
        return ApiResponse::ok(new ProfileResource($user->load(['city', 'interests'])), $message);
    }
}
