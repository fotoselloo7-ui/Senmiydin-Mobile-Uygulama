<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('encounter_requests', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('requester_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('target_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('source_post_id')->nullable()->unique()->constrained('posts')->nullOnDelete();
            $table->string('status', 12)->default('pending');
            $table->timestamp('responded_at')->nullable();
            $table->timestamps();
            $table->index(['requester_id', 'status', 'created_at'], 'encounter_requester_status');
            $table->index(['target_user_id', 'status', 'created_at'], 'encounter_target_status');
        });
        Schema::create('encounters', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('request_id')->unique()->constrained('encounter_requests')->cascadeOnDelete();
            $table->timestamp('confirmed_at')->index();
            $table->timestamps();
        });
        Schema::table('posts', function (Blueprint $table): void {
            $table->foreignId('encounter_id')->nullable()->unique()->constrained()->cascadeOnDelete();
            $table->string('story_title', 100)->nullable();
            $table->string('story_status', 12)->nullable();
            $table->unsignedInteger('story_revision')->nullable();
            $table->index(['story_status', 'visibility', 'city_id', 'created_at'], 'published_encounters_index');
        });
    }

    public function down(): void
    {
        Schema::table('posts', function (Blueprint $table): void {
            $table->dropForeign(['encounter_id']);
            $table->dropUnique(['encounter_id']);
            $table->dropIndex('published_encounters_index');
            $table->dropColumn(['encounter_id', 'story_title', 'story_status', 'story_revision']);
        });
        Schema::dropIfExists('encounters');
        Schema::dropIfExists('encounter_requests');
    }
};
