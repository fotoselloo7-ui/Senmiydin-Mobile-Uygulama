<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', fn (Blueprint $table) => $table->boolean('location_history_enabled')->default(false));
        Schema::create('user_locations', function (Blueprint $table): void {
            $table->foreignId('user_id')->primary()->constrained()->cascadeOnDelete();
            $table->foreignId('city_id')->constrained()->restrictOnDelete();
            $table->decimal('latitude', 8, 5);
            $table->decimal('longitude', 8, 5);
            $table->unsignedInteger('accuracy');
            $table->timestamp('recorded_at')->index();
            $table->boolean('visibility')->default(false);
            $table->timestamps();
            $table->index(['city_id', 'visibility', 'latitude', 'longitude']);
        });
        Schema::create('user_location_history', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('city_id')->constrained()->restrictOnDelete();
            $table->decimal('latitude', 8, 5);
            $table->decimal('longitude', 8, 5);
            $table->timestamp('recorded_at')->index();
            $table->index(['city_id', 'latitude', 'longitude', 'recorded_at'], 'history_region_index');
            $table->index(['user_id', 'recorded_at']);
        });
        Schema::table('posts', function (Blueprint $table): void {
            $table->decimal('approx_latitude', 8, 5)->nullable();
            $table->decimal('approx_longitude', 8, 5)->nullable();
            $table->index(['city_id', 'visibility', 'approx_latitude', 'approx_longitude'], 'posts_region_index');
        });
        Schema::create('location_matches', function (Blueprint $table): void {
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('post_id')->constrained()->cascadeOnDelete();
            $table->timestamp('matched_at')->index();
            $table->unsignedInteger('distance_meters');
            $table->string('status', 16)->default('pending');
            $table->primary(['user_id', 'post_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('location_matches');
        Schema::table('posts', function (Blueprint $table): void {
            $table->dropIndex('posts_region_index');
            $table->dropColumn(['approx_latitude', 'approx_longitude']);
        });
        Schema::dropIfExists('user_location_history');
        Schema::dropIfExists('user_locations');
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn('location_history_enabled'));
    }
};
