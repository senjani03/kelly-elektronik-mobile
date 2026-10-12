<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->string('midtrans_order_id')->nullable()->unique();
            $table->string('midtrans_transaction_id')->nullable();
            $table->string('midtrans_snap_token')->nullable();
            $table->text('midtrans_redirect_url')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropUnique(['midtrans_order_id']);
            $table->dropColumn([
                'midtrans_order_id',
                'midtrans_transaction_id',
                'midtrans_snap_token',
                'midtrans_redirect_url',
            ]);
        });
    }
};
