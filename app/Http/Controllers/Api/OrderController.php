<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class OrderController extends Controller
{
    public function index()
    {
        $user = Auth::user();

        // Ambil pesanan milik user, urutkan dari yang terbaru
        // with('items.product') adalah eager loading untuk performa yang lebih baik
        $orders = $user->orders()->with('items.product')->latest()->get();

        return response()->json($orders);
    }
}