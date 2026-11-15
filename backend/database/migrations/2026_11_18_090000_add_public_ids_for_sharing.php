<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * Public identifiers for sharing a post or a Map Note outside the app (https://<domain>/p/<id>, /n/<id>). They are random and
 * unrelated to the row id, so a link can't be guessed or enumerated, and one row's link never reveals another's.
 */
return new class extends Migration
{
    public function up(): void
    {
        foreach (['posts', 'map_notes'] as $table) {
            Schema::table($table, function (Blueprint $t): void {
                $t->string('public_id', 16)->nullable()->unique();
            });
            DB::table($table)->whereNull('public_id')->orderBy('id')->chunkById(200, function ($rows) use ($table): void {
                foreach ($rows as $row) {
                    DB::table($table)->where('id', $row->id)->update(['public_id' => Str::lower(Str::random(12))]);
                }
            });
        }
    }

    public function down(): void
    {
        foreach (['posts', 'map_notes'] as $table) {
            Schema::table($table, function (Blueprint $t): void {
                $t->dropUnique(['public_id']);
                $t->dropColumn('public_id');
            });
        }
    }
};
