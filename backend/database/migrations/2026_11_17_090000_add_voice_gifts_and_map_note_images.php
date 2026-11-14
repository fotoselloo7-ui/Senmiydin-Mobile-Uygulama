<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Voice messages (audio_path / audio_duration_ms), free virtual gifts (a server-controlled catalog, prepared for a paid
 * model through price_minor / currency) and one optional photo per map note.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('gifts', function (Blueprint $table): void {
            $table->id();
            $table->string('slug', 32)->unique();
            $table->string('name_tr', 40);
            $table->string('name_en', 40);
            // Key of the artwork shipped with the app (assets/gifts/<asset>.svg); unknown keys fall back to a generic icon.
            $table->string('asset', 32);
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('sort_order')->default(0);
            // Gifts are free in this release. A price may be set later without a schema change.
            $table->unsignedInteger('price_minor')->default(0);
            $table->string('currency', 3)->nullable();
            $table->timestamps();
        });
        $now = now();
        DB::table('gifts')->insert(array_map(fn (array $gift, int $order) => $gift + [
            'is_active' => true, 'sort_order' => $order, 'price_minor' => 0, 'currency' => null, 'created_at' => $now, 'updated_at' => $now,
        ], [
            ['slug' => 'heart', 'name_tr' => 'Kalp', 'name_en' => 'Heart', 'asset' => 'heart'],
            ['slug' => 'rose', 'name_tr' => 'Gül', 'name_en' => 'Rose', 'asset' => 'rose'],
            ['slug' => 'coffee', 'name_tr' => 'Kahve', 'name_en' => 'Coffee', 'asset' => 'coffee'],
            ['slug' => 'flower', 'name_tr' => 'Çiçek', 'name_en' => 'Flower', 'asset' => 'flower'],
            ['slug' => 'star', 'name_tr' => 'Yıldız', 'name_en' => 'Star', 'asset' => 'star'],
            ['slug' => 'clover', 'name_tr' => 'Yonca', 'name_en' => 'Clover', 'asset' => 'clover'],
            ['slug' => 'cake', 'name_tr' => 'Pasta', 'name_en' => 'Cake', 'asset' => 'cake'],
            ['slug' => 'gift', 'name_tr' => 'Hediye kutusu', 'name_en' => 'Gift box', 'asset' => 'gift'],
        ], range(1, 8)));

        Schema::table('messages', function (Blueprint $table): void {
            $table->string('audio_path')->nullable();
            $table->unsignedInteger('audio_duration_ms')->nullable();
            $table->foreignId('gift_id')->nullable()->constrained('gifts')->restrictOnDelete();
        });
        Schema::table('map_notes', function (Blueprint $table): void {
            $table->string('image_path')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('map_notes', fn (Blueprint $table) => $table->dropColumn('image_path'));
        Schema::table('messages', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('gift_id');
            $table->dropColumn(['audio_path', 'audio_duration_ms']);
        });
        Schema::dropIfExists('gifts');
    }
};
