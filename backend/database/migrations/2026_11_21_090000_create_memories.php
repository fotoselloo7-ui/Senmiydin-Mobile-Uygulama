<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Anılar (memories): a permanent, owner-curated section of the profile.
 *
 * A memory is an independent snapshot. `source_type` / `source_id` only remember where it was created from (a map note
 * or a post) so the same source is not copied twice; there is deliberately NO foreign key, so deleting or expiring the
 * source never touches the memory, and editing the memory never touches the source. Its photos are separate files.
 * Only the approximate area (`city_id`, optional `place_id`, a label and a grid-snapped point) is stored: never a raw
 * coordinate, and the point never leaves the server.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('memories', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('source_type', 16)->nullable();
            $table->unsignedBigInteger('source_id')->nullable();
            $table->text('body');
            $table->timestamp('occurred_at');
            $table->foreignId('city_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('place_id')->nullable()->constrained()->nullOnDelete();
            $table->string('place_label', 255)->nullable();
            $table->decimal('approx_latitude', 8, 5)->nullable();
            $table->decimal('approx_longitude', 8, 5)->nullable();
            // private | followers | public | area
            $table->string('visibility', 12)->default('private');
            $table->boolean('is_hidden')->default(false);
            $table->string('content_hash', 64)->nullable();
            $table->uuid('request_id')->nullable();
            $table->timestamp('moderated_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->index(['user_id', 'deleted_at', 'occurred_at', 'id'], 'memories_owner_timeline');
            $table->index(['user_id', 'source_type', 'source_id'], 'memories_source_lookup');
            $table->index(['city_id', 'visibility'], 'memories_area_lookup');
            $table->unique(['user_id', 'request_id'], 'memories_request_unique');
        });

        Schema::create('memory_media', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('memory_id')->constrained()->cascadeOnDelete();
            $table->string('disk', 32);
            $table->string('path');
            $table->string('thumb_path')->nullable();
            $table->unsignedTinyInteger('sort_order')->default(0);
            $table->unsignedSmallInteger('width');
            $table->unsignedSmallInteger('height');
            $table->decimal('aspect_ratio', 6, 4);
            $table->string('mime_type', 32)->default('image/jpeg');
            $table->index(['memory_id', 'sort_order']);
        });

        Schema::table('users', function (Blueprint $table): void {
            // The visibility a NEW memory starts with. Changing it never rewrites the memories that already exist.
            $table->string('memory_default_visibility', 12)->default('private');
        });
    }

    public function down(): void
    {
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn('memory_default_visibility'));
        Schema::dropIfExists('memory_media');
        Schema::dropIfExists('memories');
    }
};
