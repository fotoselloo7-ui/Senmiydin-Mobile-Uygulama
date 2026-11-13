<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('posts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('city_id')->constrained()->restrictOnDelete();
            $table->text('body');
            $table->string('type', 16);
            $table->boolean('is_anonymous')->default(false);
            $table->string('visibility', 12)->default('city');
            $table->boolean('comments_enabled')->default(true);
            $table->uuid('request_id');
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['user_id', 'request_id']);
            $table->index(['city_id', 'visibility', 'deleted_at', 'created_at', 'id']);
            $table->index(['user_id', 'deleted_at', 'created_at', 'id']);
            $table->index(['deleted_at', 'id']);
        });
        Schema::create('post_media', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('post_id')->constrained()->cascadeOnDelete();
            $table->string('file_path');
            $table->string('disk', 32);
            $table->unsignedTinyInteger('sort_order');
            $table->unsignedSmallInteger('width');
            $table->unsignedSmallInteger('height');
            $table->string('mime_type', 32);
            $table->unique(['post_id', 'sort_order']);
        });
        Schema::create('post_comments', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('post_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('body', 500);
            $table->timestamps();
            $table->softDeletes();
            $table->index(['post_id', 'deleted_at', 'id']);
        });
        foreach (['post_likes', 'post_saves'] as $name) {
            Schema::create($name, function (Blueprint $table): void {
                $table->foreignId('user_id')->constrained()->cascadeOnDelete();
                $table->foreignId('post_id')->constrained()->cascadeOnDelete();
                $table->timestamp('created_at');
                $table->primary(['user_id', 'post_id']);
                $table->index(['post_id', 'user_id']);
            });
        }
        Schema::create('user_follows', function (Blueprint $table): void {
            $table->foreignId('follower_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('followed_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('created_at');
            $table->primary(['follower_id', 'followed_id']);
            $table->index(['followed_id', 'follower_id']);
        });
    }

    public function down(): void
    {
        foreach (['user_follows', 'post_saves', 'post_likes', 'post_comments', 'post_media', 'posts'] as $table) {
            Schema::dropIfExists($table);
        }
    }
};
