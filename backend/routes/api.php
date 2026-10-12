<?php

use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\MidtransPaymentController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\ShippingController;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/payments/midtrans/notification', [MidtransPaymentController::class, 'notification']);

Route::get('/categories', [CategoryController::class, 'index']);
Route::get('/products', [ProductController::class, 'index']);
Route::get('/products/{product}', [ProductController::class, 'show']);
Route::get('/product-images/{image}', function (string $image) {
    $storagePath = 'products/'.$image;
    if (Storage::disk('public')->exists($storagePath)) {
        return Storage::disk('public')->response($storagePath);
    }

    $legacyPath = public_path('products/'.$image);
    abort_unless(is_file($legacyPath), 404);

    return response()->file($legacyPath);
})->where('image', '[A-Za-z0-9_-]+\.(?:png|jpe?g|webp)');

Route::middleware(['auth:sanctum', 'active'])->group(function (): void {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);

    Route::get('/cart', [CartController::class, 'index']);
    Route::post('/cart', [CartController::class, 'store']);
    Route::put('/cart/{cartItem}', [CartController::class, 'update']);
    Route::delete('/cart/{cartItem}', [CartController::class, 'destroy']);

    Route::get('/shipping/destinations', [ShippingController::class, 'destinations']);
    Route::get('/shipping/couriers', [ShippingController::class, 'couriers']);
    Route::post('/shipping/quotes', [ShippingController::class, 'quote']);
    Route::get('/payment-details', [PaymentController::class, 'details']);

    Route::get('/orders', [OrderController::class, 'index']);
    Route::post('/orders', [OrderController::class, 'store']);
    Route::post('/orders/{order}/midtrans-payment', [MidtransPaymentController::class, 'create']);
    Route::get('/orders/{order}/midtrans-status', [MidtransPaymentController::class, 'refreshStatus']);
    Route::get('/payments/midtrans/return-status', [MidtransPaymentController::class, 'refreshReturnStatus']);
    Route::post('/orders/{order}/payment-proof', [PaymentController::class, 'uploadProof']);
    Route::get('/orders/{order}/payment-proof', [PaymentController::class, 'showProof']);
    Route::get('/orders/{order}', [OrderController::class, 'show']);

    Route::middleware('admin')->prefix('admin')->group(function (): void {
        Route::get('/dashboard', [AdminController::class, 'dashboard']);

        Route::get('/products', [AdminController::class, 'products']);
        Route::post('/products', [AdminController::class, 'createProduct']);
        Route::get('/products/{product}', [AdminController::class, 'showProduct']);
        Route::put('/products/{product}', [AdminController::class, 'updateProduct']);
        Route::patch('/products/{product}', [AdminController::class, 'updateProduct']);
        Route::delete('/products/{product}', [AdminController::class, 'deleteProduct']);

        Route::get('/categories', [AdminController::class, 'categories']);
        Route::post('/categories', [AdminController::class, 'createCategory']);
        Route::get('/categories/{category}', [AdminController::class, 'showCategory']);
        Route::put('/categories/{category}', [AdminController::class, 'updateCategory']);
        Route::patch('/categories/{category}', [AdminController::class, 'updateCategory']);
        Route::delete('/categories/{category}', [AdminController::class, 'deleteCategory']);

        Route::get('/orders', [AdminController::class, 'orders']);
        Route::post('/orders', [AdminController::class, 'createOrder']);
        Route::get('/orders/pending-confirmation', [PaymentController::class, 'pending']);
        Route::get('/orders/{order}', [AdminController::class, 'showOrder']);
        Route::put('/orders/{order}', [AdminController::class, 'updateOrder']);
        Route::patch('/orders/{order}', [AdminController::class, 'updateOrder']);
        Route::delete('/orders/{order}', [AdminController::class, 'deleteOrder']);

        Route::get('/payments', [AdminController::class, 'payments']);
        Route::post('/orders/{order}/confirm-payment', [PaymentController::class, 'confirm']);
        Route::post('/orders/{order}/reject-payment', [PaymentController::class, 'reject']);

        Route::get('/users', [AdminController::class, 'users']);
        Route::post('/users', [AdminController::class, 'createUser']);
        Route::get('/users/{user}', [AdminController::class, 'showUser']);
        Route::put('/users/{user}', [AdminController::class, 'updateUser']);
        Route::patch('/users/{user}', [AdminController::class, 'updateUser']);
        Route::delete('/users/{user}', [AdminController::class, 'deleteUser']);
    });
});
