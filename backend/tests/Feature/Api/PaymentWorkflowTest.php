<?php

namespace Tests\Feature\Api;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class PaymentWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_can_upload_only_a_valid_proof_for_their_unpaid_order(): void
    {
        Storage::fake('local');
        $customer = User::factory()->create();
        $otherCustomer = User::factory()->create();
        $order = $this->makeOrder($customer);
        $otherOrder = $this->makeOrder($otherCustomer);
        $headers = $this->headersFor($customer);

        $this->post('/api/orders/'.$order->id.'/payment-proof', [
            'proof' => $this->pngUpload(),
        ], $headers)->assertOk()
            ->assertJsonPath('data.payment_status', 'proof_submitted');

        $order->refresh();
        $this->assertSame('proof_submitted', $order->payment_status);
        $this->assertNotNull($order->payment_proof_uploaded_at);
        Storage::disk('local')->assertExists($order->payment_proof_path);

        $this->get('/api/orders/'.$order->id.'/payment-proof', $headers)
            ->assertOk();
        $this->app['auth']->forgetGuards();
        $this->post('/api/orders/'.$otherOrder->id.'/payment-proof', [
            'proof' => $this->pngUpload(),
        ], $headers)->assertNotFound();
        $this->app['auth']->forgetGuards();
        $this->get('/api/orders/'.$order->id.'/payment-proof', $this->headersFor($otherCustomer))
            ->assertNotFound();
    }

    public function test_invalid_proof_types_and_already_paid_orders_are_rejected(): void
    {
        Storage::fake('local');
        $customer = User::factory()->create();
        $headers = $this->headersFor($customer);
        $order = $this->makeOrder($customer);

        $this->post('/api/orders/'.$order->id.'/payment-proof', [
            'proof' => UploadedFile::fake()->create('receipt.pdf', 50, 'application/pdf'),
        ], $headers + ['Accept' => 'application/json'])->assertUnprocessable()
            ->assertJsonValidationErrors('proof');

        $order->update(['payment_status' => 'paid']);
        $this->post('/api/orders/'.$order->id.'/payment-proof', [
            'proof' => $this->pngUpload(),
        ], $headers + ['Accept' => 'application/json'])->assertUnprocessable()
            ->assertJsonValidationErrors('proof');
    }

    public function test_admin_can_list_reject_and_confirm_transfer_proofs(): void
    {
        Storage::fake('local');
        $customer = User::factory()->create();
        $admin = User::factory()->create(['role' => 'admin']);
        $order = $this->makeOrder($customer, 'proof_submitted');
        $order->update([
            'payment_proof_path' => 'payment-proofs/receipt.png',
            'payment_proof_uploaded_at' => now(),
        ]);
        Storage::disk('local')->put($order->payment_proof_path, base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
        ));

        $this->getJson('/api/admin/orders/pending-confirmation', $this->headersFor($customer))
            ->assertForbidden();
        $this->app['auth']->forgetGuards();
        $adminHeaders = $this->headersFor($admin);
        $this->getJson('/api/admin/orders/pending-confirmation', $adminHeaders)
            ->assertOk()
            ->assertJsonPath('data.0.id', $order->id)
            ->assertJsonPath('data.0.user.email', $customer->email);
        $this->get('/api/orders/'.$order->id.'/payment-proof', $adminHeaders)
            ->assertOk();

        $this->postJson('/api/admin/orders/'.$order->id.'/reject-payment', [
            'reason' => 'Bukti transfer tidak terbaca.',
        ], $adminHeaders)->assertOk()
            ->assertJsonPath('data.payment_status', 'rejected');
        $this->assertDatabaseHas('orders', [
            'id' => $order->id,
            'payment_rejection_reason' => 'Bukti transfer tidak terbaca.',
        ]);

        $this->app['auth']->forgetGuards();
        $this->post('/api/orders/'.$order->id.'/payment-proof', [
            'proof' => $this->pngUpload(),
        ], $this->headersFor($customer))->assertOk();
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/admin/orders/'.$order->id.'/confirm-payment', [], $adminHeaders)
            ->assertOk()
            ->assertJsonPath('data.payment_status', 'paid')
            ->assertJsonPath('data.status', 'processing');

        $order->refresh();
        $this->assertNotNull($order->payment_confirmed_at);
        $this->assertSame($admin->id, $order->payment_confirmed_by);
        $this->assertNull($order->payment_rejection_reason);
        $this->getJson('/api/admin/orders/pending-confirmation', $adminHeaders)
            ->assertOk()
            ->assertJsonCount(0, 'data');
        $this->postJson('/api/admin/orders/'.$order->id.'/confirm-payment', [], $adminHeaders)
            ->assertUnprocessable();
    }

    public function test_payment_admin_endpoints_require_admin_role(): void
    {
        $customer = User::factory()->create();
        $order = $this->makeOrder($customer, 'proof_submitted');

        $this->getJson('/api/admin/orders/pending-confirmation')
            ->assertUnauthorized();
        $this->postJson('/api/admin/orders/'.$order->id.'/confirm-payment', [])
            ->assertUnauthorized();
        $this->postJson('/api/admin/orders/'.$order->id.'/confirm-payment', [], $this->headersFor($customer))
            ->assertForbidden();
    }

    public function test_payment_details_are_read_from_server_configuration(): void
    {
        config([
            'services.shop_bank.name' => 'BCA',
            'services.shop_bank.account_name' => 'Kelly Elektronik',
            'services.shop_bank.account_number' => '1234567890',
        ]);
        $customer = User::factory()->create();

        $this->getJson('/api/payment-details', $this->headersFor($customer))
            ->assertOk()
            ->assertJsonPath('data.name', 'BCA')
            ->assertJsonPath('data.account_name', 'Kelly Elektronik')
            ->assertJsonPath('data.account_number', '1234567890');
    }

    public function test_customer_can_create_a_midtrans_sandbox_snap_transaction(): void
    {
        config([
            'services.midtrans.server_key' => 'SB-Mid-server-test-key',
            'services.midtrans.snap_url' => 'https://app.sandbox.midtrans.com/snap/v1/transactions',
            'services.midtrans.finish_url' => 'http://localhost:3000/#/payment-return',
        ]);
        Http::fake([
            'https://app.sandbox.midtrans.com/snap/v1/transactions' => Http::response([
                'token' => 'snap-test-token',
                'redirect_url' => 'https://app.sandbox.midtrans.com/snap/v2/vtweb/snap-test-token',
            ], 201),
        ]);
        $customer = User::factory()->create();
        $order = $this->makeMidtransOrder($customer);

        $this->postJson(
            '/api/orders/'.$order->id.'/midtrans-payment',
            [],
            $this->headersFor($customer),
        )->assertOk()
            ->assertJsonPath('data.payment_status', 'pending')
            ->assertJsonPath('data.redirect_url', 'https://app.sandbox.midtrans.com/snap/v2/vtweb/snap-test-token');

        $this->assertDatabaseHas('orders', [
            'id' => $order->id,
            'payment_method' => 'midtrans',
            'midtrans_snap_token' => 'snap-test-token',
        ]);
        Http::assertSent(fn (HttpRequest $request): bool => $request->url()
            === 'https://app.sandbox.midtrans.com/snap/v1/transactions'
            && $request['transaction_details']['gross_amount'] === 110000
            && $request['callbacks']['finish'] === 'http://localhost:3000/#/payment-return'
            && $request['item_details'][0]['price'] === 100000);
    }

    public function test_customer_can_retry_midtrans_payment_when_previous_transaction_is_not_found(): void
    {
        config([
            'services.midtrans.server_key' => 'SB-Mid-server-test-key',
            'services.midtrans.api_url' => 'https://api.sandbox.midtrans.com/v2',
            'services.midtrans.snap_url' => 'https://app.sandbox.midtrans.com/snap/v1/transactions',
        ]);
        Http::fake([
            'https://api.sandbox.midtrans.com/v2/*/status' => Http::response([
                'status_code' => '404',
                'status_message' => "Transaction doesn't exist.",
            ], 200),
            'https://app.sandbox.midtrans.com/snap/v1/transactions' => Http::response([
                'token' => 'snap-retry-token',
                'redirect_url' => 'https://app.sandbox.midtrans.com/snap/v2/vtweb/snap-retry-token',
            ], 201),
        ]);
        $customer = User::factory()->create();
        $order = $this->makeMidtransOrder($customer);
        $oldMidtransOrderId = 'KEL-'.$order->id.'-oldattempt';
        $order->update([
            'midtrans_order_id' => $oldMidtransOrderId,
            'midtrans_redirect_url' => 'https://app.sandbox.midtrans.com/snap/v2/vtweb/old-token',
            'midtrans_snap_token' => 'old-token',
        ]);

        $this->postJson(
            '/api/orders/'.$order->id.'/midtrans-payment',
            [],
            $this->headersFor($customer),
        )->assertOk()
            ->assertJsonPath('data.payment_status', 'pending')
            ->assertJsonPath(
                'data.redirect_url',
                'https://app.sandbox.midtrans.com/snap/v2/vtweb/snap-retry-token',
            );

        $order->refresh();
        $this->assertNotSame($oldMidtransOrderId, $order->midtrans_order_id);
        $this->assertSame('snap-retry-token', $order->midtrans_snap_token);
        $this->assertSame('pending', $order->payment_status);
        Http::assertSent(fn (HttpRequest $request): bool => $request->method() === 'GET'
            && $request->url() === 'https://api.sandbox.midtrans.com/v2/'
                .$oldMidtransOrderId.'/status');
        Http::assertSent(fn (HttpRequest $request): bool => $request->method() === 'POST'
            && $request->url() === 'https://app.sandbox.midtrans.com/snap/v1/transactions'
            && $request['transaction_details']['gross_amount'] === 110000
            && $request['transaction_details']['order_id'] === $order->midtrans_order_id);
    }

    public function test_midtrans_status_still_rejects_a_transaction_with_the_wrong_amount(): void
    {
        config([
            'services.midtrans.server_key' => 'SB-Mid-server-test-key',
            'services.midtrans.api_url' => 'https://api.sandbox.midtrans.com/v2',
        ]);
        Http::fake([
            'https://api.sandbox.midtrans.com/v2/*/status' => Http::response([
                'status_code' => '200',
                'order_id' => 'midtrans-order-test',
                'gross_amount' => '110001.00',
                'transaction_status' => 'pending',
            ], 200),
        ]);
        $customer = User::factory()->create();
        $order = $this->makeMidtransOrder($customer);
        $order->update(['midtrans_order_id' => 'midtrans-order-test']);

        $this->getJson(
            '/api/orders/'.$order->id.'/midtrans-status',
            $this->headersFor($customer),
        )->assertUnprocessable()
            ->assertJsonPath('message', 'Midtrans transaction does not match this order.');

        $this->assertSame('pending', $order->fresh()->payment_status);
    }

    public function test_midtrans_return_status_checks_the_transaction_and_confirms_payment(): void
    {
        config([
            'services.midtrans.server_key' => 'SB-Mid-server-test-key',
            'services.midtrans.api_url' => 'https://api.sandbox.midtrans.com/v2',
        ]);
        $customer = User::factory()->create();
        $order = $this->makeMidtransOrder($customer);
        $midtransOrderId = 'KEL-'.$order->id.'-return';
        $order->update(['midtrans_order_id' => $midtransOrderId]);
        Http::fake([
            'https://api.sandbox.midtrans.com/v2/*/status' => Http::response([
                'status_code' => '200',
                'order_id' => $midtransOrderId,
                'gross_amount' => '110000.00',
                'transaction_status' => 'settlement',
                'transaction_id' => 'midtrans-return-transaction',
            ]),
        ]);

        $this->getJson(
            '/api/payments/midtrans/return-status?order_id='.$midtransOrderId,
            $this->headersFor($customer),
        )->assertOk()
            ->assertJsonPath('data.order_id', $order->id)
            ->assertJsonPath('data.order_code', $order->code)
            ->assertJsonPath('data.payment_status', 'paid');

        $this->assertDatabaseHas('orders', [
            'id' => $order->id,
            'payment_status' => 'paid',
            'status' => 'processing',
            'midtrans_transaction_id' => 'midtrans-return-transaction',
        ]);
        Http::assertSent(fn (HttpRequest $request): bool => $request->method() === 'GET'
            && str_ends_with($request->url(), '/'.$midtransOrderId.'/status'));
    }

    public function test_midtrans_return_status_does_not_trust_query_transaction_status(): void
    {
        config([
            'services.midtrans.server_key' => 'SB-Mid-server-test-key',
            'services.midtrans.api_url' => 'https://api.sandbox.midtrans.com/v2',
        ]);
        $customer = User::factory()->create();
        $order = $this->makeMidtransOrder($customer);
        $midtransOrderId = 'KEL-'.$order->id.'-return';
        $order->update(['midtrans_order_id' => $midtransOrderId]);
        Http::fake([
            'https://api.sandbox.midtrans.com/v2/*/status' => Http::response([
                'status_code' => '200',
                'order_id' => $midtransOrderId,
                'gross_amount' => '110000.00',
                'transaction_status' => 'pending',
            ]),
        ]);

        $this->getJson(
            '/api/payments/midtrans/return-status?order_id='.$midtransOrderId
                .'&transaction_status=settlement',
            $this->headersFor($customer),
        )->assertOk()
            ->assertJsonPath('data.payment_status', 'pending');

        $this->assertSame('pending', $order->fresh()->payment_status);
    }

    public function test_midtrans_return_status_rejects_an_amount_mismatch_and_other_users_order(): void
    {
        config([
            'services.midtrans.server_key' => 'SB-Mid-server-test-key',
            'services.midtrans.api_url' => 'https://api.sandbox.midtrans.com/v2',
        ]);
        $customer = User::factory()->create();
        $otherCustomer = User::factory()->create();
        $order = $this->makeMidtransOrder($customer);
        $otherOrder = $this->makeMidtransOrder($otherCustomer);
        $midtransOrderId = 'KEL-'.$order->id.'-return';
        $otherMidtransOrderId = 'KEL-'.$otherOrder->id.'-return';
        $order->update(['midtrans_order_id' => $midtransOrderId]);
        $otherOrder->update(['midtrans_order_id' => $otherMidtransOrderId]);
        Http::fake([
            'https://api.sandbox.midtrans.com/v2/*/status' => Http::response([
                'status_code' => '200',
                'order_id' => $midtransOrderId,
                'gross_amount' => '110001.00',
                'transaction_status' => 'settlement',
            ]),
        ]);

        $this->getJson(
            '/api/payments/midtrans/return-status?order_id='.$midtransOrderId,
            $this->headersFor($customer),
        )->assertUnprocessable()
            ->assertJsonPath('message', 'Midtrans transaction does not match this order.');

        $this->assertSame('pending', $order->fresh()->payment_status);
        $this->getJson(
            '/api/payments/midtrans/return-status?order_id='.$otherMidtransOrderId,
            $this->headersFor($customer),
        )->assertNotFound();
    }

    public function test_expired_midtrans_order_can_be_retried_when_stock_is_available(): void
    {
        config([
            'services.midtrans.server_key' => 'SB-Mid-server-test-key',
            'services.midtrans.api_url' => 'https://api.sandbox.midtrans.com/v2',
            'services.midtrans.snap_url' => 'https://app.sandbox.midtrans.com/snap/v1/transactions',
        ]);
        Http::fake([
            'https://api.sandbox.midtrans.com/v2/*/status' => Http::response([
                'status_code' => '404',
                'status_message' => "Transaction doesn't exist.",
            ]),
            'https://app.sandbox.midtrans.com/snap/v1/transactions' => Http::response([
                'token' => 'snap-expired-retry-token',
                'redirect_url' => 'https://app.sandbox.midtrans.com/snap/v2/vtweb/snap-expired-retry-token',
            ], 201),
        ]);
        $customer = User::factory()->create();
        $product = Product::create([
            'category_id' => Category::create(['name' => 'Retry category', 'slug' => 'retry-category'])->id,
            'name' => 'Retry product',
            'price' => 100000,
            'weight' => 500,
            'stock' => 5,
            'is_active' => true,
        ]);
        $order = $this->makeMidtransOrder($customer);
        $order->items()->firstOrFail()->update(['product_id' => $product->id]);
        $oldMidtransOrderId = 'KEL-'.$order->id.'-expired';
        $order->update([
            'midtrans_order_id' => $oldMidtransOrderId,
            'midtrans_redirect_url' => 'https://app.sandbox.midtrans.com/snap/v2/vtweb/expired-token',
            'payment_status' => 'expired',
            'status' => 'cancelled',
        ]);

        $this->postJson(
            '/api/orders/'.$order->id.'/midtrans-payment',
            [],
            $this->headersFor($customer),
        )->assertOk()
            ->assertJsonPath('data.payment_status', 'pending');

        $this->assertSame(4, $product->fresh()->stock);
        $this->assertDatabaseHas('orders', [
            'id' => $order->id,
            'payment_status' => 'pending',
            'status' => 'pending_payment',
        ]);
    }

    public function test_midtrans_notifications_require_a_valid_signature_and_confirm_payment(): void
    {
        config(['services.midtrans.server_key' => 'SB-Mid-server-test-key']);
        $customer = User::factory()->create();
        $order = $this->makeMidtransOrder($customer);
        $order->update(['midtrans_order_id' => 'KEL-'.$order->id.'-attempt']);
        $notification = [
            'order_id' => $order->midtrans_order_id,
            'status_code' => '200',
            'gross_amount' => '110000.00',
            'transaction_status' => 'settlement',
            'transaction_id' => 'midtrans-transaction-123',
            'payment_type' => 'qris',
        ];
        $notification['signature_key'] = hash(
            'sha512',
            $notification['order_id'].$notification['status_code']
                .$notification['gross_amount'].'SB-Mid-server-test-key',
        );

        $this->postJson('/api/payments/midtrans/notification', [
            ...$notification,
            'signature_key' => 'invalid',
        ])->assertForbidden();
        $this->assertSame('pending', $order->fresh()->payment_status);

        $this->postJson('/api/payments/midtrans/notification', $notification)
            ->assertOk();
        $this->assertDatabaseHas('orders', [
            'id' => $order->id,
            'payment_status' => 'paid',
            'status' => 'processing',
            'midtrans_transaction_id' => 'midtrans-transaction-123',
        ]);
    }

    public function test_midtrans_notification_rejects_an_amount_that_does_not_match_the_order(): void
    {
        config(['services.midtrans.server_key' => 'SB-Mid-server-test-key']);
        $customer = User::factory()->create();
        $order = $this->makeMidtransOrder($customer);
        $order->update(['midtrans_order_id' => 'KEL-'.$order->id.'-attempt']);
        $notification = [
            'order_id' => $order->midtrans_order_id,
            'status_code' => '200',
            'gross_amount' => '1.00',
            'transaction_status' => 'settlement',
            'transaction_id' => 'midtrans-transaction-123',
        ];
        $notification['signature_key'] = hash(
            'sha512',
            $notification['order_id'].$notification['status_code']
                .$notification['gross_amount'].'SB-Mid-server-test-key',
        );

        $this->postJson('/api/payments/midtrans/notification', $notification)
            ->assertUnprocessable();
        $this->assertSame('pending', $order->fresh()->payment_status);
    }

    public function test_customer_cannot_start_another_users_midtrans_payment(): void
    {
        $customer = User::factory()->create();
        $otherCustomer = User::factory()->create();
        $order = $this->makeMidtransOrder($otherCustomer);

        $this->postJson(
            '/api/orders/'.$order->id.'/midtrans-payment',
            [],
            $this->headersFor($customer),
        )->assertNotFound();
    }

    public function test_unpaid_bank_transfer_orders_expire_after_24_hours(): void
    {
        $customer = User::factory()->create();
        $expired = $this->makeOrder($customer);
        $submitted = $this->makeOrder($customer, 'proof_submitted');
        $recent = $this->makeOrder($customer);
        $expired->forceFill(['created_at' => now()->subHours(25)])->save();
        $submitted->forceFill(['created_at' => now()->subHours(25)])->save();
        $product = Product::create([
            'category_id' => Category::create(['name' => 'Test', 'slug' => 'test'])->id,
            'name' => 'Test product',
            'price' => 1000,
            'weight' => 500,
            'stock' => 3,
            'is_active' => true,
        ]);
        $expired->items()->create([
            'product_id' => $product->id,
            'product_name' => $product->name,
            'quantity' => 2,
            'price' => $product->price,
        ]);

        $this->artisan('orders:cancel-expired')->assertSuccessful();

        $this->assertDatabaseHas('orders', [
            'id' => $expired->id,
            'status' => 'cancelled',
            'payment_status' => 'expired',
        ]);
        $this->assertDatabaseHas('orders', [
            'id' => $submitted->id,
            'status' => 'pending_payment',
            'payment_status' => 'proof_submitted',
        ]);
        $this->assertDatabaseHas('orders', [
            'id' => $recent->id,
            'status' => 'pending_payment',
            'payment_status' => 'pending',
        ]);
        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'stock' => 5,
        ]);
    }

    private function makeOrder(User $customer, string $paymentStatus = 'pending'): Order
    {
        return Order::create([
            'user_id' => $customer->id,
            'code' => 'KEL-'.$customer->id.'-'.bin2hex(random_bytes(5)),
            'recipient_name' => $customer->name,
            'phone' => '081234567890',
            'address' => 'Jalan Melati nomor 10, Jakarta',
            'payment_method' => 'bank_transfer',
            'payment_status' => $paymentStatus,
            'status' => 'pending_payment',
            'subtotal' => 100000,
            'shipping_cost' => 10000,
            'payment_unique_code' => 123,
            'total' => 110123,
        ]);
    }

    private function makeMidtransOrder(User $customer): Order
    {
        $order = Order::create([
            'user_id' => $customer->id,
            'code' => 'KEL-'.$customer->id.'-'.bin2hex(random_bytes(5)),
            'recipient_name' => $customer->name,
            'phone' => '081234567890',
            'address' => 'Jalan Melati nomor 10, Jakarta',
            'payment_method' => 'midtrans',
            'payment_status' => 'pending',
            'status' => 'pending_payment',
            'subtotal' => 100000,
            'shipping_cost' => 10000,
            'payment_unique_code' => 0,
            'total' => 110000,
        ]);
        $order->items()->create([
            'product_name' => 'Produk uji',
            'quantity' => 1,
            'price' => 100000,
        ]);

        return $order;
    }

    private function headersFor(User $user): array
    {
        return [
            'Authorization' => 'Bearer '.$user->createToken('payment-test')->plainTextToken,
        ];
    }

    private function pngUpload(): UploadedFile
    {
        return UploadedFile::fake()->createWithContent(
            'receipt.png',
            base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC'),
        );
    }
}
