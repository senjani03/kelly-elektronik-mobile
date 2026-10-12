<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CartItem;
use App\Services\RajaOngkirException;
use App\Services\RajaOngkirService;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ShippingController extends Controller
{
    public function __construct(private readonly RajaOngkirService $rajaOngkir) {}

    public function destinations(Request $request): JsonResponse
    {
        $data = $request->validate([
            'search' => ['required', 'string', 'min:2', 'max:100'],
        ]);

        try {
            return response()->json([
                'data' => $this->rajaOngkir->searchDestinations($data['search']),
            ]);
        } catch (RajaOngkirException $exception) {
            return response()->json(['message' => $exception->getMessage()], 502);
        } catch (ConnectionException) {
            return response()->json(['message' => 'Tidak dapat terhubung ke RajaOngkir. Coba lagi.'], 502);
        }
    }

    public function couriers(): JsonResponse
    {
        $couriers = [
            'jne' => 'JNE',
            'jnt' => 'J&T',
            'sicepat' => 'SiCepat',
            'pos' => 'POS Indonesia',
            'tiki' => 'TIKI',
            'wahana' => 'Wahana',
            'ninja' => 'Ninja Xpress',
            'lion' => 'Lion Parcel',
        ];

        $enabled = config('services.rajaongkir.couriers', []);

        return response()->json([
            'data' => collect($enabled)
                ->filter(fn (string $code): bool => isset($couriers[$code]))
                ->map(fn (string $code): array => [
                    'code' => $code,
                    'name' => $couriers[$code],
                ])->values(),
        ]);
    }

    public function quote(Request $request): JsonResponse
    {
        $couriers = config('services.rajaongkir.couriers', []);
        $data = $request->validate([
            'destination_id' => ['required', 'integer', 'min:1'],
            'courier' => ['required', 'string', Rule::in($couriers)],
        ]);

        $weight = $this->cartWeight($request);

        try {
            return response()->json([
                'data' => [
                    'weight' => $weight,
                    'services' => $this->rajaOngkir->calculate(
                        (int) $data['destination_id'],
                        $weight,
                        $data['courier'],
                    ),
                ],
            ]);
        } catch (RajaOngkirException $exception) {
            return response()->json(['message' => $exception->getMessage()], 502);
        } catch (ConnectionException) {
            return response()->json(['message' => 'Tidak dapat terhubung ke RajaOngkir. Coba lagi.'], 502);
        }
    }

    private function cartWeight(Request $request): int
    {
        $items = $request->user()->cartItems()->with('product')->get();

        return max(1, (int) ceil($items->sum(
            fn (CartItem $item): float => (float) $item->product->weight * $item->quantity,
        )));
    }
}
