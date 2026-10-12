<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

class PaymentController extends Controller
{
    public function details(): JsonResponse
    {
        $details = config('services.shop_bank');
        if (collect($details)->contains(fn ($value): bool => ! is_string($value) || trim($value) === '')) {
            return response()->json([
                'message' => 'Informasi rekening toko belum diatur di backend/.env.',
            ], 503);
        }

        return response()->json(['data' => $details]);
    }

    public function uploadProof(Request $request, Order $order): JsonResponse
    {
        abort_unless($order->user_id === $request->user()->id, 404);
        $this->ensureProofCanBeUploaded($order);

        $data = $request->validate([
            'proof' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:5120'],
        ]);

        $newPath = $data['proof']->store('payment-proofs', 'local');
        if ($newPath === false) {
            return response()->json(['message' => 'Bukti transfer gagal disimpan. Coba lagi.'], 500);
        }

        $previousPath = null;
        try {
            DB::transaction(function () use ($request, $order, $newPath, &$previousPath): void {
                $lockedOrder = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();
                abort_unless($lockedOrder->user_id === $request->user()->id, 404);
                $this->ensureProofCanBeUploaded($lockedOrder);

                $previousPath = $lockedOrder->payment_proof_path;
                $lockedOrder->update([
                    'payment_proof_path' => $newPath,
                    'payment_proof_uploaded_at' => now(),
                    'payment_status' => 'proof_submitted',
                    'payment_rejection_reason' => null,
                ]);
            });
        } catch (\Throwable $exception) {
            Storage::disk('local')->delete($newPath);
            throw $exception;
        }

        if ($previousPath !== null) {
            Storage::disk('local')->delete($previousPath);
        }

        return response()->json([
            'message' => 'Bukti transfer berhasil dikirim untuk diperiksa admin.',
            'data' => [
                'payment_status' => $order->fresh()->payment_status,
                'payment_proof_uploaded_at' => $order->fresh()->payment_proof_uploaded_at?->toISOString(),
            ],
        ]);
    }

    public function showProof(Request $request, Order $order): Response
    {
        abort_unless(
            $order->user_id === $request->user()->id || $request->user()->role === 'admin',
            404,
        );
        abort_if($order->payment_proof_path === null, 404);
        abort_unless(Storage::disk('local')->exists($order->payment_proof_path), 404);

        return Storage::disk('local')->response($order->payment_proof_path);
    }

    public function pending(): JsonResponse
    {
        $orders = Order::query()
            ->with(['user:id,name,email,phone', 'items'])
            ->where('payment_method', 'bank_transfer')
            ->where('payment_status', 'proof_submitted')
            ->latest('payment_proof_uploaded_at')
            ->get()
            ->map(fn (Order $order): array => $this->adminOrderData($order));

        return response()->json(['data' => $orders]);
    }

    public function confirm(Request $request, Order $order): JsonResponse
    {
        $updated = DB::transaction(function () use ($request, $order): Order {
            $lockedOrder = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();
            $this->ensurePendingConfirmation($lockedOrder);

            $lockedOrder->update([
                'payment_status' => 'paid',
                'payment_confirmed_at' => now(),
                'payment_confirmed_by' => $request->user()->id,
                'payment_rejection_reason' => null,
                'status' => 'processing',
            ]);

            return $lockedOrder->fresh(['user', 'items']);
        });

        return response()->json([
            'message' => 'Pembayaran berhasil dikonfirmasi.',
            'data' => $this->adminOrderData($updated),
        ]);
    }

    public function reject(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'reason' => ['required', 'string', 'min:3', 'max:1000'],
        ]);

        $updated = DB::transaction(function () use ($order, $data): Order {
            $lockedOrder = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();
            $this->ensurePendingConfirmation($lockedOrder);

            $lockedOrder->update([
                'payment_status' => 'rejected',
                'payment_confirmed_at' => null,
                'payment_confirmed_by' => null,
                'payment_rejection_reason' => $data['reason'],
            ]);

            return $lockedOrder->fresh(['user', 'items']);
        });

        return response()->json([
            'message' => 'Bukti transfer ditolak.',
            'data' => $this->adminOrderData($updated),
        ]);
    }

    private function ensureProofCanBeUploaded(Order $order): void
    {
        if ($order->payment_method !== 'bank_transfer'
            || $order->status !== 'pending_payment'
            || ! in_array($order->payment_status, ['pending', 'rejected'], true)) {
            throw ValidationException::withMessages([
                'proof' => ['Pesanan ini tidak dapat menerima bukti transfer.'],
            ]);
        }
    }

    private function ensurePendingConfirmation(Order $order): void
    {
        if ($order->payment_method !== 'bank_transfer'
            || $order->status !== 'pending_payment'
            || $order->payment_status !== 'proof_submitted'
            || $order->payment_proof_path === null) {
            throw ValidationException::withMessages([
                'payment' => ['Pesanan ini tidak menunggu konfirmasi pembayaran.'],
            ]);
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function adminOrderData(Order $order): array
    {
        return [
            'id' => $order->id,
            'code' => $order->code,
            'status' => $order->status,
            'payment_status' => $order->payment_status,
            'recipient_name' => $order->recipient_name,
            'phone' => $order->phone,
            'address' => $order->address,
            'destination_label' => $order->destination_label,
            'total' => $order->total,
            'payment_proof_uploaded_at' => $order->payment_proof_uploaded_at?->toISOString(),
            'payment_proof_url' => url('/api/orders/'.$order->id.'/payment-proof'),
            'user' => $order->user === null ? null : [
                'name' => $order->user->name,
                'email' => $order->user->email,
                'phone' => $order->user->phone,
            ],
            'items' => $order->items->map(fn ($item): array => [
                'product_name' => $item->product_name,
                'quantity' => $item->quantity,
                'price' => $item->price,
            ]),
        ];
    }
}
