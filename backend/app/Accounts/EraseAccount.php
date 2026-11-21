<?php

namespace App\Accounts;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class EraseAccount
{
    // Keep only anonymous relational identifiers; no restoration of erased accounts.
    public function erase(User $user): void
    {
        DB::transaction(function () use ($user): void {
            $user = User::lockForUpdate()->findOrFail($user->id);
            abort_if($user->erased_at !== null, 409);
            $id = $user->id;
            foreach (array_filter([$user->avatar, $user->cover_image]) as $path) {
                $this->media(config('mobile.avatar_disk'), $path);
            }
            $posts = DB::table('posts')->where('user_id', $id)->select('id');
            DB::table('post_media')->whereIn('post_id', $posts)->orderBy('id')->chunkById(100, function ($items): void {
                foreach ($items as $item) {
                    $this->media($item->disk, $item->file_path);
                }
            });
            DB::table('messages')->where('sender_id', $id)->whereNotNull('image_path')->orderBy('id')->chunkById(100, function ($items): void {
                foreach ($items as $item) {
                    $this->media(config('mobile.post_media_disk'), $item->image_path);
                }
            });
            DB::table('messages')->where('sender_id', $id)->whereNotNull('audio_path')->orderBy('id')->chunkById(100, function ($items): void {
                foreach ($items as $item) {
                    $this->media(config('mobile.post_media_disk'), $item->audio_path);
                }
            });
            DB::table('map_notes')->where('user_id', $id)->whereNotNull('image_path')->orderBy('id')->chunkById(100, function ($items): void {
                foreach ($items as $item) {
                    $this->media(config('mobile.post_media_disk'), $item->image_path);
                }
            });
            // Memories are the person's own content: every row and file goes with the account.
            $memories = DB::table('memories')->where('user_id', $id)->select('id');
            DB::table('memory_media')->whereIn('memory_id', $memories)->orderBy('id')->chunkById(100, function ($items): void {
                foreach ($items as $item) {
                    $this->media($item->disk, $item->path);
                    if ($item->thumb_path) {
                        $this->media($item->disk, $item->thumb_path);
                    }
                }
            });
            DB::table('memory_media')->whereIn('memory_id', $memories)->delete();
            DB::table('memories')->where('user_id', $id)->delete();
            DB::table('location_matches')->whereIn('post_id', $posts)->delete();
            DB::table('post_media')->whereIn('post_id', $posts)->delete();
            DB::table('post_travel_details')->whereIn('post_id', $posts)->delete();
            DB::table('posts')->where('user_id', $id)->update([
                'body' => '', 'story_title' => null, 'visibility' => 'private',
                'approx_latitude' => null, 'approx_longitude' => null, 'occurred_at' => null, 'place_label' => null, 'content_hash' => null,
                'featured_rank' => null, 'deleted_at' => now(), 'updated_at' => now(),
            ]);
            // Map notes and replies leave public view immediately; the rows are purged by the retention lifecycle.
            DB::table('map_notes')->where('user_id', $id)->update(['body' => '', 'content_hash' => null, 'place_label' => null, 'image_path' => null, 'deleted_at' => now(), 'updated_at' => now()]);
            DB::table('map_note_reads')->where('user_id', $id)->delete();
            DB::table('map_note_replies')->where('user_id', $id)->update(['body' => '', 'content_hash' => null, 'deleted_at' => now(), 'updated_at' => now()]);
            // Their likes and every like on their comments, plus their private collections.
            DB::table('comment_likes')->where('user_id', $id)->delete();
            DB::table('comment_likes')->whereIn('comment_id', DB::table('post_comments')->where('user_id', $id)->select('id'))->delete();
            DB::table('saved_collection_posts')->whereIn('collection_id', DB::table('saved_collections')->where('user_id', $id)->select('id'))->delete();
            DB::table('saved_collections')->where('user_id', $id)->delete();
            DB::table('post_comments')->where('user_id', $id)->update(['body' => '', 'content_hash' => null, 'deleted_at' => now(), 'updated_at' => now()]);
            DB::table('messages')->where('sender_id', $id)->update(['body' => '', 'image_path' => null, 'audio_path' => null, 'audio_duration_ms' => null, 'gift_id' => null, 'deleted_at' => now(), 'updated_at' => now()]);
            DB::table('encounter_requests')->where(fn ($query) => $query->where('requester_id', $id)->orWhere('target_user_id', $id))
                ->update(['deleted_at' => now()]);
            DB::table('conversations')->where(fn ($query) => $query->where('first_user_id', $id)->orWhere('second_user_id', $id))
                ->update(['status' => 'cancelled', 'responded_at' => now(), 'updated_at' => now()]);
            foreach (['user_locations', 'user_location_history', 'location_matches', 'user_interests', 'post_likes', 'post_saves', 'conversation_participants'] as $table) {
                DB::table($table)->where('user_id', $id)->delete();
            }
            DB::table('user_follows')->where('follower_id', $id)->orWhere('followed_id', $id)->delete();
            DB::table('user_blocks')->where('blocker_id', $id)->orWhere('blocked_id', $id)->delete();
            DB::table('app_notifications')->where('user_id', $id)->orWhere('actor_id', $id)->delete();
            DB::table('user_devices')->where('user_id', $id)->delete();
            DB::table('password_reset_tokens')->where('email', $user->email)->delete();
            DB::table('reports')->where('reporter_id', $id)->update(['description' => null]);
            foreach (DB::table('social_identities')->where('user_id', $id)->get() as $identity) {
                if ($identity->provider === 'apple' && $identity->refresh_token) {
                    DB::table('oauth_revocations')->insert(['client_id' => $identity->client_id, 'refresh_token' => $identity->refresh_token, 'created_at' => now()]);
                }
            }
            DB::table('social_identities')->where('user_id', $id)->delete();
            $user->tokens()->delete();
            $user->forceFill([
                'name' => 'Silinmiş hesap', 'username' => 'deleted_'.Str::lower(Str::random(16)),
                'email' => Str::uuid().'@deleted.invalid', 'password' => Str::random(64),
                'birth_date' => '1900-01-01', 'city_id' => DB::table('cities')->min('id'), 'place_id' => null, 'has_password' => true,
                'avatar' => null, 'cover_image' => null, 'bio' => '', 'occupation_school' => '',
                'connections' => [], 'account_status' => 'deleted', 'last_seen_at' => null,
                'nearby_visible' => false, 'encounter_suggestions' => false, 'city_discovery' => false,
                'active_city_id' => null, 'active_city_source' => null, 'location_history_enabled' => false, 'show_activity' => false, 'push_preferences' => [],
                'remember_token' => null, 'erased_at' => now(),
            ])->save();
        });
    }

    private function media(string $disk, string $path): void
    {
        DB::table('media_deletions')->insertOrIgnore(['disk' => $disk, 'path' => $path, 'created_at' => now()]);
    }
}
