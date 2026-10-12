<?php

namespace App\Services;

use App\Models\Order;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class MidtransService
{
    /**
     * @return array{order_id: string, token: string, redirect_url: string}
     */
    public function createSnapTransaction(Order $order): array
    {
        $serverKey = $this->serverKey();
        $orderId = 'KEL-'.$order->id.'-'.Str::lower(Str::random(10));
        $items = $order->items->map(function ($item): array {
            $unitPrice = (int) round((float) $item->price);

            return [
                'id' => $item->product_id === null
                    ? 'item-'.$item->id
                    : (string) $item->product_id,
                'price' => $unitPrice,
                'quantity' => $item->quantity,
                'name' => Str::limit($item->product_name, 50, ''),
            ];
        })->all();

        if ((int) $order->shipping_cost > 0) {
            $items[] = [
                'id' => 'shipping',
                'price' => (int) round((float) $order->shipping_cost),
                'quantity' => 1,
                'name' => Str::limit(
                    'Ongkos kirim '.$order->courier_code.' '.$order->courier_service,
                    50,
                    '',
                ),
            ];
        }

        $itemTotal = collect($items)->sum(
            fn (array $item): int => $item['price'] * $item['quantity'],
        );
        $grossAmount = (int) round((float) $order->total);
        if ($itemTotal !== $grossAmount) {
            throw new MidtransException('Rincian harga pesanan tidak cocok dengan total pembayaran.');
        }

        try {
            $response = Http::asJson()
                ->acceptJson()
                ->withBasicAuth($serverKey, '')
                ->timeout(20)
                ->post(config('services.midtrans.snap_url'), [
                    'transaction_details' => [
                        'order_id' => $orderId,
                        'gross_amount' => $grossAmount,
                    ],
                    'item_details' => $items,
                    'customer_details' => [
                        'first_name' => $order->recipient_name,
                        'email' => $order->user->email,
                        'phone' => $order->phone,
                    ],
                    'callbacks' => [
                        'finish' => config('services.midtrans.finish_url'),
                    ],
                ]);
        } catch (ConnectionException) {
            throw new MidtransException('Tidak dapat terhubung ke Midtrans. Coba lagi.');
        }

        if (! $response->successful()) {
            throw new MidtransException(
                $response->json('status_message')
                    ?? 'Midtrans menolak pembuatan transaksi. Periksa konfigurasi Sandbox.',
            );
        }

        $token = $response->json('token');
        $redirectUrl = $response->json('redirect_url');
        if (! is_string($token) || $token === ''
            || ! is_string($redirectUrl) || ! str_starts_with($redirectUrl, 'https://')) {
            throw new MidtransException('Respons transaksi dari Midtrans tidak lengkap.');
        }

        return [
            'order_id' => $orderId,
            'token' => $token,
            'redirect_url' => $redirectUrl,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function transactionStatus(string $orderId): array
    {
        $serverKey = $this->serverKey();

        try {
            $response = Http::acceptJson()
                ->withBasicAuth($serverKey, '')
                ->timeout(20)
                ->get(rtrim(config('services.midtrans.api_url'), '/').'/'.rawurlencode($orderId).'/status');
        } catch (ConnectionException) {
            throw new MidtransException('Tidak dapat memeriksa status pembayaran di Midtrans.');
        }

        $status = $response->json();
        if (is_array($status) && (string) ($status['status_code'] ?? '') === '404') {
            throw new MidtransTransactionNotFoundException(
                'Transaksi Midtrans tidak ditemukan.',
            );
        }

        if (! $response->successful() || ! is_array($status)) {
            throw new MidtransException(
                (is_array($status) ? ($status['status_message'] ?? null) : null)
                    ?? 'Midtrans gagal memberikan status transaksi.',
            );
        }

        return $status;
    }

    public function verifyNotification(array $notification): bool
    {
        $orderId = $notification['order_id'] ?? null;
        $statusCode = $notification['status_code'] ?? null;
        $grossAmount = $notification['gross_amount'] ?? null;
        $signature = $notification['signature_key'] ?? null;

        if (! is_string($orderId) || ! is_string($statusCode)
            || ! is_string($grossAmount) || ! is_string($signature)) {
            return false;
        }

        $expected = hash(
            'sha512',
            $orderId.$statusCode.$grossAmount.$this->serverKey(),
        );

        return hash_equals($expected, $signature);
    }

    private function serverKey(): string
    {
        $key = config('services.midtrans.server_key');
        if (! is_string($key) || trim($key) === '') {
            throw new MidtransException('MIDTRANS_SERVER_KEY belum diatur di backend/.env.');
        }

        return $key;
    }
}
