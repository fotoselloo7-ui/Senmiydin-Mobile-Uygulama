<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('app_notifications', function (Blueprint $table): void {
            // Set once a push for the row reached the delivery provider: makes DeliverPush idempotent across retries.
            $table->timestamp('pushed_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('app_notifications', fn (Blueprint $table) => $table->dropColumn('pushed_at'));
    }
};
