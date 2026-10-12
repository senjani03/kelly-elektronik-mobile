<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->unsignedSmallInteger('payment_unique_code')->default(0);
            $table->string('payment_proof_path')->nullable();
            $table->timestamp('payment_proof_uploaded_at')->nullable();
            $table->timestamp('payment_confirmed_at')->nullable();
            $table->foreignId('payment_confirmed_by')->nullable()
                ->constrained('users')->nullOnDelete();
            $table->text('payment_rejection_reason')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('payment_confirmed_by');
            $table->dropColumn([
                'payment_unique_code',
                'payment_proof_path',
                'payment_proof_uploaded_at',
                'payment_confirmed_at',
                'payment_rejection_reason',
            ]);
        });
    }
};
