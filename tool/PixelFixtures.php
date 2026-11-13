<?php

namespace Senmiydin\Development;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/** Only explicit, owned device-test identities; never a wildcard reset. */
final class PixelFixtures
{
    public static function guard(): void
    {
        if (! app()->environment('local', 'development', 'testing')) {
            throw new \RuntimeException('REFUSE: device fixtures require development or testing.');
        }
        if (! app()->environment('testing') && (DB::getDriverName() !== 'mysql' ||
            config('database.connections.mysql.host') !== '127.0.0.1' ||
            (int) config('database.connections.mysql.port') !== 33076)) {
            throw new \RuntimeException('REFUSE: unexpected development database.');
        }
    }

    public function create(): array
    {
        self::guard();
        $run = (string) Str::uuid();
        $password = Str::random(28).'aA1!';
        $city = DB::table('cities')->where('slug', 'alanya')->value('id');
        $accounts = [];
        $roles = ['encounter_writer' => 'Deniz Kaya', 'encounter_reader' => 'Elif Aydın',
            'social_writer' => 'Deniz Kaya', 'social_reader' => 'Ece Yılmaz',
            'message_writer' => 'Deniz Kaya', 'message_reader' => 'Elif Aydın',
            'location' => 'Deniz Kaya', 'history_writer' => 'Deniz Kaya', 'history_reader' => 'Elif Aydın'];
        DB::transaction(function () use ($run, $password, $city, $roles, &$accounts): void {
            foreach ($roles as $role => $name) {
                $username = (str_contains($role, 'reader') ? 'elif_' : 'deniz_').strtolower(Str::random(10));
                $email = $run.'.'.$role.'@example.test';
                $history = str_starts_with($role, 'history_');
                $user = User::create(['name' => $name, 'username' => $username, 'email' => $email, 'password' => $password,
                    'birth_date' => '1995-04-12', 'city_id' => $city, 'nearby_visible' => true, 'city_discovery' => true,
                    'location_history_enabled' => $history, 'push_preferences' => ['location_match' => true]]);
                $avatarSource = dirname(base_path()).'/assets/images/'.(str_contains($role, 'reader') ? 'user_1.jpg' : 'user_0.jpg');
                $avatar = null;
                if (is_file($avatarSource)) {
                    $avatar = 'avatars/'.Str::uuid().'.jpg';
                    Storage::disk(config('mobile.avatar_disk'))->put($avatar, file_get_contents($avatarSource), 'private');
                }
                $user->forceFill(['avatar' => $avatar, 'onboarding_step' => 3])->save();
                $user->interests()->sync(DB::table('interests')->orderBy('id')->limit(5)->pluck('id'));
                $accounts[$role] = ['id' => $user->id, 'username' => $username, 'email' => $email];
                if ($history) {
                    foreach ([['istanbul', 41.015, 28.980, now()->subHours(2)->startOfMinute()],
                        ['ankara', 39.920, 32.855, now()->subMinutes(15)->startOfMinute()]] as [$slug,$lat,$lng,$at]) {
                        DB::table('user_location_history')->insert(['user_id' => $user->id,
                            'city_id' => DB::table('cities')->where('slug', $slug)->value('id'),
                            'latitude' => $lat, 'longitude' => $lng, 'recorded_at' => $at]);
                    }
                }
            }
        });

        return ['run' => $run, 'started_at' => now()->toISOString(), 'password' => $password, 'accounts' => $accounts,
            'registration' => ['username' => 'ada_'.strtolower(Str::random(10)), 'email' => $run.'.registration@example.test'],
            'event_at' => now()->subHours(2)->startOfMinute()->toISOString(),
            'departure_at' => now()->subMinutes(15)->startOfMinute()->toISOString()];
    }

    public function register(array &$state, int $id): void
    {
        self::guard();
        if (isset($state['accounts']['registration'])) {
            if ($state['accounts']['registration']['id'] !== $id) {
                throw new \RuntimeException('Account identity changed.');
            }

            return;
        }
        $user = User::findOrFail($id);
        if ($user->username !== $state['registration']['username'] || $user->email !== $state['registration']['email']) {
            throw new \RuntimeException('Unowned registration account.');
        }
        $state['accounts']['registration'] = ['id' => $id, 'username' => $user->username, 'email' => $user->email];
    }

    public function cleanup(array $state): array
    {
        self::guard();
        if (! Str::isUuid($state['run'] ?? '')) {
            throw new \RuntimeException('Invalid ownership ledger.');
        }
        $ids = [];
        foreach ($state['accounts'] as $account) {
            $user = User::find($account['id']);
            if (! $user) {
                continue;
            }
            $erased = $user->erased_at && $user->account_status === 'deleted' && str_ends_with($user->email, '@deleted.invalid');
            if (! $erased && ($user->email !== $account['email'] || ! str_starts_with($user->email, $state['run'].'.'))) {
                throw new \RuntimeException('REFUSE: fixture ownership mismatch.');
            }
            $ids[] = $user->id;
        }

        return $this->removeOwned($ids);
    }

    public function assertDemoQuality(): void
    {
        self::guard();
        $ids = User::whereIn('email', ['demo@senmiydin.local', 'elif@senmiydin.local'])->pluck('id');
        foreach (DB::table('posts')->whereIn('user_id', $ids)->whereNull('deleted_at')->get(['body', 'story_title']) as $post) {
            foreach ([$post->body, $post->story_title] as $text) {
                if (preg_match('/[0-9]{13}\\s*$/u', $text ?? '') || preg_match('/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i', $text ?? '')) {
                    throw new \RuntimeException('Visible Demo content contains an internal suffix.');
                }
            }
        }
    }

