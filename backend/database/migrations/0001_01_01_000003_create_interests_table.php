<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('interests', function (Blueprint $table): void {
            $table->id();
            $table->string('name', 80);
            $table->string('slug', 80)->unique();
            $table->string('icon', 48);
            $table->unsignedSmallInteger('sort_order');
            $table->boolean('is_active')->default(true);
        });
        Schema::create('user_interests', function (Blueprint $table): void {
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('interest_id')->constrained()->cascadeOnDelete();
            $table->primary(['user_id', 'interest_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_interests');
        Schema::dropIfExists('interests');
    }
};
