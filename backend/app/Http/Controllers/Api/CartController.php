<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CartItem;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CartController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $items = $request->user()->cartItems()
            ->with('product.category:id,name')
            ->orderBy('id')
            ->get()
            ->map(fn (CartItem $item): array => $this->cartItemData($item));

        return response()->json(['data' => $items]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'product_id' => ['required', 'integer', 'exists:products,id'],
            'quantity' => ['required', 'integer', 'min:1', 'max:100'],
        ]);

        $item = DB::transaction(function () use ($request, $data): CartItem {
            DB::table('users')->where('id', $request->user()->id)->lockForUpdate()->first();
            $product = Product::query()->whereKey($data['product_id'])
                ->where('is_active', true)->lockForUpdate()->firstOrFail();
            $item = $request->user()->cartItems()
                ->where('product_id', $product->id)->lockForUpdate()->first();
            $quantity = ($item?->quantity ?? 0) + $data['quantity'];

            $this->ensureStock($product, $quantity);

            if ($item === null) {
                $item = $request->user()->cartItems()->create([
                    'product_id' => $product->id,
                    'quantity' => $quantity,
                ]);
            } else {
                $item->update(['quantity' => $quantity]);
            }

            return $item->load('product.category:id,name');
        });

        return response()->json(['data' => $this->cartItemData($item)], 201);
    }

    public function update(Request $request, CartItem $cartItem): JsonResponse
    {
        abort_unless($cartItem->user_id === $request->user()->id, 404);
        $data = $request->validate([
            'quantity' => ['required', 'integer', 'min:1', 'max:100'],
        ]);

        $item = DB::transaction(function () use ($request, $cartItem, $data): CartItem {
            DB::table('users')->where('id', $request->user()->id)->lockForUpdate()->first();
            $item = $request->user()->cartItems()->whereKey($cartItem->id)
                ->lockForUpdate()->firstOrFail();
            $product = Product::query()->whereKey($item->product_id)
                ->where('is_active', true)->lockForUpdate()->firstOrFail();
            $this->ensureStock($product, $data['quantity']);
            $item->update(['quantity' => $data['quantity']]);

            return $item->load('product.category:id,name');
        });

        return response()->json(['data' => $this->cartItemData($item)]);
    }

    public function destroy(Request $request, CartItem $cartItem): JsonResponse
    {
        abort_unless($cartItem->user_id === $request->user()->id, 404);
        DB::transaction(function () use ($request, $cartItem): void {
            DB::table('users')->where('id', $request->user()->id)->lockForUpdate()->first();
            $request->user()->cartItems()->whereKey($cartItem->id)->delete();
        });

        return response()->json(['message' => 'Produk dihapus dari keranjang']);
    }

    /**
     * @return array<string, mixed>
     */
    private function cartItemData(CartItem $item): array
    {
        return [
            'id' => $item->id,
            'quantity' => $item->quantity,
            'product' => app(ProductController::class)->productData($item->product),
        ];
    }

    private function ensureStock(Product $product, int $quantity): void
    {
        if ($product->stock < $quantity) {
            throw ValidationException::withMessages([
                'quantity' => ["Stok {$product->name} tidak mencukupi."],
            ]);
        }
    }
}
