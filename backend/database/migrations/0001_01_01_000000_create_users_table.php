<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table): void {
            $table->id();
            $table->string('name', 100);
            $table->string('username', 24)->unique();
            $table->string('email')->unique();
            $table->string('password');
            $table->date('birth_date');
            $table->foreignId('city_id')->constrained()->restrictOnDelete();
            $table->string('avatar')->nullable();
            $table->string('cover_image')->nullable();
            $table->string('bio', 160)->default('');
            $table->string('occupation_school', 120)->default('');
            $table->string('account_status', 20)->default('active');
            $table->timestamp('last_seen_at')->nullable();
            $table->json('connections')->nullable();
            $table->boolean('nearby_visible')->default(false);
            $table->boolean('encounter_suggestions')->default(false);
            $table->boolean('city_discovery')->default(false);
            $table->unsignedTinyInteger('onboarding_step')->default(0);
            $table->rememberToken();
            $table->timestamps();
        });

        Schema::create('password_reset_tokens', function (Blueprint $table): void {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table): void {
            $table->string('id')->primary();
            $table->foreignId('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sessions');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('users');
    }
};
