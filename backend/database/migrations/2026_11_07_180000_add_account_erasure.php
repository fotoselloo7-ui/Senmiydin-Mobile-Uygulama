<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('users', fn (Blueprint $table) => $table->timestamp('erased_at')->nullable()->index());
        Schema::create('media_deletions', function (Blueprint $table): void {
            $table->id();
            $table->string('disk', 32);
            $table->string('path');
            $table->timestamp('created_at');
            $table->unique(['disk', 'path']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('media_deletions');
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn('erased_at'));
    }
};
