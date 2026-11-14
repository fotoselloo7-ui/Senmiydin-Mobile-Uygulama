<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            // tr | en. Null means "follow Accept-Language, then Turkish".
            $table->string('preferred_locale', 2)->nullable()->after('message_privacy');
        });
        Schema::table('announcements', function (Blueprint $table): void {
            $table->string('title_en', 120)->nullable()->after('body');
            $table->text('body_en')->nullable()->after('title_en');
            // all | city | location. Location targets keep only the approximate point and a radius, never a user position.
            $table->string('target_type', 12)->default('all')->after('city_id');
            $table->decimal('target_latitude', 8, 5)->nullable();
            $table->decimal('target_longitude', 8, 5)->nullable();
            $table->unsignedInteger('target_radius_m')->nullable();
            $table->unsignedInteger('targeted_count')->default(0);
            $table->unsignedInteger('delivered_count')->default(0);
        });
        Schema::table('messages', function (Blueprint $table): void {
            // type = location: the point is always snapped to the approximate grid before it is stored.
            $table->decimal('approx_latitude', 8, 5)->nullable();
            $table->decimal('approx_longitude', 8, 5)->nullable();
            $table->string('place_label', 80)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('messages', fn (Blueprint $table) => $table->dropColumn(['approx_latitude', 'approx_longitude', 'place_label']));
        Schema::table('announcements', fn (Blueprint $table) => $table->dropColumn([
            'title_en', 'body_en', 'target_type', 'target_latitude', 'target_longitude', 'target_radius_m', 'targeted_count', 'delivered_count',
        ]));
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn('preferred_locale'));
    }
};
