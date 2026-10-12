<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AdminController extends Controller
{
    public function dashboard(): JsonResponse
    {
        $paidOrders = Order::query()->where('payment_status', 'paid')->where('status', '!=', 'cancelled');
        $today = now()->startOfDay();
        $dailyOrders = (clone $paidOrders)->where('created_at', '>=', $today->copy()->subDays(6))->get(['total', 'created_at']);
        $monthlyOrders = (clone $paidOrders)->where('created_at', '>=', now()->startOfMonth()->subMonths(11))->get(['total', 'created_at']);

        $daily = collect(range(6, 0))->map(function (int $days) use ($dailyOrders): array {
            $date = now()->startOfDay()->subDays($days);

            return [
                'date' => $date->toDateString(),
                'sales' => (float) $dailyOrders->filter(fn (Order $order): bool => $order->created_at->isSameDay($date))->sum('total'),
            ];
        })->values();

        $monthly = collect(range(11, 0))->map(function (int $months) use ($monthlyOrders): array {
            $month = now()->startOfMonth()->subMonths($months);

            return [
                'month' => $month->format('Y-m'),
                'sales' => (float) $monthlyOrders->filter(fn (Order $order): bool => $order->created_at->format('Y-m') === $month->format('Y-m'))->sum('total'),
            ];
        })->values();

        return response()->json([
            'data' => [
                'stats' => [
                    'sales_total' => (float) (clone $paidOrders)->sum('total'),
                    'orders_count' => Order::query()->count(),
                    'pending_payments_count' => Order::query()->whereIn('payment_status', ['pending', 'proof_submitted', 'rejected'])->count(),
                    'users_count' => User::query()->where('role', 'customer')->count(),
                    'low_stock_count' => Product::query()->where('is_active', true)->where('stock', '<=', 5)->count(),
                ],
                'sales' => $daily->map(fn (array $row): array => [
                    'label' => $row['date'],
                    'total' => $row['sales'],
                ]),
                'recent_orders' => Order::query()->with('user:id,name,email')->latest('id')->limit(10)->get()
                    ->map(fn (Order $order): array => $this->orderData($order)),
                'monthly_sales' => $monthly,
            ],
        ]);
    }

    public function products(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['sometimes', 'string', 'max:120'],
            'category_id' => ['sometimes', 'integer', 'exists:categories,id'],
            'status' => ['sometimes', Rule::in(['active', 'inactive'])],
            'sort' => ['sometimes', Rule::in(['latest', 'oldest', 'name_asc', 'name_desc', 'price_asc', 'price_desc', 'stock_asc', 'stock_desc'])],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
        $query = Product::query()->with('category:id,name')
            ->when(isset($filters['search']), function (Builder $query) use ($filters): void {
                $term = '%'.mb_strtolower($filters['search']).'%';
                $query->where(fn (Builder $q) => $q->whereRaw('LOWER(name) LIKE ?', [$term])
                    ->orWhereRaw("LOWER(COALESCE(brand, '')) LIKE ?", [$term]));
            })
            ->when(isset($filters['category_id']), fn (Builder $q) => $q->where('category_id', $filters['category_id']))
            ->when(isset($filters['status']), fn (Builder $q) => $q->where('is_active', $filters['status'] === 'active'));

        $sorts = [
            'oldest' => ['id', 'asc'], 'name_asc' => ['name', 'asc'], 'name_desc' => ['name', 'desc'],
            'price_asc' => ['price', 'asc'], 'price_desc' => ['price', 'desc'],
            'stock_asc' => ['stock', 'asc'], 'stock_desc' => ['stock', 'desc'], 'latest' => ['id', 'desc'],
        ];
        [$column, $direction] = $sorts[$filters['sort'] ?? 'latest'];

        return $this->paginatedResponse($query->orderBy($column, $direction)->paginate($filters['per_page'] ?? 20));
    }

    public function showProduct(Product $product): JsonResponse
    {
        return response()->json(['data' => $product->load('category:id,name')]);
    }

    public function createProduct(Request $request): JsonResponse
    {
        $data = $this->productInput($request);
        $image = $data['image'] ?? null;
        unset($data['image']);

        if ($image !== null) {
            $data['image_url'] = $this->storeProductImage($image);
        }

        try {
            $product = Product::create($data);
        } catch (\Throwable $exception) {
            if ($image !== null) {
                $this->deleteManagedProductImage($data['image_url']);
            }
            throw $exception;
        }

        return response()->json(['data' => $product->load('category:id,name')], 201);
    }

    public function updateProduct(Request $request, Product $product): JsonResponse
    {
        $data = $this->productInput($request, true);
        $image = $data['image'] ?? null;
        unset($data['image']);
        $previousImageUrl = $product->image_url;

        if ($image !== null) {
            $data['image_url'] = $this->storeProductImage($image);
        }

        try {
            $product->update($data);
        } catch (\Throwable $exception) {
            if ($image !== null) {
                $this->deleteManagedProductImage($data['image_url']);
            }
            throw $exception;
        }

        if ($previousImageUrl !== $product->image_url) {
            $this->deleteManagedProductImage($previousImageUrl);
        }

        return response()->json(['data' => $product->fresh('category:id,name')]);
    }

    public function deleteProduct(Product $product): JsonResponse
    {
        if ($product->orderItems()->exists()) {
            $product->update(['is_active' => false]);
            $product->delete();
            $message = 'Produk telah dinonaktifkan karena sudah tercatat dalam pesanan.';
        } else {
            $product->cartItems()->delete();
            $imageUrl = $product->image_url;
            $product->forceDelete();
            $this->deleteManagedProductImage($imageUrl);
            $message = 'Produk berhasil dihapus.';
        }

        return response()->json(['message' => $message]);
    }

    public function categories(): JsonResponse
    {
        return $this->paginatedResponse(Category::query()->withCount('products')->orderBy('name')->paginate(50));
    }

    public function showCategory(Category $category): JsonResponse
    {
        return response()->json(['data' => $category->loadCount('products')]);
    }

    public function createCategory(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:categories,name'],
            'slug' => ['sometimes', 'nullable', 'string', 'max:255', 'unique:categories,slug'],
        ], ['name.unique' => 'Nama kategori sudah digunakan.', 'slug.unique' => 'Slug kategori sudah digunakan.']);
        $slug = $data['slug'] ?: Str::slug($data['name']);
        if (Category::query()->where('slug', $slug)->exists()) {
            throw ValidationException::withMessages(['slug' => ['Slug kategori sudah digunakan.']]);
        }
        $category = Category::create([
            'name' => $data['name'],
            'slug' => $slug,
        ]);

        return response()->json(['data' => $category], 201);
    }

    public function updateCategory(Request $request, Category $category): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255', Rule::unique('categories', 'name')->ignore($category->id)],
            'slug' => ['sometimes', 'nullable', 'string', 'max:255', Rule::unique('categories', 'slug')->ignore($category->id)],
        ]);
        if (array_key_exists('name', $data) && ! array_key_exists('slug', $data)) {
            $data['slug'] = Str::slug($data['name']);
        }
        if (array_key_exists('slug', $data) && $data['slug'] === null) {
            $data['slug'] = Str::slug($data['name'] ?? $category->name);
        }
        if (isset($data['slug']) && Category::query()->where('slug', $data['slug'])->where('id', '!=', $category->id)->exists()) {
            throw ValidationException::withMessages(['slug' => ['Slug kategori sudah digunakan.']]);
        }
        $category->update($data);

        return response()->json(['data' => $category->fresh()]);
    }

    public function deleteCategory(Category $category): JsonResponse
    {
        if ($category->products()->exists()) {
            throw ValidationException::withMessages(['category' => ['Kategori tidak dapat dihapus selama masih memiliki produk.']]);
        }
        $category->delete();

        return response()->json(['message' => 'Kategori berhasil dihapus.']);
    }

    public function orders(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['sometimes', 'string', 'max:120'],
            'status' => ['sometimes', 'string', 'max:40'],
            'payment_status' => ['sometimes', 'string', 'max:40'],
            'from' => ['sometimes', 'date'],
            'to' => ['sometimes', 'date', 'after_or_equal:from'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
        $query = Order::query()->with(['user:id,name,email,phone', 'items'])
            ->when(isset($filters['search']), function (Builder $query) use ($filters): void {
                $term = '%'.mb_strtolower($filters['search']).'%';
                $query->where(fn (Builder $q) => $q->whereRaw('LOWER(code) LIKE ?', [$term])
                    ->orWhereHas('user', fn (Builder $u) => $u->whereRaw('LOWER(name) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(email) LIKE ?', [$term])));
            })
            ->when(isset($filters['status']), fn (Builder $q) => $q->where('status', $filters['status']))
            ->when(isset($filters['payment_status']), fn (Builder $q) => $q->where('payment_status', $filters['payment_status']))
            ->when(isset($filters['from']), fn (Builder $q) => $q->whereDate('created_at', '>=', $filters['from']))
            ->when(isset($filters['to']), fn (Builder $q) => $q->whereDate('created_at', '<=', $filters['to']));

        return $this->paginatedResponse($query->latest('id')->paginate($filters['per_page'] ?? 20)->through(
            fn (Order $order): array => $this->orderData($order),
        ));
    }

    public function showOrder(Order $order): JsonResponse
    {
        return response()->json(['data' => $this->orderData($order->load(['user:id,name,email,phone', 'items']))]);
    }

    public function updateOrder(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'status' => ['sometimes', Rule::in(['pending_payment', 'processing', 'shipped', 'delivered', 'cancelled'])],
            'tracking_number' => ['sometimes', 'nullable', 'string', 'max:255'],
            'admin_notes' => ['sometimes', 'nullable', 'string', 'max:5000'],
        ], ['status.in' => 'Status pesanan tidak valid.']);

        $updated = DB::transaction(function () use ($data, $order): Order {
            $locked = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();
            if ($locked->status === 'cancelled' && ($data['status'] ?? null) !== 'cancelled') {
                throw ValidationException::withMessages(['status' => ['Pesanan yang dibatalkan tidak dapat diaktifkan kembali.']]);
            }
            if (($data['status'] ?? null) === 'cancelled' && $locked->status !== 'cancelled') {
                if (in_array($locked->status, ['shipped', 'delivered'], true)) {
                    throw ValidationException::withMessages(['status' => ['Pesanan yang telah dikirim tidak dapat dibatalkan melalui panel admin.']]);
                }
                $this->restoreOrderStock($locked);
                $data['payment_status'] = 'cancelled';
            }
            $locked->update($data);

            return $locked->fresh(['user:id,name,email,phone', 'items']);
        });

        return response()->json(['data' => $this->orderData($updated)]);
    }

    public function createOrder(Request $request): JsonResponse
    {
        $data = $request->validate([
            'user_id' => ['required', 'integer', 'exists:users,id'],
            'recipient_name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:30'],
            'address' => ['required', 'string', 'min:10', 'max:2000'],
            'payment_method' => ['required', Rule::in(['bank_transfer', 'cod', 'ewallet'])],
            'payment_status' => ['sometimes', Rule::in(['pending', 'paid'])],
            'shipping_cost' => ['sometimes', 'numeric', 'min:0'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'integer', 'distinct', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:10000'],
        ]);

        $order = DB::transaction(function () use ($data): Order {
            $user = User::query()->whereKey($data['user_id'])->lockForUpdate()->firstOrFail();
            if (! $user->is_active) {
                throw ValidationException::withMessages(['user_id' => ['Pengguna tidak aktif.']]);
            }
            $items = collect($data['items'])->sortBy('product_id');
            $products = [];
            $subtotalCents = 0;
            foreach ($items as $item) {
                $product = Product::query()->whereKey($item['product_id'])->lockForUpdate()->firstOrFail();
                if (! $product->is_active || $product->stock < $item['quantity']) {
                    throw ValidationException::withMessages(['items' => ["Stok {$product->name} tidak mencukupi atau produk tidak aktif."]]);
                }
                $products[$product->id] = $product;
                $subtotalCents += (int) round((float) $product->price * 100) * $item['quantity'];
            }
            $shippingCents = (int) round((float) ($data['shipping_cost'] ?? 0) * 100);
            $uniqueCode = $data['payment_method'] === 'bank_transfer' ? random_int(1, 999) : 0;
            $paid = ($data['payment_status'] ?? 'pending') === 'paid';
            $order = Order::create([
                'user_id' => $user->id,
                'code' => 'KEL-'.$user->id.'-'.now()->format('ymdHis').'-'.Str::upper(Str::random(5)),
                'recipient_name' => $data['recipient_name'],
                'phone' => $data['phone'],
                'address' => $data['address'],
                'payment_method' => $data['payment_method'],
                'payment_status' => $paid ? 'paid' : 'pending',
                'payment_confirmed_at' => $paid ? now() : null,
                'status' => $paid ? 'processing' : 'pending_payment',
                'payment_unique_code' => $uniqueCode,
                'subtotal' => $subtotalCents / 100,
                'shipping_cost' => $shippingCents / 100,
                'total' => ($subtotalCents + $shippingCents + $uniqueCode * 100) / 100,
            ]);
            foreach ($items as $item) {
                $product = $products[$item['product_id']];
                $order->items()->create([
                    'product_id' => $product->id, 'product_name' => $product->name,
                    'quantity' => $item['quantity'], 'price' => $product->price,
                ]);
                $product->decrement('stock', $item['quantity']);
            }

            return $order->load(['user:id,name,email,phone', 'items']);
        });

        return response()->json(['data' => $this->orderData($order)], 201);
    }

    public function deleteOrder(Order $order): JsonResponse
    {
        $proofPath = DB::transaction(function () use ($order): ?string {
            $locked = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();
            if (! in_array($locked->status, ['cancelled', 'shipped', 'delivered'], true)) {
                $this->restoreOrderStock($locked);
            }
            $path = $locked->payment_proof_path;
            $locked->delete();

            return $path;
        });
        if ($proofPath !== null) {
            Storage::disk('local')->delete($proofPath);
        }

        return response()->json(['message' => 'Pesanan berhasil dihapus dan stok dipulihkan bila diperlukan.']);
    }

    public function payments(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'status' => ['sometimes', 'string', 'max:40'],
            'from' => ['sometimes', 'date'],
            'to' => ['sometimes', 'date', 'after_or_equal:from'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
        $query = Order::query()->with(['user:id,name,email,phone', 'items'])
            ->where('payment_method', 'bank_transfer')
            ->when(isset($filters['status']), fn (Builder $q) => $q->where('payment_status', $filters['status']))
            ->when(isset($filters['from']), fn (Builder $q) => $q->whereDate('created_at', '>=', $filters['from']))
            ->when(isset($filters['to']), fn (Builder $q) => $q->whereDate('created_at', '<=', $filters['to']));

        return $this->paginatedResponse($query->latest('id')->paginate($filters['per_page'] ?? 20)->through(
            fn (Order $order): array => $this->orderData($order),
        ));
    }

    public function users(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['sometimes', 'string', 'max:120'],
            'role' => ['sometimes', Rule::in(['admin', 'customer'])],
            'status' => ['sometimes', Rule::in(['active', 'inactive'])],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
        $query = User::query()->withCount('orders')
            ->when(isset($filters['search']), function (Builder $q) use ($filters): void {
                $term = '%'.mb_strtolower($filters['search']).'%';
                $q->where(fn (Builder $u) => $u->whereRaw('LOWER(name) LIKE ?', [$term])
                    ->orWhereRaw('LOWER(email) LIKE ?', [$term])->orWhereRaw("LOWER(COALESCE(phone, '')) LIKE ?", [$term]));
            })
            ->when(isset($filters['role']), fn (Builder $q) => $q->where('role', $filters['role']))
            ->when(isset($filters['status']), fn (Builder $q) => $q->where('is_active', $filters['status'] === 'active'));

        return $this->paginatedResponse($query->latest('id')->paginate($filters['per_page'] ?? 20));
    }

    public function showUser(User $user): JsonResponse
    {
        return response()->json(['data' => $user->load(['orders' => fn (Builder $q) => $q->latest('id')])]);
    }

    public function createUser(Request $request): JsonResponse
    {
        $data = $this->userInput($request);
        $data['password'] = Hash::make($data['password']);
        $user = User::create($data);

        return response()->json(['data' => $user], 201);
    }

    public function updateUser(Request $request, User $user): JsonResponse
    {
        $data = $this->userInput($request, $user);
        if (isset($data['password'])) {
            $data['password'] = Hash::make($data['password']);
        }
        $user->update($data);

        return response()->json(['data' => $user->fresh()]);
    }

    public function deleteUser(Request $request, User $user): JsonResponse
    {
        if ($request->user()->is($user)) {
            throw ValidationException::withMessages(['user' => ['Anda tidak dapat menghapus akun sendiri.']]);
        }
        if ($user->orders()->exists()) {
            return response()->json(['message' => 'Pengguna memiliki riwayat pesanan dan tidak dapat dihapus.'], 409);
        }
        $user->cartItems()->delete();
        $user->tokens()->delete();
        $user->delete();

        return response()->json(['message' => 'Pengguna berhasil dihapus.']);
    }

    /** @return array<string, mixed> */
    private function productInput(Request $request, bool $partial = false): array
    {
        $required = $partial ? ['sometimes', 'required'] : ['required'];

        return $request->validate([
            'category_id' => [...$required, 'integer', 'exists:categories,id'],
            'name' => [...$required, 'string', 'max:255'],
            'brand' => ['sometimes', 'nullable', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string', 'max:10000'],
            'price' => [...$required, 'numeric', 'min:0', 'max:9999999999.99'],
            'weight' => ['sometimes', 'numeric', 'min:0', 'max:99999999'],
            'stock' => [...$required, 'integer', 'min:0'],
            'image_url' => ['sometimes', 'nullable', 'string', 'max:2048'],
            'image' => ['sometimes', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'is_active' => ['sometimes', 'boolean'],
        ], [
            'category_id.exists' => 'Kategori tidak ditemukan.',
            'stock.min' => 'Stok tidak boleh negatif.',
            'price.min' => 'Harga tidak boleh negatif.',
        ]);
    }

    /** @return array<string, mixed> */
    private function userInput(Request $request, ?User $user = null): array
    {
        $required = $user === null ? 'required' : 'sometimes|required';

        return $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'email' => [$required, 'email', 'max:255', Rule::unique('users', 'email')->ignore($user?->id)],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
            'role' => ['sometimes', Rule::in(['admin', 'customer'])],
            'password' => [$user === null ? 'required' : 'sometimes', 'string', 'min:8'],
            'is_active' => ['sometimes', 'boolean'],
        ], ['password.min' => 'Kata sandi minimal 8 karakter.']);
    }

    private function restoreOrderStock(Order $order): void
    {
        $items = $order->items()->orderBy('product_id')->get();
        foreach ($items as $item) {
            if ($item->product_id === null) {
                continue;
            }
            $product = Product::withTrashed()->whereKey($item->product_id)->lockForUpdate()->first();
            $product?->increment('stock', $item->quantity);
        }
    }

    private function storeProductImage(UploadedFile $image): string
    {
        $extension = match ($image->getMimeType()) {
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'image/webp' => 'webp',
            default => throw ValidationException::withMessages([
                'image' => ['Format gambar harus JPG, JPEG, PNG, atau WEBP.'],
            ]),
        };
        $filename = Str::uuid().'.'.$extension;
        $storedPath = $image->storeAs('products', $filename, 'public');
        if ($storedPath === false) {
            throw ValidationException::withMessages(['image' => ['Gambar produk gagal disimpan.']]);
        }

        return url('/api/product-images/'.$filename);
    }

    private function deleteManagedProductImage(?string $imageUrl): void
    {
        if ($imageUrl === null) {
            return;
        }

        $path = parse_url($imageUrl, PHP_URL_PATH);
        if (! is_string($path)
            || preg_match('#/api/product-images/([a-f0-9-]{36}\.(?:jpg|jpeg|png|webp))$#i', $path, $matches) !== 1) {
            return;
        }

        Storage::disk('public')->delete('products/'.$matches[1]);
    }

    private function paginatedResponse(LengthAwarePaginator $paginator): JsonResponse
    {
        return response()->json([
            'data' => $paginator->items(),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
                'from' => $paginator->firstItem(),
                'to' => $paginator->lastItem(),
            ],
        ]);
    }

    /** @return array<string, mixed> */
    private function orderData(Order $order): array
    {
        return [
            'id' => $order->id,
            'code' => $order->code,
            'user' => $order->user === null ? null : [
                'id' => $order->user->id, 'name' => $order->user->name,
                'email' => $order->user->email, 'phone' => $order->user->phone,
            ],
            'status' => $order->status,
            'payment_method' => $order->payment_method,
            'payment_status' => $order->payment_status,
            'recipient_name' => $order->recipient_name,
            'phone' => $order->phone,
            'address' => $order->address,
            'tracking_number' => $order->tracking_number,
            'admin_notes' => $order->admin_notes,
            'subtotal' => $order->subtotal,
            'shipping_cost' => $order->shipping_cost,
            'total' => $order->total,
            'payment_proof_uploaded_at' => $order->payment_proof_uploaded_at?->toISOString(),
            'payment_proof_url' => $order->payment_proof_path === null ? null : url('/api/orders/'.$order->id.'/payment-proof'),
            'created_at' => $order->created_at?->toISOString(),
            'items' => $order->items->map(fn ($item): array => [
                'product_id' => $item->product_id, 'product_name' => $item->product_name,
                'quantity' => $item->quantity, 'price' => $item->price,
            ]),
        ];
    }
}
