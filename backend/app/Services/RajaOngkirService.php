<?php

namespace App\Services;

use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class RajaOngkirService
{
    /**
     * @return list<array<string, mixed>>
     */
    public function searchDestinations(string $search): array
    {
        $response = Http::acceptJson()
            ->withHeaders(['key' => $this->apiKey()])
            ->timeout(15)
            ->get($this->url('/destination/domestic-destination'), [
                'search' => $search,
                'limit' => 10,
                'offset' => 0,
            ]);

        return $this->data($response);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function calculate(int $destinationId, int $weight, string $courier): array
    {
        $response = Http::acceptJson()
            ->asForm()
            ->withHeaders(['key' => $this->apiKey()])
            ->timeout(20)
            ->post($this->url('/calculate/domestic-cost'), [
                'origin' => $this->originId(),
                'destination' => $destinationId,
                'weight' => $weight,
                'courier' => $courier,
            ]);

        return $this->data($response);
    }

    private function originId(): int
    {
        $originSearch = (string) config('services.rajaongkir.origin_search');

        return Cache::remember('rajaongkir.origin.'.Str::slug($originSearch), 86400, function () use ($originSearch): int {
            $locations = $this->searchDestinations(
                $originSearch,
            );

            foreach ($locations as $location) {
                $subdistrict = Str::lower((string) ($location['subdistrict_name'] ?? ''));
                $district = Str::lower((string) ($location['district_name'] ?? ''));
                $city = Str::lower((string) ($location['city_name'] ?? ''));

                if ($subdistrict === 'tanjung duren selatan'
                    && Str::contains($district, 'grogol petamburan')
                    && Str::contains($city, 'jakarta barat')
                    && isset($location['id'])) {
                    return (int) $location['id'];
                }
            }

            throw new RajaOngkirException(
                'Lokasi asal Tanjung Duren Selatan tidak ditemukan di data RajaOngkir.',
            );
        });
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function data(Response $response): array
    {
        $payload = $response->json();
        $data = is_array($payload) ? ($payload['data'] ?? null) : null;
        $meta = is_array($payload) ? ($payload['meta'] ?? []) : [];

        if (! $response->successful() || ! is_array($data)) {
            $message = is_array($meta) && is_string($meta['message'] ?? null)
                ? $meta['message']
                : 'Permintaan ke RajaOngkir gagal.';

            throw new RajaOngkirException($message);
        }

        return array_values(array_filter($data, 'is_array'));
    }

    private function apiKey(): string
    {
        $key = trim((string) config('services.rajaongkir.api_key'));

        if ($key === '') {
            throw new RajaOngkirException(
                'API key RajaOngkir belum diatur di backend/.env.',
            );
        }

        return $key;
    }

    private function url(string $path): string
    {
        return rtrim((string) config('services.rajaongkir.base_url'), '/').$path;
    }
}
