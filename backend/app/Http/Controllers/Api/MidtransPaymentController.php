<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Product;
use App\Services\MidtransException;
use App\Services\MidtransService;
use App\Services\MidtransTransactionNotFoundException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class MidtransPaymentController extends Controller
{
    public function create(
        Request $request,
        Order $order,
        MidtransService $midtrans,
    ): JsonResponse {
        abort_unless($order->user_id === $request->user()->id, 404);
        $this->prepareExpiredOrderForRetry($order);
        $this->ensurePayable($order);

        try {
            if ($order->midtrans_order_id !== null && $order->midtrans_redirect_url !== null) {
                try {
                    $status = $midtrans->transactionStatus($order->midtrans_order_id);
                } catch (MidtransTransactionNotFoundException) {
                    $status = null;
                }

                if ($status !== null) {
                    $this->ensureStatusMatchesOrder($order, $status);
                    $this->applyStatus($order, $status);
                    $order->refresh();

                    if ($order->payment_status === 'paid') {
                        return response()->json([
                            'data' => ['payment_status' => 'paid'],
                        ]);
                    }

                    if ($order->status !== 'pending_payment'
                        || ! in_array($order->payment_status, ['pending', 'failed'], true)) {
                        throw ValidationException::withMessages([
                            'payment' => ['Pesanan ini tidak dapat dibayar melalui Midtrans.'],
                        ]);
                    }

                    if ($order->payment_status === 'pending') {
                        return response()->json([
                            'data' => [
                                'payment_status' => 'pending',
                                'redirect_url' => $order->midtrans_redirect_url,
                            ],
                        ]);
                    }
                }
            }

            $transaction = $midtrans->createSnapTransaction(
                $order->load(['items', 'user']),
            );
            $order->update([
                'midtrans_order_id' => $transaction['order_id'],
                'midtrans_snap_token' => $transaction['token'],
                'midtrans_redirect_url' => $transaction['redirect_url'],
                'payment_status' => 'pending',
            ]);
        } catch (MidtransException $exception) {
            return response()->json(['message' => $exception->getMessage()], 502);
        }

        return response()->json([
            'data' => [
                'payment_status' => 'pending',
                'redirect_url' => $transaction['redirect_url'],
            ],
        ]);
    }

    public function refreshStatus(
        Request $request,
        Order $order,
        MidtransService $midtrans,
    ): JsonResponse {
        abort_unless($order->user_id === $request->user()->id, 404);
        if ($order->payment_method !== 'midtrans') {
            throw ValidationException::withMessages([
                'payment' => ['Pesanan ini tidak menggunakan Midtrans.'],
            ]);
        }

        try {
            $this->refreshOrderStatus($order, $midtrans);
        } catch (MidtransException $exception) {
            return response()->json(['message' => $exception->getMessage()], 502);
        }

        return response()->json([
            'data' => ['payment_status' => $order->fresh()->payment_status],
        ]);
    }

    public function refreshReturnStatus(
        Request $request,
        MidtransService $midtrans,
    ): JsonResponse {
        $data = $request->validate([
            'order_id' => ['required', 'string', 'max:255'],
        ]);
        $order = $request->user()->orders()
            ->where('midtrans_order_id', $data['order_id'])
            ->firstOrFail();

        try {
            $this->refreshOrderStatus($order, $midtrans);
        } catch (MidtransException $exception) {
            return response()->json(['message' => $exception->getMessage()], 502);
        }

        $order->refresh();

        return response()->json([
            'data' => [
                'order_id' => $order->id,
                'order_code' => $order->code,
                'payment_status' => $order->payment_status,
            ],
        ]);
    }

    public function notification(Request $request, MidtransService $midtrans): JsonResponse
    {
        $notification = $request->all();
        try {
            abort_unless($midtrans->verifyNotification($notification), 403, 'Invalid Midtrans signature.');
        } catch (MidtransException $exception) {
            return response()->json(['message' => $exception->getMessage()], 503);
        }

        $order = Order::query()
            ->where('midtrans_order_id', $notification['order_id'])
            ->firstOrFail();
        $this->ensureStatusMatchesOrder($order, $notification);
        $this->applyStatus($order, $notification);

        return response()->json(['message' => 'Notification processed.']);
    }

    /**
     * @param  array<string, mixed>  $status
     */
    private function ensureStatusMatchesOrder(Order $order, array $status): void
    {
        abort_unless(
            ($status['order_id'] ?? null) === $order->midtrans_order_id
                && is_numeric($status['gross_amount'] ?? null)
                && number_format((float) $status['gross_amount'], 2, '.', '')
                    === number_format((float) $order->total, 2, '.', ''),
            422,
            'Midtrans transaction does not match this order.',
        );
    }

    /**
     * @param  array<string, mixed>  $status
     */
    private function applyStatus(Order $order, array $status): void
    {
        DB::transaction(function () use ($order, $status): void {
            $lockedOrder = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();
            if ($lockedOrder->payment_method !== 'midtrans'
                || $lockedOrder->midtrans_order_id !== ($status['order_id'] ?? null)
                || $lockedOrder->payment_status === 'paid') {
                return;
            }

            $transactionStatus = $status['transaction_status'] ?? null;
            $fraudAccepted = ($status['fraud_status'] ?? null) === 'accept';

            if ($transactionStatus === 'settlement'
                || ($transactionStatus === 'capture' && $fraudAccepted)) {
                $lockedOrder->update([
                    'payment_status' => 'paid',
                    'midtrans_transaction_id' => $status['transaction_id'] ?? null,
                    'payment_confirmed_at' => now(),
                    'payment_confirmed_by' => null,
                    'status' => 'processing',
                ]);

                return;
            }

            if (in_array($transactionStatus, ['deny', 'cancel'], true)) {
                $lockedOrder->update([
                    'payment_status' => 'failed',
                    'midtrans_transaction_id' => $status['transaction_id'] ?? null,
                ]);

                return;
            }

            if ($transactionStatus === 'pending') {
                $lockedOrder->update([
                    'payment_status' => 'pending',
                    'midtrans_transaction_id' => $status['transaction_id'] ?? null,
                ]);

                return;
            }

            if ($transactionStatus === 'expire'
                && $lockedOrder->status === 'pending_payment') {
                foreach ($lockedOrder->items as $item) {
                    Product::query()->whereKey($item->product_id)
                        ->increment('stock', $item->quantity);
                }

                $lockedOrder->update([
                    'payment_status' => 'expired',
                    'midtrans_transaction_id' => $status['transaction_id'] ?? null,
                    'status' => 'cancelled',
                ]);
            }
        });
    }

    private function refreshOrderStatus(Order $order, MidtransService $midtrans): void
    {
        if ($order->payment_status === 'paid' || $order->midtrans_order_id === null) {
            return;
        }

        $status = $midtrans->transactionStatus($order->midtrans_order_id);
        $this->ensureStatusMatchesOrder($order, $status);
        $this->applyStatus($order, $status);
    }

    private function prepareExpiredOrderForRetry(Order $order): void
    {
        if ($order->payment_method !== 'midtrans'
            || $order->payment_status !== 'expired'
            || $order->status !== 'cancelled') {
            return;
        }

        DB::transaction(function () use ($order): void {
            $lockedOrder = Order::query()->whereKey($order->id)
                ->lockForUpdate()->firstOrFail();
            if ($lockedOrder->payment_method !== 'midtrans'
                || $lockedOrder->payment_status !== 'expired'
                || $lockedOrder->status !== 'cancelled') {
                return;
            }

            $items = $lockedOrder->items()->orderBy('product_id')->get();
            foreach ($items as $item) {
                $product = $item->product_id === null
                    ? null
                    : Product::query()->whereKey($item->product_id)
                        ->lockForUpdate()->first();
                if ($product === null || ! $product->is_active
                    || $product->stock < $item->quantity) {
                    throw ValidationException::withMessages([
                        'payment' => [
                            "Stok {$item->product_name} tidak mencukupi untuk bayar ulang.",
                        ],
                    ]);
                }

                $product->decrement('stock', $item->quantity);
            }

            $lockedOrder->update([
                'payment_status' => 'pending',
                'status' => 'pending_payment',
            ]);
        });

        $order->refresh();
    }

    private function ensurePayable(Order $order): void
    {
        if ($order->payment_method !== 'midtrans'
            || $order->status !== 'pending_payment'
            || ! in_array($order->payment_status, ['pending', 'failed'], true)) {
            throw ValidationException::withMessages([
                'payment' => ['Pesanan ini tidak dapat dibayar melalui Midtrans.'],
            ]);
        }
    }
}
