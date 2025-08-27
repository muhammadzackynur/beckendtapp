<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Product; // <-- Import yang diperlukan untuk checkoutNow
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class CheckoutController extends Controller
{
    /**
     * Membuat pesanan dari semua item di keranjang.
     */
    public function store(Request $request)
    {
        $user = Auth::user();
        $cartItems = $user->cartItems()->with('product')->get();

        if ($cartItems->isEmpty()) {
            return response()->json(['message' => 'Keranjang Anda kosong.'], 422);
        }

        try {
            DB::beginTransaction();

            // Hitung total harga dari item keranjang
            $totalPrice = $cartItems->sum(function ($cartItem) {
                return $cartItem->quantity * $cartItem->product->price;
            });

            // 1. Buat record di tabel 'orders'
            $order = Order::create([
                'user_id' => $user->id,
                'total_price' => $totalPrice,
                'status' => 'pending',
            ]);

            // 2. Pindahkan item dari keranjang ke 'order_items'
            foreach ($cartItems as $cartItem) {
                $order->items()->create([
                    'product_id' => $cartItem->product_id,
                    'quantity' => $cartItem->quantity,
                    'price' => $cartItem->product->price,
                ]);
            }

            // 3. Kosongkan keranjang pengguna
            $user->cartItems()->delete();

            DB::commit();

            return response()->json(['message' => 'Pesanan berhasil dibuat!'], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Terjadi kesalahan saat checkout.', 'error' => $e->getMessage()], 500);
        }
    }

    /**
     * Membuat pesanan untuk satu item secara langsung (Beli Sekarang).
     */
    public function checkoutNow(Request $request)
    {
        $request->validate([
            'product_id' => 'required|exists:products,id',
            'quantity' => 'required|integer|min:1',
        ]);

        $user = Auth::user();
        $product = Product::findOrFail($request->product_id);

        try {
            DB::beginTransaction();

            $totalPrice = $product->price * $request->quantity;

            // 1. Buat record di tabel 'orders'
            $order = Order::create([
                'user_id' => $user->id,
                'total_price' => $totalPrice,
                'status' => 'pending',
            ]);

            // 2. Buat record di tabel 'order_items'
            $order->items()->create([
                'product_id' => $product->id,
                'quantity' => $request->quantity,
                'price' => $product->price,
            ]);

            DB::commit();

            return response()->json(['message' => 'Pesanan berhasil dibuat!'], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Terjadi kesalahan saat checkout.', 'error' => $e->getMessage()], 500);
        }
    }
}