    public function cleanupKnownLegacyAccounts(array $accounts): array
    {
        self::guard();
        $ids = [];
        foreach ($accounts as $expected) {
            $user = User::findOrFail($expected['id']);
            $qa = preg_match('/^qa(writer|reader)[0-9]{13}$/', $user->username) &&
                in_array($user->name, ['Deniz Pixel QA', 'Ece Pixel QA'], true);
            $registration = preg_match('/^pixel[0-9]{13}$/', $user->username) &&
                in_array($user->name, ['Pixel Deneme', 'Pixel Güncel'], true);
            if ((! $qa && ! $registration) || $user->email !== $user->username.'@example.test' ||
                $user->email !== $expected['email'] || $user->username !== $expected['username']) {
                throw new \RuntimeException('REFUSE: unknown legacy identity.');
            }
            $ids[] = $user->id;
        }

        return $this->removeOwned($ids);
    }

    private function removeOwned(array $ids): array
    {
        self::guard();
        if (! $ids) {
            return ['users' => 0, 'posts' => 0, 'conversations' => 0, 'clean' => true];
        }
        $postIds = DB::table('posts')->whereIn('user_id', $ids)->pluck('id')->all();
        $requestIds = DB::table('encounter_requests')->whereIn('requester_id', $ids)->orWhereIn('target_user_id', $ids)->pluck('id')->all();
        foreach (DB::table('encounter_requests')->whereIn('id', $requestIds)->get() as $request) {
            if (! in_array($request->requester_id, $ids) || ! in_array($request->target_user_id, $ids)) {
                throw new \RuntimeException('REFUSE: fixture encounter contains an unowned participant.');
            }
        }
        $conversations = DB::table('conversations')->whereIn('first_user_id', $ids)->orWhereIn('second_user_id', $ids)->get();
        // A device fixture must not delete an unknown participant's conversation.
        foreach ($conversations as $conversation) {
            if (! in_array($conversation->first_user_id, $ids) || ! in_array($conversation->second_user_id, $ids)) {
                throw new \RuntimeException('REFUSE: fixture conversation contains an unowned participant.');
            }
        }
        $conversationIds = $conversations->pluck('id')->all();
        DB::transaction(function () use ($ids, $postIds, $requestIds, $conversationIds): void {
            foreach (DB::table('post_media')->whereIn('post_id', $postIds)->get() as $media) {
                $this->queueFile($media->disk, $media->file_path);
            }
            foreach (DB::table('messages')->whereIn('conversation_id', $conversationIds)->whereNotNull('image_path')->get() as $message) {
                $this->queueFile(config('mobile.post_media_disk'), $message->image_path);
            }
            foreach (User::whereKey($ids)->get() as $user) {
                if ($user->avatar) {
                    $this->queueFile(config('mobile.avatar_disk'), $user->avatar);
                }
                if ($user->cover_image) {
                    $this->queueFile(config('mobile.avatar_disk'), $user->cover_image);
                }
            }
            DB::table('app_notifications')->whereIn('user_id', $ids)->orWhereIn('actor_id', $ids)->delete();
            DB::table('app_notifications')->whereIn('type', ['like', 'comment', 'nearby_activity', 'location_match'])->whereIn('entity_id', $postIds)->delete();
            DB::table('app_notifications')->where('type', 'like', 'encounter_%')->whereIn('entity_id', $requestIds)->delete();
            DB::table('app_notifications')->whereIn('type', ['message', 'message_request'])->whereIn('entity_id', $conversationIds)->delete();
            DB::table('reports')->whereIn('reporter_id', $ids)->delete();
            DB::table('personal_access_tokens')->where('tokenable_type', User::class)->whereIn('tokenable_id', $ids)->delete();
            foreach (User::whereKey($ids)->pluck('email') as $email) {
                DB::table('password_reset_tokens')->where('email', $email)->delete();
            }
            DB::table('users')->whereIn('id', $ids)->delete();
        });
        $clean = ! DB::table('users')->whereIn('id', $ids)->exists() &&
            ! DB::table('posts')->whereIn('id', $postIds)->exists() &&
            ! DB::table('post_comments')->whereIn('user_id', $ids)->exists() &&
            ! DB::table('app_notifications')->whereIn('user_id', $ids)->exists() &&
            ! DB::table('location_matches')->whereIn('user_id', $ids)->orWhereIn('post_id', $postIds)->exists() &&
            ! DB::table('encounter_requests')->whereIn('id', $requestIds)->exists() &&
            ! DB::table('conversations')->whereIn('id', $conversationIds)->exists();
        if (! $clean) {
            throw new \RuntimeException('Fixture cleanup assertion failed.');
        }

        return ['users' => count($ids), 'posts' => count($postIds), 'conversations' => count($conversationIds), 'clean' => true];
    }

    private function queueFile(string $disk, string $path): void
    {
        if (! preg_match('~^(posts|messages|avatars|covers)/[0-9a-f-]{36}\.(jpg|jpeg|png|webp)$~i', $path)) {
            throw new \RuntimeException('Unexpected fixture media path.');
        }
        DB::table('media_deletions')->insertOrIgnore(['disk' => $disk, 'path' => $path, 'created_at' => now()]);
    }
}
