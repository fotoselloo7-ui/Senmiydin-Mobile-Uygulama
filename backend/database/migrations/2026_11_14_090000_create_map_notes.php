<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Map notes (digital letters) are an independent module: they are NOT posts and never enter the home feed.
 * Only the server-side grid-approximated coordinate is stored; the raw map selection is never persisted.
 */
return new class extends Migration {
    public function up(): void
    {
        Schema::create('map_notes', function (Blueprint $t): void {
            $t->id();
            $t->foreignId('user_id')->constrained()->cascadeOnDelete();
            $t->foreignId('city_id')->constrained('cities')->restrictOnDelete();
            $t->string('body', 700);
            $t->boolean('is_anonymous')->default(false);
            $t->decimal('approx_latitude', 8, 5);
            $t->decimal('approx_longitude', 8, 5);
            $t->string('place_label', 100)->nullable();
            $t->string('content_hash', 64)->nullable();
            $t->uuid('request_id')->nullable();
            $t->timestamp('expires_at');
            $t->timestamp('moderated_at')->nullable();
            $t->timestamps();
            $t->softDeletes();
            $t->unique(['user_id', 'request_id']);
            $t->index(['city_id', 'expires_at', 'approx_latitude', 'approx_longitude'], 'map_notes_region_index');
            $t->index(['approx_latitude', 'approx_longitude', 'created_at'], 'map_notes_point_index');
            $t->index(['user_id', 'content_hash', 'created_at'], 'map_notes_repeat_index');
            $t->index('expires_at');
        });
        Schema::create('map_note_replies', function (Blueprint $t): void {
            $t->id();
            $t->foreignId('map_note_id')->constrained('map_notes')->cascadeOnDelete();
            $t->foreignId('user_id')->constrained()->cascadeOnDelete();
            $t->string('body', 500);
            $t->boolean('is_anonymous')->default(false);
            $t->string('content_hash', 64)->nullable();
            $t->uuid('request_id')->nullable();
            $t->timestamp('moderated_at')->nullable();
            $t->timestamps();
            $t->softDeletes();
            $t->unique(['user_id', 'request_id']);
            $t->index(['map_note_id', 'created_at', 'id'], 'map_note_replies_thread_index');
            $t->index(['user_id', 'content_hash', 'created_at'], 'map_note_replies_repeat_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('map_note_replies');
        Schema::dropIfExists('map_notes');
    }
};
