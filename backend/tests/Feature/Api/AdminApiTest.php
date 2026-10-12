<?php

namespace Tests\Feature\Api;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AdminApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_routes_require_authentication_and_admin_role(): void
    {
        $this->getJson('/api/admin/dashboard')->assertUnauthorized();
        $this->actingAs(User::factory()->create())
            ->getJson('/api/admin/dashboard')->assertForbidden();
        $this->actingAs(User::factory()->create(['is_active' => false]))
            ->getJson('/api/cart')->assertForbidden();
        $this->actingAs(User::factory()->create(['role' => 'admin']))
            ->getJson('/api/admin/dashboard')->assertOk();
    }

    public function test_admin_product_validation_and_category_delete_protection(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $this->actingAs($admin)->postJson('/api/admin/products', [
            'category_id' => 999,
            'name' => 'Produk',
            'price' => -1,
            'stock' => -1,
        ])->assertUnprocessable()->assertJsonValidationErrors(['category_id', 'price', 'stock']);

        $category = Category::create(['name' => 'Elektronik', 'slug' => 'elektronik']);
        Product::create(['category_id' => $category->id, 'name' => 'Radio', 'price' => 10, 'stock' => 1]);
        $this->getJson('/api/admin/products')
            ->assertOk()
            ->assertJsonStructure(['data', 'meta' => ['current_page', 'last_page', 'total']]);
        $this->getJson('/api/admin/categories/'.$category->id)
            ->assertOk()->assertJsonPath('data.name', 'Elektronik');
        $this->deleteJson('/api/admin/categories/'.$category->id)->assertUnprocessable()
            ->assertJsonValidationErrors('category');
    }

    public function test_product_with_order_history_is_deactivated_and_soft_deleted(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $customer = User::factory()->create();
        $category = Category::create(['name' => 'Aksesori', 'slug' => 'aksesori']);
        $product = Product::create([
            'category_id' => $category->id, 'name' => 'Kabel', 'price' => 10000, 'stock' => 5,
        ]);
        $order = Order::create([
            'user_id' => $customer->id,
            'code' => 'TEST-SOFT-DELETE',
            'recipient_name' => 'Dewi',
            'phone' => '081234567890',
            'address' => 'Jalan Merdeka nomor 10',
            'payment_method' => 'cod',
            'subtotal' => 10000,
            'shipping_cost' => 0,
            'total' => 10000,
        ]);
        $order->items()->create([
            'product_id' => $product->id, 'product_name' => 'Kabel', 'quantity' => 1, 'price' => 10000,
        ]);

        $this->actingAs($admin)->deleteJson('/api/admin/products/'.$product->id)->assertOk();
        $this->assertSoftDeleted('products', ['id' => $product->id]);
        $this->assertFalse(Product::withTrashed()->findOrFail($product->id)->is_active);
        $this->getJson('/api/products/'.$product->id)->assertNotFound();
    }

    public function test_admin_product_images_are_uploaded_served_replaced_and_deleted_safely(): void
    {
        Storage::fake('public');
        $admin = User::factory()->create(['role' => 'admin']);
        $category = Category::create(['name' => 'Gawai', 'slug' => 'gawai']);
        $productData = [
            'category_id' => $category->id,
            'name' => 'Ponsel',
            'price' => 1000000,
            'stock' => 4,
        ];

        $created = $this->actingAs($admin)->post('/api/admin/products', [
            ...$productData,
            'image' => $this->fakePng('upload.png'),
        ], ['Accept' => 'application/json']);
        $created->assertCreated();
        $product = Product::findOrFail($created->json('data.id'));
        $firstUrl = $product->image_url;
        $this->assertStringContainsString('/api/product-images/', $firstUrl);
        $firstFilename = basename(parse_url($firstUrl, PHP_URL_PATH));
        Storage::disk('public')->assertExists('products/'.$firstFilename);
        $this->get(parse_url($firstUrl, PHP_URL_PATH))->assertOk();

        $updated = $this->post('/api/admin/products/'.$product->id, [
            ...$productData,
            '_method' => 'PUT',
            'image' => $this->fakePng('replacement.png'),
        ], ['Accept' => 'application/json']);
        $updated->assertOk();
        $secondUrl = $product->fresh()->image_url;
        $secondFilename = basename(parse_url($secondUrl, PHP_URL_PATH));
        $this->assertNotSame($firstFilename, $secondFilename);
        Storage::disk('public')->assertMissing('products/'.$firstFilename);
        Storage::disk('public')->assertExists('products/'.$secondFilename);
        $this->get(parse_url($secondUrl, PHP_URL_PATH))->assertOk();

        $this->deleteJson('/api/admin/products/'.$product->id)->assertOk();
        Storage::disk('public')->assertMissing('products/'.$secondFilename);
    }

    public function test_admin_product_image_rejects_unsupported_format_and_files_over_five_megabytes(): void
    {
        Storage::fake('public');
        $admin = User::factory()->create(['role' => 'admin']);
        $category = Category::create(['name' => 'Komponen', 'slug' => 'komponen']);
        $productData = [
            'category_id' => $category->id,
            'name' => 'Kartu Grafis',
            'price' => 1000000,
            'stock' => 2,
        ];

        $this->actingAs($admin)->post('/api/admin/products', [
            ...$productData,
            'image' => UploadedFile::fake()->create('malware.svg', 100, 'image/svg+xml'),
        ], ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('image');

        $this->post('/api/admin/products', [
            ...$productData,
            'image' => $this->fakePng('too-large.png', 5 * 1024 * 1024 + 1),
        ], ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('image');
        $this->assertDatabaseCount('products', 0);
        $this->assertSame([], Storage::disk('public')->allFiles('products'));
    }

    private function fakePng(string $name, int $size = 0): UploadedFile
    {
        $png = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jXioAAAAASUVORK5CYII=', true);

        return UploadedFile::fake()->createWithContent($name, $png.str_repeat('0', max(0, $size - strlen($png))));
    }

    public function test_admin_cannot_delete_self_and_passwords_are_hashed(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $this->actingAs($admin)->deleteJson('/api/admin/users/'.$admin->id)
            ->assertUnprocessable()->assertJsonValidationErrors('user');

        $response = $this->postJson('/api/admin/users', [
            'name' => 'Nadia Admin',
            'email' => 'nadia.admin@example.test',
            'password' => 'A-strong-password-123',
            'role' => 'admin',
            'is_active' => true,
        ]);
        $response->assertCreated()->assertJsonMissingPath('data.password');
        $created = User::where('email', 'nadia.admin@example.test')->firstOrFail();
        $this->assertTrue(Hash::check('A-strong-password-123', $created->password));
        $this->assertNotSame('A-strong-password-123', $created->password);
    }

    public function test_manual_order_reserves_stock_and_cancellation_restores_it_exactly_once(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $customer = User::factory()->create();
        $category = Category::create(['name' => 'Komputer', 'slug' => 'komputer']);
        $product = Product::create([
            'category_id' => $category->id, 'name' => 'Mouse', 'price' => 50000, 'stock' => 10,
        ]);

        $response = $this->actingAs($admin)->postJson('/api/admin/orders', [
            'user_id' => $customer->id,
            'recipient_name' => 'Nadia',
            'phone' => '081234567890',
            'address' => 'Jalan Merdeka nomor 10',
            'payment_method' => 'cod',
            'items' => [['product_id' => $product->id, 'quantity' => 3]],
        ]);
        $response->assertCreated()->assertJsonPath('data.subtotal', '150000.00');
        $orderId = $response->json('data.id');
        $this->assertSame(7, $product->fresh()->stock);

        $this->patchJson('/api/admin/orders/'.$orderId, ['status' => 'cancelled'])->assertOk();
        $this->assertSame(10, $product->fresh()->stock);
        $this->patchJson('/api/admin/orders/'.$orderId, ['status' => 'cancelled'])->assertOk();
        $this->assertSame(10, $product->fresh()->stock);
    }

    public function test_order_deletion_restores_stock_and_dashboard_reports_sales_and_counts(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $customer = User::factory()->create();
        $category = Category::create(['name' => 'Audio', 'slug' => 'audio']);
        $product = Product::create([
            'category_id' => $category->id, 'name' => 'Headphone', 'price' => 100000, 'stock' => 8,
        ]);
        $order = Order::create([
            'user_id' => $customer->id,
            'code' => 'TEST-001',
            'recipient_name' => 'Nadia',
            'phone' => '081234567890',
            'address' => 'Jalan Merdeka nomor 10',
            'payment_method' => 'bank_transfer',
            'payment_status' => 'paid',
            'status' => 'processing',
            'subtotal' => 100000,
            'shipping_cost' => 0,
            'total' => 100000,
        ]);
        $order->items()->create([
            'product_id' => $product->id, 'product_name' => 'Headphone', 'quantity' => 2, 'price' => 100000,
        ]);
        $product->update(['stock' => 6]);

        $this->actingAs($admin)->getJson('/api/admin/dashboard')
            ->assertOk()->assertJsonPath('data.stats.sales_total', 100000)
            ->assertJsonPath('data.stats.orders_count', 1)
            ->assertJsonPath('data.stats.users_count', 1)
            ->assertJsonPath('data.sales.6.label', now()->toDateString())
            ->assertJsonPath('data.sales.6.total', 100000);

        $this->deleteJson('/api/admin/orders/'.$order->id)->assertOk();
        $this->assertSame(8, $product->fresh()->stock);
        $this->assertDatabaseMissing('orders', ['id' => $order->id]);
    }
}
