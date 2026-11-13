<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('message_privacy', 16)->default('everyone');
            $table->boolean('show_activity')->default(false);
            $table->json('push_preferences')->nullable();
        });
        Schema::create('user_blocks', function (Blueprint $table): void {
            $table->foreignId('blocker_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('blocked_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('created_at');
            $table->primary(['blocker_id', 'blocked_id']);
            $table->index(['blocked_id', 'blocker_id']);
        });
        Schema::create('conversations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('first_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('second_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('requester_id')->constrained('users')->cascadeOnDelete();
            $table->string('status', 12);
            $table->timestamp('responded_at')->nullable();
            $table->timestamps();
            $table->unique(['first_user_id', 'second_user_id']);
            $table->index(['first_user_id', 'updated_at']);
            $table->index(['second_user_id', 'updated_at']);
        });
        Schema::create('conversation_participants', function (Blueprint $table): void {
            $table->foreignId('conversation_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->unsignedBigInteger('hidden_through')->default(0);
            $table->primary(['conversation_id', 'user_id']);
            $table->index(['user_id', 'conversation_id']);
        });
        Schema::create('messages', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('conversation_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sender_id')->constrained('users')->cascadeOnDelete();
            $table->uuid('request_id');
            $table->text('body');
            $table->string('type', 8);
            $table->string('image_path')->nullable();
            $table->timestamp('read_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['sender_id', 'request_id']);
            $table->index(['conversation_id', 'id']);
            $table->index(['conversation_id', 'read_at', 'id']);
        });
        Schema::create('app_notifications', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('type', 32);
            $table->unsignedBigInteger('entity_id')->nullable();
            $table->timestamp('created_at');
            $table->timestamp('read_at')->nullable();
            $table->index(['user_id', 'read_at', 'id']);
            $table->index(['user_id', 'id']);
        });
        Schema::create('user_devices', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('personal_access_token_id')->nullable()->constrained()->nullOnDelete();
            $table->string('platform', 8);
            $table->uuid('device_identifier')->unique();
            $table->text('push_token');
            $table->string('token_hash', 64)->unique();
            $table->string('app_version', 32)->nullable();
            $table->timestamp('last_seen_at');
            $table->boolean('is_active')->default(true);
            $table->index(['user_id', 'is_active']);
        });
        Schema::create('reports', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('reporter_id')->constrained('users')->cascadeOnDelete();
            $table->string('target_type', 16);
            $table->unsignedBigInteger('target_id');
            $table->string('reason', 24);
            $table->text('description')->nullable();
            $table->string('status', 12)->default('pending');
            $table->timestamp('created_at');
            $table->unique(['reporter_id', 'target_type', 'target_id']);
            $table->index(['target_type', 'target_id']);
        });
    }

    public function down(): void
    {
        foreach (['reports', 'user_devices', 'app_notifications', 'messages', 'conversation_participants', 'conversations', 'user_blocks'] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn(['message_privacy', 'show_activity', 'push_preferences']));
    }
};
