@extends('layouts.app')

@section('content')
    <h2>Tambah Produk Baru</h2>
    <a class="btn btn-primary mb-3" href="{{ route('products.index') }}"> Kembali</a>

    <form action="{{ route('products.store') }}" method="POST" enctype="multipart/form-data">
        @csrf
        <div class="mb-3">
            <label for="name" class="form-label"><strong>Nama:</strong></label>
            <input type="text" name="name" class="form-control" placeholder="Nama Produk">
        </div>
        <div class="mb-3">
            <label for="description" class="form-label"><strong>Deskripsi:</strong></label>
            <textarea class="form-control" style="height:150px" name="description" placeholder="Deskripsi"></textarea>
        </div>
        <div class="mb-3">
            <label for="price" class="form-label"><strong>Harga:</strong></label>
            <input type="number" step="0.01" name="price" class="form-control" placeholder="Harga">
        </div>
        
        <div class="mb-3">
            <label for="category" class="form-label"><strong>Kategori:</strong></label>
            <select name="category" class="form-select">
                <option selected disabled>Pilih Kategori</option>
                <option value="Laptop">Laptop</option>
                <option value="Smartphone">Smartphone</option>
                <option value="Jam">Jam</option>
            </select>
        </div>
        <div class="mb-3">
            <label for="image" class="form-label"><strong>Gambar Produk:</strong></label>
            <input type="file" name="image" class="form-control">
        </div>
        <div class="text-center">
            <button type="submit" class="btn btn-success">Simpan</button>
        </div>
    </form>
@endsection