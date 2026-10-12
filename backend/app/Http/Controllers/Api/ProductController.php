<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class ProductController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'category_id' => ['sometimes', 'integer', 'exists:categories,id'],
            'search' => ['sometimes', 'string', 'max:120'],
            'min_price' => ['sometimes', 'numeric', 'min:0'],
            'max_price' => ['sometimes', 'numeric', 'min:0'],
            'sort' => ['sometimes', 'in:latest,best_selling,price_asc,price_desc'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:50'],
        ]);

        if (isset($filters['min_price'], $filters['max_price'])
            && $filters['min_price'] > $filters['max_price']) {
            throw ValidationException::withMessages([
                'min_price' => ['Harga minimum tidak boleh melebihi harga maksimum.'],
            ]);
        }

        $products = Product::query()
            ->with('category:id,name')
            ->where('is_active', true)
            ->when(isset($filters['category_id']), fn (Builder $query) => $query->where('category_id', $filters['category_id']))
            ->when(isset($filters['search']), function (Builder $query) use ($filters): void {
                $search = $filters['search'];
                $query->where(function (Builder $query) use ($search): void {
                    $term = '%'.mb_strtolower($search).'%';
                    $query->whereRaw('LOWER(name) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(brand, \'\')) LIKE ?', [$term])
                        ->orWhereHas('category', fn (Builder $category) => $category->whereRaw('LOWER(name) LIKE ?', [$term]));
                });
            })
            ->when(isset($filters['min_price']), fn (Builder $query) => $query->where('price', '>=', $filters['min_price']))
            ->when(isset($filters['max_price']), fn (Builder $query) => $query->where('price', '<=', $filters['max_price']));

        match ($filters['sort'] ?? 'latest') {
            'best_selling' => $products->withSum('orderItems as sold_quantity', 'quantity')
                ->orderByDesc('sold_quantity')->orderByDesc('id'),
            'price_asc' => $products->orderBy('price')->orderByDesc('id'),
            'price_desc' => $products->orderByDesc('price')->orderByDesc('id'),
            default => $products->latest('id'),
        };

        return response()->json([
            'data' => $products->limit((int) ($filters['per_page'] ?? 20))->get()
                ->map(fn (Product $product): array => $this->productData($product)),
        ]);
    }

    public function show(Product $product): JsonResponse
    {
        abort_unless($product->is_active, 404);

        return response()->json([
            'data' => $this->productData($product->load('category:id,name')),
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    public function productData(Product $product): array
    {
        return [
            'id' => $product->id,
            'name' => $product->name,
            'brand' => $product->brand,
            'description' => $product->description,
            'price' => $product->price,
            'weight' => $product->weight,
            'stock' => $product->stock,
            'image_url' => $product->image_url,
            'category' => $product->category === null ? null : [
                'id' => $product->category->id,
                'name' => $product->category->name,
            ],
        ];
    }
}
