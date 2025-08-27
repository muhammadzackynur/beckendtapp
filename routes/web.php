<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ProductController; // Pastikan ini diarahkan ke controller baru

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
*/

// Arahkan halaman utama langsung ke daftar produk
Route::get('/', function () {
    return redirect()->route('products.index');
});

// Route ini secara otomatis membuat semua URL untuk CRUD produk
Route::resource('products', ProductController::class);