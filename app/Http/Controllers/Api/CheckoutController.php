<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;

class CheckoutController extends Controller
{
    /**
     * Checkout dari keranjang belanja.
     * Bisa memproses semua item, atau hanya item yang dipilih.
     */
    public function store(Request $request)
    {
        // Validasi input, pastikan 'product_ids' adalah array jika ada
        $request->validate([
            'product_ids' => 'sometimes|array',
            'product_ids.*' => 'integer|exists:products,id'
        ]);

        $user = Auth::user();
        $cartItemsQuery = $user->cartItems()->with('product.images');

        // --- PERBAIKAN 1: Logika untuk checkout selektif ---
        // Jika ada 'product_ids' dalam request, filter keranjang berdasarkan ID tersebut.
        // Jika tidak ada, proses semua item di keranjang.
        if ($request->has('product_ids') && !empty($request->product_ids)) {
            $cartItemsQuery->whereIn('product_id', $request->product_ids);
        }

        $cartItems = $cartItemsQuery->get();

        if ($cartItems->isEmpty()) {
            return response()->json(['message' => 'Tidak ada item yang dipilih untuk checkout.'], 400);
        }

        $totalPrice = $cartItems->sum(function ($item) {
            return $item->quantity * $item->product->price;
        });

        $order = Order::create([
            'user_id' => $user->id,
            'total_price' => $totalPrice,
            'status' => 'Pending',
        ]);

        foreach ($cartItems as $item) {
            $order->items()->create([
                'product_id' => $item->product_id,
                'quantity' => $item->quantity,
                'price' => $item->product->price,
            ]);
        }

        // Hapus hanya item yang sudah di-checkout dari keranjang
        $productIdsToDelete = $cartItems->pluck('product_id');
        $user->cartItems()->whereIn('product_id', $productIdsToDelete)->delete();

        // PERBAIKAN 2: Muat juga relasi gambar agar data konsisten
        return response()->json($order->load('items.product.images'), 201);
    }

    /**
     * Checkout untuk "Beli Sekarang" satu produk.
     */
    public function checkoutNow(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'product_id' => 'required|exists:products,id',
            'quantity' => 'required|integer|min:1',
        ]);

        if ($validator->fails()) {
            return response()->json($validator->errors(), 422);
        }

        $user = Auth::user();
        $product = Product::find($request->product_id);
        $quantity = $request->quantity;

        $totalPrice = $product->price * $quantity;

        $order = Order::create([
            'user_id' => $user->id,
            'total_price' => $totalPrice,
            'status' => 'Pending',
        ]);

        $order->items()->create([
            'product_id' => $product->id,
            'quantity' => $quantity,
            'price' => $product->price,
        ]);

        // PERBAIKAN 2: Muat juga relasi gambar agar data konsisten
        return response()->json($order->load('items.product.images'), 201);
    }
}