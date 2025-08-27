<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Product;

class ProductSeeder extends Seeder
{
    public function run(): void
    {
        Product::create([
            'name' => 'Laptop Pro 15"',
            'description' => 'Laptop canggih untuk para profesional kreatif.',
            'price' => 25000000.00,
            'image' => 'https://via.placeholder.com/150/0000FF/808080?Text=Laptop' // <-- UBAH DI SINI
        ]);

        Product::create([
            'name' => 'Smartphone Flagship',
            'description' => 'Kamera terbaik di kelasnya dengan performa super cepat.',
            'price' => 15000000.00,
            'image' => 'https://via.placeholder.com/150/FF0000/FFFFFF?Text=Phone' // <-- UBAH DI SINI
        ]);

        Product::create([
            'name' => 'Wireless Headphones',
            'description' => 'Nikmati musik tanpa batas dengan noise cancelling.',
            'price' => 3500000.00,
            'image' => 'https://via.placeholder.com/150/00FF00/000000?Text=Headphones' // <-- UBAH DI SINI
        ]);

         Product::create([
            'name' => 'Smartwatch 2 Pro',
            'description' => 'Pantau kesehatan dan notifikasi langsung dari pergelangan tangan.',
            'price' => 4250000.00,
            'image' => 'https://via.placeholder.com/150/FFA500/FFFFFF?Text=Watch' // <-- UBAH DI SINI
        ]);
    }
}