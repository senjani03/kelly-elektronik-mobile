<?php

use App\Models\Order;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('orders:cancel-expired', function (): void {
    $orders = Order::query()
        ->where('payment_method', 'bank_transfer')
        ->where('status', 'pending_payment')
        ->whereIn('payment_status', ['pending', 'rejected'])
        ->where('created_at', '<=', now()->subHours(24))
        ->with('items')
        ->get();

    $cancelled = 0;
    foreach ($orders as $order) {
        DB::transaction(function () use ($order, &$cancelled): void {
            $lockedOrder = Order::query()->whereKey($order->id)->lockForUpdate()->first();
            if ($lockedOrder === null
                || $lockedOrder->payment_method !== 'bank_transfer'
                || $lockedOrder->status !== 'pending_payment'
                || ! in_array($lockedOrder->payment_status, ['pending', 'rejected'], true)
                || $lockedOrder->created_at->gt(now()->subHours(24))) {
                return;
            }

            foreach ($lockedOrder->items as $item) {
                $item->product()->increment('stock', $item->quantity);
            }
            $lockedOrder->update([
                'status' => 'cancelled',
                'payment_status' => 'expired',
            ]);
            $cancelled++;
        });
    }

    $this->info("Cancelled {$cancelled} expired unpaid order(s).");
})->purpose('Cancel unpaid orders older than 24 hours');
