<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Single-level comment replies: every reply points straight at a top-level comment (enforced server-side).
        Schema::table('post_comments', function (Blueprint $table): void {
            $table->foreignId('parent_id')->nullable()->after('post_id')->constrained('post_comments')->cascadeOnDelete();
            $table->index(['post_id', 'parent_id', 'id'], 'post_comments_thread_index');
        });

        // "Mektuplarım": the owner's private archive is independent of the 7-day public lifecycle.
        Schema::table('map_notes', function (Blueprint $table): void {
            // The real date of the original letter. A re-publication gets a fresh created_at / expires_at but keeps this.
            $table->timestamp('occurred_at')->nullable()->after('place_label');
            // Set when the owner takes the letter off the public map ("Haritadan Kaldır"). It stays in the owner's archive.
            $table->timestamp('archived_at')->nullable()->after('moderated_at');
            // A re-publication is a NEW public note that points back to the letter it came from (old replies stay on the old one).
            $table->foreignId('reposted_from_id')->nullable()->after('archived_at')->constrained('map_notes')->nullOnDelete();
            $table->index(['user_id', 'archived_at', 'expires_at'], 'map_notes_owner_lifecycle_index');
        });
        DB::table('map_notes')->whereNull('occurred_at')->update(['occurred_at' => DB::raw('created_at')]);

        // Private per-user "opened" tracking for the "new letters near you" count. Never exposed to anyone else.
        Schema::create('map_note_reads', function (Blueprint $table): void {
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('map_note_id')->constrained('map_notes')->cascadeOnDelete();
            $table->timestamp('read_at');
            $table->primary(['user_id', 'map_note_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('map_note_reads');
        Schema::table('map_notes', function (Blueprint $table): void {
            $table->dropIndex('map_notes_owner_lifecycle_index');
            $table->dropConstrainedForeignId('reposted_from_id');
            $table->dropColumn(['archived_at', 'occurred_at']);
        });
        Schema::table('post_comments', function (Blueprint $table): void {
            $table->dropIndex('post_comments_thread_index');
            $table->dropConstrainedForeignId('parent_id');
        });
    }
};
