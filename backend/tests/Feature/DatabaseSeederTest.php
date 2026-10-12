<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Database\Seeders\AdminUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class DatabaseSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_demo_order_is_created_once_and_seed_preserves_stock_and_demo_credentials(): void
    {
        $demo = User::factory()->create([
            'name' => 'Existing Demo',
            'email' => 'demo@kelly.test',
            'password' => 'ExistingDemoPassword123!',
        ]);
        $originalPassword = $demo->fresh()->password;

        $this->seed();

        $order = Order::query()->where('code', 'KEL-DEMO-SAMPLE-001')->firstOrFail();
        $this->assertSame($demo->id, $order->user_id);
        $this->assertSame(2, $order->items()->count());
        $this->assertSame('Existing Demo', $demo->fresh()->name);
        $this->assertSame($originalPassword, $demo->fresh()->password);
        $this->assertTrue(Hash::check('ExistingDemoPassword123!', $demo->fresh()->password));
        $this->assertSame(19, Product::query()->where('name', 'Rice Cooker Digital 1.8L')->value('stock'));
        $this->assertSame(14, Product::query()->where('name', 'Blender 2 Liter')->value('stock'));

        $this->seed();

        $this->assertSame(1, Order::query()->where('code', 'KEL-DEMO-SAMPLE-001')->count());
        $this->assertSame(2, $order->fresh()->items()->count());
        $this->assertSame(19, Product::query()->where('name', 'Rice Cooker Digital 1.8L')->value('stock'));
        $this->assertSame(14, Product::query()->where('name', 'Blender 2 Liter')->value('stock'));
        $this->assertSame($originalPassword, $demo->fresh()->password);
    }

    public function test_admin_seeder_does_not_reset_an_existing_account(): void
    {
        $admin = User::factory()->create([
            'name' => 'Established Admin',
            'email' => 'configured-admin@example.test',
            'role' => 'admin',
            'password' => 'ExistingAdminPassword123!',
        ]);
        $originalPassword = $admin->fresh()->password;
        $environment = [];
        foreach (['ADMIN_EMAIL', 'ADMIN_PASSWORD', 'ADMIN_NAME'] as $key) {
            $environment[$key] = getenv($key);
        }

        try {
            putenv('ADMIN_EMAIL=configured-admin@example.test');
            putenv('ADMIN_PASSWORD=NewSeedPassword123!');
            putenv('ADMIN_NAME=Seeded Name');
            $_ENV['ADMIN_EMAIL'] = 'configured-admin@example.test';
            $_ENV['ADMIN_PASSWORD'] = 'NewSeedPassword123!';
            $_ENV['ADMIN_NAME'] = 'Seeded Name';

            $this->seed(AdminUserSeeder::class);
        } finally {
            foreach ($environment as $key => $value) {
                if ($value === false) {
                    putenv($key);
                    unset($_ENV[$key]);
                } else {
                    putenv($key.'='.$value);
                    $_ENV[$key] = $value;
                }
            }
        }

        $this->assertSame('Established Admin', $admin->fresh()->name);
        $this->assertSame($originalPassword, $admin->fresh()->password);
        $this->assertTrue(Hash::check('ExistingAdminPassword123!', $admin->fresh()->password));
    }
}
