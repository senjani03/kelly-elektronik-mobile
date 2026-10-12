<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->unsignedBigInteger('destination_id')->nullable();
            $table->string('destination_label')->nullable();
            $table->string('courier_code', 30)->nullable();
            $table->string('courier_service')->nullable();
            $table->string('shipping_etd', 100)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropColumn([
                'destination_id',
                'destination_label',
                'courier_code',
                'courier_service',
                'shipping_etd',
            ]);
        });
    }
};
