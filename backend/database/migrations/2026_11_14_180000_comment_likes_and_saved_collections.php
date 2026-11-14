<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Likes on top-level comments and on replies (single table: a reply is a comment with a parent).
        Schema::create('comment_likes', function (Blueprint $table): void {
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('comment_id')->constrained('post_comments')->cascadeOnDelete();
            $table->timestamp('created_at');
            $table->primary(['user_id', 'comment_id']);
            $table->index('comment_id');
        });

        // Private, per-user collections that sit on top of the normal "Kaydedilenler" list.
        Schema::create('saved_collections', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('name', 40);
            // Lower-cased name: one user cannot own two collections that differ only by case.
            $table->string('name_key', 160);
            $table->timestamps();
            $table->unique(['user_id', 'name_key']);
        });
        Schema::create('saved_collection_posts', function (Blueprint $table): void {
            $table->foreignId('collection_id')->constrained('saved_collections')->cascadeOnDelete();
            $table->foreignId('post_id')->constrained()->cascadeOnDelete();
            $table->timestamp('created_at');
            $table->primary(['collection_id', 'post_id']);
            $table->index('post_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('saved_collection_posts');
        Schema::dropIfExists('saved_collections');
        Schema::dropIfExists('comment_likes');
    }
};
