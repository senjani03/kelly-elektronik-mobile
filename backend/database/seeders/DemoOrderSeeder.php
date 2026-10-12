<?php

namespace Database\Seeders;

use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DemoOrderSeeder extends Seeder
{
    private const ORDER_CODE = 'KEL-DEMO-SAMPLE-001';

    public function run(): void
    {
        if (Order::query()->where('code', self::ORDER_CODE)->exists()) {
            return;
        }

        $demo = User::query()->where('email', 'demo@kelly.test')->first();
        $productNames = ['Rice Cooker Digital 1.8L', 'Blender 2 Liter'];
        $products = Product::query()->whereIn('name', $productNames)->get()->keyBy('name');

        if ($demo === null || $products->count() !== count($productNames)) {
            $this->command?->warn('Sample order dilewati karena akun demo atau produk seed belum tersedia.');

            return;
        }

        DB::transaction(function () use ($demo, $productNames): void {
            if (Order::query()->where('code', self::ORDER_CODE)->exists()) {
                return;
            }

            $lockedProducts = [];
            $subtotalCents = 0;
            foreach ($productNames as $name) {
                $product = Product::query()->where('name', $name)->lockForUpdate()->first();
                if ($product === null || ! $product->is_active || $product->stock < 1) {
                    $this->command?->warn('Sample order dilewati karena stok produk demo tidak mencukupi.');

                    return;
                }
                $lockedProducts[] = $product;
                $subtotalCents += (int) round((float) $product->price * 100);
            }

            $shippingCents = 25000 * 100;
            $order = $demo->orders()->create([
                'code' => self::ORDER_CODE,
                'recipient_name' => $demo->name,
                'phone' => $demo->phone ?: '081234567890',
                'address' => 'Jl. Contoh No. 10, Jakarta Barat',
                'destination_label' => 'Grogol Petamburan, Jakarta Barat',
                'payment_method' => 'cod',
                'payment_status' => 'paid',
                'payment_confirmed_at' => now(),
                'status' => 'delivered',
                'subtotal' => $subtotalCents / 100,
                'shipping_cost' => $shippingCents / 100,
                'total' => ($subtotalCents + $shippingCents) / 100,
            ]);

            foreach ($lockedProducts as $product) {
                $order->items()->create([
                    'product_id' => $product->id,
                    'product_name' => $product->name,
                    'quantity' => 1,
                    'price' => $product->price,
                ]);
                $product->decrement('stock');
            }
        });
    }
}
