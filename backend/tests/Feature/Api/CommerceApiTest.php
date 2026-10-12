<?php

namespace Tests\Feature\Api;

use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class CommerceApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_can_browse_products_and_categories(): void
    {
        $category = Category::create(['name' => 'Dapur', 'slug' => 'dapur']);
        Product::create([
            'category_id' => $category->id,
            'name' => 'Blender Rumah',
            'brand' => 'Kelly',
            'description' => 'Blender untuk dapur.',
            'price' => 100000,
            'weight' => 1200,
            'stock' => 5,
            'is_active' => true,
        ]);

        $this->getJson('/api/categories')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Dapur');

        $this->getJson('/api/products?search=BLENDER&category_id='.$category->id)
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Blender Rumah')
            ->assertJsonPath('data.0.category.name', 'Dapur')
            ->assertJsonPath('data.0.stock', 5);
    }

    public function test_authenticated_customer_can_add_cart_item_and_complete_checkout(): void
    {
        $this->fakeRajaOngkir();
        $category = Category::create(['name' => 'Dapur', 'slug' => 'dapur']);
        $product = Product::create([
            'category_id' => $category->id,
            'name' => 'Blender Rumah',
            'price' => 100000,
            'weight' => 1200,
            'stock' => 5,
            'is_active' => true,
        ]);
        $user = User::factory()->create();
        $headers = ['Authorization' => 'Bearer '.$user->createToken('test')->plainTextToken];

        $this->postJson('/api/cart', [
            'product_id' => $product->id,
            'quantity' => 2,
        ], $headers)->assertCreated()
            ->assertJsonPath('data.quantity', 2)
            ->assertJsonPath('data.product.id', $product->id);

        $this->postJson('/api/orders', [
            'recipient_name' => 'Dewi',
            'phone' => '081234567890',
            'address' => 'Jalan Melati nomor 10, Jakarta',
            'destination_id' => 200,
            'destination_label' => 'Tanjung Duren Selatan, Grogol Petamburan, Jakarta Barat',
            'courier' => 'jne',
            'courier_service' => 'REG',
            'payment_method' => 'bank_transfer',
        ], $headers)->assertCreated()
            ->assertJsonPath('data.status', 'pending_payment')
            ->assertJsonPath('data.payment_status', 'pending')
            ->assertJsonPath('data.subtotal', '200000.00')
            ->assertJsonPath('data.shipping_cost', '12000.00')
            ->assertJsonPath('data.courier_code', 'jne')
            ->assertJsonPath('data.courier_service', 'REG')
            ->assertJsonPath('data.items.0.product_name', 'Blender Rumah')
            ->assertJsonPath('data.items.0.quantity', 2);

        $uniqueCode = $this->json('GET', '/api/orders', [], $headers)
            ->assertOk()->json('data.0.payment_unique_code');
        $orderResponse = $this->json(
            'GET',
            '/api/orders',
            [],
            $headers,
        )->assertOk();
        $totalCents = (int) round((float) $orderResponse->json('data.0.total') * 100);
        $this->assertGreaterThanOrEqual(1, $uniqueCode);
        $this->assertLessThanOrEqual(999, $uniqueCode);
        $this->assertSame(21200000 + $uniqueCode * 100, $totalCents);

        $this->assertDatabaseHas('products', ['id' => $product->id, 'stock' => 3]);
        $this->assertDatabaseCount('cart_items', 0);
        $this->assertDatabaseCount('orders', 1);
        $this->getJson('/api/orders', $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_customer_can_search_destinations_and_get_shipping_quotes(): void
    {
        $this->fakeRajaOngkir();
        $product = Product::create([
            'category_id' => Category::create(['name' => 'Dapur', 'slug' => 'dapur'])->id,
            'name' => 'Blender Rumah',
            'price' => 100000,
            'weight' => 1200,
            'stock' => 5,
            'is_active' => true,
        ]);
        $user = User::factory()->create();
        $headers = ['Authorization' => 'Bearer '.$user->createToken('test')->plainTextToken];
        $this->postJson('/api/cart', [
            'product_id' => $product->id,
            'quantity' => 2,
        ], $headers)->assertCreated();

        $this->getJson('/api/shipping/destinations?search=Tanjung%20Duren', $headers)
            ->assertOk()
            ->assertJsonPath('data.0.id', 200)
            ->assertJsonPath('data.0.subdistrict_name', 'Tanjung Duren Selatan');

        $this->postJson('/api/shipping/quotes', [
            'destination_id' => 200,
            'courier' => 'jne',
        ], $headers)->assertOk()
            ->assertJsonPath('data.weight', 2400)
            ->assertJsonPath('data.services.0.service', 'REG')
            ->assertJsonPath('data.services.0.cost', 12000);
    }

    public function test_checkout_keeps_cart_and_stock_unchanged_when_stock_is_insufficient(): void
    {
        $category = Category::create(['name' => 'Dapur', 'slug' => 'dapur']);
        $product = Product::create([
            'category_id' => $category->id,
            'name' => 'Blender Rumah',
            'price' => 100000,
            'stock' => 3,
            'is_active' => true,
        ]);
        $user = User::factory()->create();
        $headers = ['Authorization' => 'Bearer '.$user->createToken('test')->plainTextToken];

        $this->postJson('/api/cart', ['product_id' => $product->id, 'quantity' => 2], $headers)
            ->assertCreated();

        $product->update(['stock' => 1]);

        $this->postJson('/api/orders', [
            'recipient_name' => 'Dewi',
            'phone' => '081234567890',
            'address' => 'Jalan Melati nomor 10, Jakarta',
            'destination_id' => 200,
            'destination_label' => 'Tanjung Duren Selatan, Jakarta Barat',
            'courier' => 'jne',
            'courier_service' => 'REG',
            'payment_method' => 'cod',
        ], $headers)->assertUnprocessable()
            ->assertJsonValidationErrors('cart');

        $this->assertDatabaseHas('products', ['id' => $product->id, 'stock' => 1]);
        $this->assertDatabaseCount('cart_items', 1);
        $this->assertDatabaseCount('orders', 0);
    }

    public function test_cart_and_order_endpoints_require_authentication(): void
    {
        $this->getJson('/api/cart')->assertUnauthorized();
        $this->postJson('/api/orders', [])->assertUnauthorized();
    }

    private function fakeRajaOngkir(): void
    {
        config([
            'services.rajaongkir.api_key' => 'test-api-key',
            'services.rajaongkir.couriers' => ['jne'],
        ]);
        Cache::forget('rajaongkir.origin.tanjung-duren-selatan');
        Http::fake([
            '*/destination/domestic-destination*' => Http::response([
                'meta' => ['message' => 'Success', 'code' => 200, 'status' => 'success'],
                'data' => [[
                    'id' => 200,
                    'label' => 'Tanjung Duren Selatan, Grogol Petamburan, Jakarta Barat',
                    'province_name' => 'DKI Jakarta',
                    'city_name' => 'Jakarta Barat',
                    'district_name' => 'Grogol Petamburan',
                    'subdistrict_name' => 'Tanjung Duren Selatan',
                    'zip_code' => '11470',
                ]],
            ]),
            '*/calculate/domestic-cost' => Http::response([
                'meta' => ['message' => 'Success', 'code' => 200, 'status' => 'success'],
                'data' => [[
                    'name' => 'JNE',
                    'code' => 'jne',
                    'service' => 'REG',
                    'description' => 'Reguler',
                    'cost' => 12000,
                    'etd' => '2-3 hari',
                ]],
            ]),
        ]);
    }
}
