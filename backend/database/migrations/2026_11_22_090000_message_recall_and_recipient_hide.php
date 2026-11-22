<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Message deletion the way the stores' messaging guidelines expect it: the sender can take a message back for everyone
 * (recalled_at), the receiver can remove it from their own view (recipient_hidden_at). deleted_at stays "the sender hid it".
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table): void {
            $table->timestamp('recalled_at')->nullable()->after('deleted_at');
            $table->timestamp('recipient_hidden_at')->nullable()->after('recalled_at');
        });
    }

    public function down(): void
    {
        Schema::table('messages', function (Blueprint $table): void {
            $table->dropColumn(['recalled_at', 'recipient_hidden_at']);
        });
    }
};
