<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table): void {
            $table->softDeletes();
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->boolean('is_active')->default(true);
        });

        Schema::table('orders', function (Blueprint $table): void {
            $table->string('tracking_number')->nullable();
            $table->text('admin_notes')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropColumn(['tracking_number', 'admin_notes']);
        });
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn('is_active');
        });
        Schema::table('products', function (Blueprint $table): void {
            $table->dropSoftDeletes();
        });
    }
};
