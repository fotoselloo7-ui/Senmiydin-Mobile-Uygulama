<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('reports', fn (Blueprint $table) => $table->index(['status', 'id'], 'reports_status_id'));
        Schema::table('users', fn (Blueprint $table) => $table->index(['account_status', 'city_id', 'id'], 'users_active_city_id'));
    }
    public function down(): void
    {
        Schema::table('reports', fn (Blueprint $table) => $table->dropIndex('reports_status_id'));
        Schema::table('users', fn (Blueprint $table) => $table->dropIndex('users_active_city_id'));
    }
};
