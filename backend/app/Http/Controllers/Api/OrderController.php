<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Product;
use App\Services\RajaOngkirException;
use App\Services\RajaOngkirService;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class OrderController extends Controller
{
    public function __construct(private readonly RajaOngkirService $rajaOngkir) {}

    public function index(Request $request): JsonResponse
    {
        $orders = $request->user()->orders()->with('items')
            ->latest('id')->get()
            ->map(fn (Order $order): array => $this->orderData($order));

        return response()->json(['data' => $orders]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'recipient_name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:30'],
            'address' => ['required', 'string', 'min:10', 'max:2000'],
            'destination_id' => ['required', 'integer', 'min:1'],
            'destination_label' => ['required', 'string', 'max:255'],
            'courier' => ['required', 'string', Rule::in(config('services.rajaongkir.couriers', []))],
            'courier_service' => ['required', 'string', 'max:100'],
            'payment_method' => ['required', Rule::in(['bank_transfer', 'cod', 'ewallet', 'midtrans'])],
        ]);

        $cartBeforeQuote = $request->user()->cartItems()->with('product')->get();
        if ($cartBeforeQuote->isEmpty()) {
            throw ValidationException::withMessages([
                'cart' => ['Keranjang masih kosong.'],
            ]);
        }

        foreach ($cartBeforeQuote as $cartItem) {
            if (! $cartItem->product->is_active || $cartItem->product->stock < $cartItem->quantity) {
                throw ValidationException::withMessages([
                    'cart' => ["Stok {$cartItem->product->name} tidak mencukupi."],
                ]);
            }
        }

        $quotedWeight = max(1, (int) ceil($cartBeforeQuote->sum(
            fn ($item): float => (float) $item->product->weight * $item->quantity,
        )));

        try {
            $shippingServices = $this->rajaOngkir->calculate(
                (int) $data['destination_id'],
                $quotedWeight,
                $data['courier'],
            );
        } catch (RajaOngkirException $exception) {
            return response()->json(['message' => $exception->getMessage()], 502);
        } catch (ConnectionException) {
            return response()->json(['message' => 'Tidak dapat terhubung ke RajaOngkir. Coba lagi.'], 502);
        }

        $selectedService = collect($shippingServices)->first(
            fn (array $service): bool => ($service['service'] ?? null) === $data['courier_service'],
        );

        if ($selectedService === null || ! is_numeric($selectedService['cost'] ?? null)) {
            return response()->json([
                'message' => 'Layanan kurir yang dipilih sudah tidak tersedia. Silakan hitung ongkir kembali.',
            ], 422);
        }

        $order = DB::transaction(function () use ($request, $data, $quotedWeight, $selectedService): Order {
            DB::table('users')->where('id', $request->user()->id)->lockForUpdate()->first();
            $cartItems = $request->user()->cartItems()
                ->with('product')
                ->orderBy('product_id')
                ->lockForUpdate()
                ->get();

            if ($cartItems->isEmpty()) {
                throw ValidationException::withMessages([
                    'cart' => ['Keranjang masih kosong.'],
                ]);
            }

            $lockedProducts = [];
            $subtotalCents = 0;
            foreach ($cartItems as $cartItem) {
                $product = Product::query()->whereKey($cartItem->product_id)
                    ->lockForUpdate()->firstOrFail();

                if (! $product->is_active) {
                    throw ValidationException::withMessages([
                        'cart' => ["Produk {$product->name} sudah tidak tersedia."],
                    ]);
                }

                if ($product->stock < $cartItem->quantity) {
                    throw ValidationException::withMessages([
                        'cart' => ["Stok {$product->name} tidak mencukupi."],
                    ]);
                }

                $lockedProducts[$cartItem->id] = $product;
                $subtotalCents += (int) round((float) $product->price * 100) * $cartItem->quantity;
            }

            $lockedWeight = max(1, (int) ceil(collect($cartItems)->sum(
                fn ($item): float => (float) $lockedProducts[$item->id]->weight * $item->quantity,
            )));
            if ($lockedWeight !== $quotedWeight) {
                throw ValidationException::withMessages([
                    'cart' => ['Isi keranjang berubah. Silakan hitung ulang ongkos kirim.'],
                ]);
            }

            $shippingCents = (int) $selectedService['cost'] * 100;
            $uniqueCode = $data['payment_method'] === 'bank_transfer'
                ? random_int(1, 999)
                : 0;
            $order = $request->user()->orders()->create([
                'code' => 'KEL-'.$request->user()->id.'-'.now()->format('ymdHis').'-'.Str::upper(Str::random(5)),
                'recipient_name' => $data['recipient_name'],
                'phone' => $data['phone'],
                'address' => $data['address'],
                'destination_id' => $data['destination_id'],
                'destination_label' => $data['destination_label'],
                'courier_code' => $data['courier'],
                'courier_service' => $selectedService['service'],
                'shipping_etd' => $selectedService['etd'] ?? null,
                'payment_method' => $data['payment_method'],
                'payment_status' => 'pending',
                'status' => 'pending_payment',
                'payment_unique_code' => $uniqueCode,
                'subtotal' => $this->money($subtotalCents),
                'shipping_cost' => $this->money($shippingCents),
                'total' => $this->money($subtotalCents + $shippingCents + $uniqueCode * 100),
            ]);

            foreach ($cartItems as $cartItem) {
                $product = $lockedProducts[$cartItem->id];
                $order->items()->create([
                    'product_id' => $product->id,
                    'product_name' => $product->name,
                    'quantity' => $cartItem->quantity,
                    'price' => $product->price,
                ]);
                $product->decrement('stock', $cartItem->quantity);
            }

            $request->user()->cartItems()->delete();

            return $order->load('items');
        });

        return response()->json(['data' => $this->orderData($order)], 201);
    }

    public function show(Request $request, Order $order): JsonResponse
    {
        abort_unless($order->user_id === $request->user()->id, 404);

        return response()->json([
            'data' => $this->orderData($order->load('items')),
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function orderData(Order $order): array
    {
        return [
            'id' => $order->id,
            'code' => $order->code,
            'status' => $order->status,
            'payment_status' => $order->payment_status,
            'payment_method' => $order->payment_method,
            'recipient_name' => $order->recipient_name,
            'phone' => $order->phone,
            'address' => $order->address,
            'destination_label' => $order->destination_label,
            'courier_code' => $order->courier_code,
            'courier_service' => $order->courier_service,
            'shipping_etd' => $order->shipping_etd,
            'payment_unique_code' => $order->payment_unique_code,
            'midtrans_redirect_url' => $order->midtrans_redirect_url,
            'payment_proof_uploaded_at' => $order->payment_proof_uploaded_at?->toISOString(),
            'payment_confirmed_at' => $order->payment_confirmed_at?->toISOString(),
            'payment_confirmed_by' => $order->payment_confirmed_by,
            'payment_rejection_reason' => $order->payment_rejection_reason,
            'payment_proof_url' => $order->payment_proof_path === null
                ? null
                : url('/api/orders/'.$order->id.'/payment-proof'),
            'subtotal' => $order->subtotal,
            'shipping_cost' => $order->shipping_cost,
            'total' => $order->total,
            'created_at' => $order->created_at->toISOString(),
            'items' => $order->items->map(fn ($item): array => [
                'product_id' => $item->product_id,
                'product_name' => $item->product_name,
                'quantity' => $item->quantity,
                'price' => $item->price,
            ]),
        ];
    }

    private function money(int $cents): string
    {
        return intdiv($cents, 100).'.'.str_pad((string) ($cents % 100), 2, '0', STR_PAD_LEFT);
    }
}
