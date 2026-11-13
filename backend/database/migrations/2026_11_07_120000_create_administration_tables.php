<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admins', function (Blueprint $table): void {
            $table->id();
            $table->string('name', 100);
            $table->string('email')->unique();
            $table->string('password');
            $table->string('role', 20)->default('moderator');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
        Schema::create('admin_audit_logs', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('admin_id')->nullable()->constrained()->nullOnDelete();
            $table->string('action', 64);
            $table->string('target_type', 40);
            $table->unsignedBigInteger('target_id')->nullable();
            $table->json('metadata')->nullable();
            $table->ipAddress('ip_address')->nullable();
            $table->timestamp('created_at');
            $table->index(['target_type', 'target_id']);
        });
        Schema::create('system_settings', function (Blueprint $table): void {
            $table->string('key', 64)->primary();
            $table->json('value');
            $table->timestamp('updated_at');
        });
        Schema::create('legal_pages', function (Blueprint $table): void {
            $table->string('slug', 48)->primary();
            $table->string('title', 120);
            $table->text('body');
            $table->timestamp('updated_at');
        });
        Schema::create('web_requests', function (Blueprint $table): void {
            $table->id();
            $table->string('type', 16);
            $table->string('name', 100);
            $table->string('email', 254);
            $table->string('subject', 120)->nullable();
            $table->text('message')->nullable();
            $table->timestamp('created_at');
            $table->timestamp('handled_at')->nullable();
            $table->index(['type', 'created_at']);
        });
        Schema::create('announcements', function (Blueprint $table): void {
            $table->id();
            $table->string('title', 120);
            $table->text('body');
            $table->foreignId('city_id')->nullable()->constrained();
            $table->foreignId('admin_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamp('publish_at')->index();
            $table->timestamp('published_at')->nullable();
            $table->unsignedBigInteger('last_user_id')->default(0);
            $table->boolean('send_push');
            $table->boolean('show_in_app');
            $table->timestamps();
        });
        Schema::table('app_notifications', function (Blueprint $table): void {
            $table->boolean('in_app')->default(true);
            $table->foreignId('announcement_id')->nullable()->constrained()->nullOnDelete();
        });
        Schema::table('posts', function (Blueprint $table): void {
            $table->timestamp('moderated_at')->nullable();
            $table->unsignedInteger('featured_rank')->nullable();
            $table->index(['city_id', 'featured_rank']);
        });
        Schema::table('post_comments', fn (Blueprint $table) => $table->timestamp('moderated_at')->nullable());
        Schema::table('encounter_requests', fn (Blueprint $table) => $table->softDeletes());
        Schema::table('reports', fn (Blueprint $table) => $table->timestamp('reviewed_at')->nullable());
        Schema::table('messages', fn (Blueprint $table) => $table->timestamp('moderated_at')->nullable());
    }

    public function down(): void
    {
        Schema::table('messages', fn (Blueprint $table) => $table->dropColumn('moderated_at'));
        Schema::table('reports', fn (Blueprint $table) => $table->dropColumn('reviewed_at'));
        Schema::table('encounter_requests', fn (Blueprint $table) => $table->dropSoftDeletes());
        Schema::table('post_comments', fn (Blueprint $table) => $table->dropColumn('moderated_at'));
        Schema::table('posts', function (Blueprint $table): void {
            $table->dropIndex(['city_id', 'featured_rank']);
            $table->dropColumn(['moderated_at', 'featured_rank']);
        });
        Schema::table('app_notifications', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('announcement_id');
            $table->dropColumn('in_app');
        });
        foreach (['announcements', 'web_requests', 'legal_pages', 'system_settings', 'admin_audit_logs', 'admins'] as $table) {
            Schema::dropIfExists($table);
        }
    }
};
