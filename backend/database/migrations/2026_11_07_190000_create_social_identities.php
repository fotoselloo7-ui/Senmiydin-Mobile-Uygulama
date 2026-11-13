<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('social_identities', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('provider', 12);
            $table->string('subject_hash', 64);
            $table->string('client_id');
            $table->text('refresh_token')->nullable();
            $table->timestamps();
            $table->unique(['provider', 'subject_hash']);
        });
        Schema::create('oauth_revocations', function (Blueprint $table): void {
            $table->id();
            $table->string('client_id');
            $table->text('refresh_token');
            $table->timestamp('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('oauth_revocations');
        Schema::dropIfExists('social_identities');
    }
};
