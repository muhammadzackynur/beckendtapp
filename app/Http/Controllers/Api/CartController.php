<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CartItem;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class CartController extends Controller
{
    /**
     * Mengambil semua item di keranjang pengguna beserta gambar produk.
     */
    public function index()
    {
        // --- PERBAIKAN DI SINI ---
        // Menggunakan nested eager loading untuk memuat produk DAN gambar di dalamnya.
        $cartItems = CartItem::with('product.images') 
                              ->where('user_id', Auth::id())
                              ->get();

        return response()->json($cartItems);
    }

    /**
     * Menambah item ke keranjang.
     */
    public function store(Request $request)
    {
        $request->validate([
            'product_id' => 'required|exists:products,id',
            'quantity' => 'required|integer|min:1'
        ]);

        $cartItem = CartItem::where('user_id', Auth::id())
                            ->where('product_id', $request->product_id)
                            ->first();

        if ($cartItem) {
            // Jika item sudah ada, update kuantitasnya
            $cartItem->quantity += $request->quantity;
            $cartItem->save();
        } else {
            // Jika item baru, buat entri baru
            $cartItem = CartItem::create([
                'user_id' => Auth::id(),
                'product_id' => $request->product_id,
                'quantity' => $request->quantity
            ]);
        }

        // PERBAIKAN: Muat juga relasi gambar saat item ditambahkan
        return response()->json($cartItem->load('product.images'), 201);
    }
    
    /**
     * Mengupdate kuantitas item.
     */
    public function update(Request $request, $productId)
    {
        $request->validate([
            'quantity' => 'required|integer|min:1'
        ]);

        $cartItem = CartItem::where('user_id', Auth::id())
                            ->where('product_id', $productId)
                            ->firstOrFail();

        $cartItem->update(['quantity' => $request->quantity]);

        // PERBAIKAN: Muat juga relasi gambar saat item diupdate
        return response()->json($cartItem->load('product.images'));
    }

    /**
     * Menghapus item dari keranjang.
     */
    public function destroy($productId)
    {
        CartItem::where('user_id', Auth::id())
                ->where('product_id', $productId)
                ->delete();

        return response()->json(['message' => 'Item berhasil dihapus dari keranjang.']);
    }
}