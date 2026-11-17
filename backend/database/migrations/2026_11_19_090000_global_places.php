<?php

use App\Places\Areas;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Global places. Nothing is dropped or rewritten:
 *  - `cities` stays the feed area (every existing city_id keeps working) and gains the fields that let new areas come
 *    from a place provider anywhere in the world;
 *  - `places` holds the finer places people pick (neighbourhood, suburb, village, town ...), each inside one area;
 *  - users / posts / journeys get nullable place columns, so old rows simply have no place.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('cities', function (Blueprint $table): void {
            // Locale independent identity of an area: country | admin1 | (empty) | name (slugs).
            $table->string('area_key', 191)->nullable()->unique();
            $table->string('provider', 20)->nullable();
            $table->string('provider_place_id', 40)->nullable();
            $table->char('country_code', 2)->nullable()->index();
            $table->string('country_name', 100)->nullable();
            $table->string('admin1', 120)->nullable();
            $table->string('admin2', 120)->nullable();
            $table->decimal('latitude', 8, 5)->nullable();
            $table->decimal('longitude', 8, 5)->nullable();
            // Display names per app language: {"tr": {"name": ..., "admin1": ..., "country": ...}, "en": {...}}.
            $table->json('labels')->nullable();
        });

        Schema::create('places', function (Blueprint $table): void {
            $table->id();
            $table->string('provider', 20);
            $table->string('provider_place_id', 40);
            $table->foreignId('city_id')->constrained()->restrictOnDelete();
            $table->string('type', 30);
            $table->string('name', 120);
            $table->char('country_code', 2);
            $table->string('country_name', 100);
            $table->string('admin1', 120)->nullable();
            $table->string('admin2', 120)->nullable();
            $table->string('locality', 120)->nullable();
            $table->string('suburb', 120)->nullable();
            $table->string('neighbourhood', 120)->nullable();
            $table->string('display_name', 255);
            // The public centre of the place itself (never a person's position), rounded to ~100 m.
            $table->decimal('latitude', 8, 5);
            $table->decimal('longitude', 8, 5);
            $table->json('labels')->nullable();
            $table->timestamps();
            $table->unique(['provider', 'provider_place_id']);
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->foreignId('place_id')->nullable()->constrained()->nullOnDelete();
            // False for accounts created with Google / Apple that never chose an app password.
            $table->boolean('has_password')->default(true);
        });
        Schema::table('posts', function (Blueprint $table): void {
            $table->foreignId('place_id')->nullable()->constrained()->nullOnDelete();
        });
        Schema::table('post_travel_details', function (Blueprint $table): void {
            $table->foreignId('origin_place_id')->nullable()->constrained('places')->nullOnDelete();
            $table->foreignId('destination_place_id')->nullable()->constrained('places')->nullOnDelete();
        });

        Areas::describeLegacy();
    }

    public function down(): void
    {
        Schema::table('post_travel_details', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('origin_place_id');
            $table->dropConstrainedForeignId('destination_place_id');
        });
        Schema::table('posts', fn (Blueprint $table) => $table->dropConstrainedForeignId('place_id'));
        Schema::table('users', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('place_id');
            $table->dropColumn('has_password');
        });
        Schema::dropIfExists('places');
        Schema::table('cities', function (Blueprint $table): void {
            $table->dropUnique(['area_key']);
            $table->dropIndex(['country_code']);
            $table->dropColumn(['area_key', 'provider', 'provider_place_id', 'country_code', 'country_name', 'admin1',
                'admin2', 'latitude', 'longitude', 'labels']);
        });
    }
};
