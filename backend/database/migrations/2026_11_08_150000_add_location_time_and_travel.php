<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('users', function (Blueprint $t): void {
            $t->foreignId('active_city_id')->nullable()->constrained('cities')->nullOnDelete();
            $t->string('active_city_source', 12)->nullable();
        });
        Schema::table('user_locations', fn (Blueprint $t) => $t->unsignedBigInteger('city_id')->nullable()->change());
        Schema::table('posts', function (Blueprint $t): void {
            $t->string('content_hash', 64)->nullable();
            $t->index(['user_id', 'content_hash', 'created_at'], 'posts_content_repeat_index');
            $t->timestamp('occurred_at')->nullable()->index();
            $t->string('place_label', 100)->nullable();
            $t->index(['city_id', 'occurred_at'], 'posts_city_occurrence_index');
        });
        Schema::table('post_comments', function (Blueprint $t): void {
            $t->string('content_hash', 64)->nullable();
            $t->index(['user_id', 'content_hash', 'created_at'], 'comments_content_repeat_index');
        });
        Schema::create('post_travel_details', function (Blueprint $t): void {
            $t->foreignId('post_id')->primary()->constrained()->cascadeOnDelete();
            $t->string('transport_type', 12);
            $t->foreignId('origin_city_id')->constrained('cities')->restrictOnDelete();
            $t->foreignId('destination_city_id')->constrained('cities')->restrictOnDelete();
            $t->timestamp('departure_at')->nullable();
            $t->string('operator_name', 80)->nullable();
            $t->string('service_code', 40)->nullable();
            $t->string('vehicle_identifier', 40)->nullable();
            $t->boolean('is_public')->default(false);
            $t->index(['origin_city_id', 'departure_at']);
            $t->index(['destination_city_id', 'departure_at']);
        });
        Schema::table('location_matches', function (Blueprint $t): void {
            $t->unsignedInteger('distance_meters')->nullable()->change();
            $t->unsignedInteger('time_difference_seconds')->default(0);
            $t->unsignedSmallInteger('score')->default(0);
            $t->string('strength', 10)->default('weak');
            $t->string('notification_state', 12)->default('pending');
            $t->index(['user_id', 'score', 'post_id'], 'matches_recommendation_index');
        });
        Schema::table('user_location_history', fn (Blueprint $t) => $t->index(['city_id', 'recorded_at', 'latitude', 'longitude'], 'history_city_time_index'));
    }

    public function down(): void
    {
        Schema::table('user_location_history', fn (Blueprint $t) => $t->dropIndex('history_city_time_index'));
        \Illuminate\Support\Facades\DB::table('location_matches')->whereNull('distance_meters')->delete();
        Schema::table('location_matches', function (Blueprint $t): void {
            $t->unsignedInteger('distance_meters')->nullable(false)->change();
            $t->dropIndex('matches_recommendation_index');
            $t->dropColumn(['time_difference_seconds', 'score', 'strength', 'notification_state']);
        });
        if (!Schema::hasIndex('post_comments', ['user_id'])) {
            Schema::table('post_comments', fn (Blueprint $t) => $t->index('user_id', 'comments_user_lookup_index'));
        }
        Schema::table('post_comments', function (Blueprint $t): void {
            $t->dropIndex('comments_content_repeat_index');
            $t->dropColumn('content_hash');
        });
        Schema::dropIfExists('post_travel_details');
        if (!Schema::hasIndex('posts', ['user_id'])) {
            Schema::table('posts', fn (Blueprint $t) => $t->index('user_id', 'posts_user_lookup_index'));
        }
        Schema::table('posts', function (Blueprint $t): void {
            $t->dropIndex('posts_city_occurrence_index');
            $t->dropIndex('posts_content_repeat_index');
            $t->dropColumn('content_hash');
            $t->dropIndex(['occurred_at']);
            $t->dropColumn(['occurred_at', 'place_label']);
        });
        // Unresolved coordinates must not acquire a guessed city on rollback.
        \Illuminate\Support\Facades\DB::table('user_locations')->whereNull('city_id')->delete();
        Schema::table('user_locations', fn (Blueprint $t) => $t->unsignedBigInteger('city_id')->nullable(false)->change());
        Schema::table('users', function (Blueprint $t): void {
            $t->dropForeign(['active_city_id']);
            $t->dropColumn(['active_city_id', 'active_city_source']);
        });
    }
};
