<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\CheckoutController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\ProfileController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "api" middleware group. Make something great!
|
*/

// --- Route Publik (Tidak perlu login) ---

// Route ini sudah mencakup semua fungsionalitas CRUD untuk produk
Route::apiResource('products', ProductController::class);

// Route untuk Autentikasi
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);


// --- Route Terproteksi (Wajib login) ---
Route::middleware('auth:sanctum')->group(function () {
    // Route untuk mendapatkan info user & logout
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::post('/logout', [AuthController::class, 'logout']);

    // Route untuk Keranjang Belanja
    Route::get('/cart', [CartController::class, 'index']);
    Route::post('/cart', [CartController::class, 'store']);
    Route::post('/cart/item/{productId}', [CartController::class, 'update']);
    Route::delete('/cart/item/{productId}', [CartController::class, 'destroy']);

    // Route untuk Checkout
    Route::post('/checkout', [CheckoutController::class, 'store']);
    Route::post('/checkout/now', [CheckoutController::class, 'checkoutNow']); // <-- PERBAIKAN: Route "Beli Sekarang" ditambahkan

    // Route untuk Pesanan
    Route::get('/orders', [OrderController::class, 'index']);

    // Route untuk Profil Pengguna
    Route::put('/user/profile-information', [ProfileController::class, 'updateProfile']);
    Route::put('/user/password', [ProfileController::class, 'updatePassword']);
});