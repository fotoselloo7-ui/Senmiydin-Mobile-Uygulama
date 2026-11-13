<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('announcements', function (Blueprint $table): void {
            $table->boolean('is_active')->default(true)->after('show_in_app');
            $table->timestamp('expires_at')->nullable()->after('publish_at');
        });
    }

    public function down(): void
    {
        Schema::table('announcements', function (Blueprint $table): void {
            $table->dropColumn(['is_active', 'expires_at']);
        });
    }
};

