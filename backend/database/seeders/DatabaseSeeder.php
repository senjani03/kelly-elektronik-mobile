<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $categories = [];
        foreach (['Peralatan Dapur', 'Elektronik Rumah', 'Audio & Video'] as $name) {
            $categories[$name] = Category::firstOrCreate(
                ['slug' => Str::slug($name)],
                ['name' => $name],
            );
        }

        $products = [
            ['Peralatan Dapur', 'Rice Cooker Digital 1.8L', 'Miyako', 'Penanak nasi digital dengan kapasitas 1.8 liter.', 425000, 2500, 20],
            ['Peralatan Dapur', 'Blender 2 Liter', 'Philips', 'Blender serbaguna untuk kebutuhan dapur.', 585000, 1800, 15],
            ['Elektronik Rumah', 'Kipas Angin Berdiri 16 Inci', 'Miyako', 'Kipas angin dengan tiga pilihan kecepatan.', 375000, 4500, 25],
            ['Elektronik Rumah', 'Setrika Uap', 'Philips', 'Setrika uap dengan lapisan anti lengket.', 329000, 1200, 18],
            ['Audio & Video', 'Smart TV LED 32 Inci', 'Samsung', 'Televisi LED 32 inci untuk hiburan keluarga.', 2450000, 5200, 8],
            ['Audio & Video', 'Speaker Bluetooth Portable', 'JBL', 'Speaker portabel dengan koneksi Bluetooth.', 799000, 900, 12],
        ];

        foreach ($products as [$category, $name, $brand, $description, $price, $weight, $stock]) {
            Product::firstOrCreate(
                ['name' => $name],
                [
                    'category_id' => $categories[$category]->id,
                    'brand' => $brand,
                    'description' => $description,
                    'price' => $price,
                    'weight' => $weight,
                    'stock' => $stock,
                    'is_active' => true,
                ],
            );
        }

        User::firstOrCreate(
            ['email' => 'demo@kelly.test'],
            [
                'name' => 'Pengguna Demo',
                'phone' => '081234567890',
                'password' => 'KellyDemo123!',
            ],
        );

        $this->call(DemoOrderSeeder::class);
        $this->call(AdminUserSeeder::class);
    }
}
