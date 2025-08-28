@extends('layouts.app')

@section('content')
    <div class="row">
        <div class="col-lg-12">
            <div class="d-flex justify-content-between align-items-center mb-4">
                <h2>Manajemen Produk</h2>
                <a class="btn btn-success" href="{{ route('products.create') }}"> Tambah Produk Baru</a>
            </div>
        </div>
    </div>

    @if ($message = Session::get('success'))
        <div class="alert alert-success">
            <p>{{ $message }}</p>
        </div>
    @endif

    <table class="table table-bordered table-striped">
        <thead class="table-dark">
            <tr>
                <th scope="col">No</th>
                <th scope="col">Gambar</th>
                <th scope="col">Nama</th>
                <th scope="col">Deskripsi</th>
                <th scope="col">Harga</th>
                <th scope="col">Kategori</th>
                <th scope="col">Warna</th>
                <th scope="col">Penyimpanan</th>
                <th scope="col" width="180px">Aksi</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($products as $product)
            <tr>
                <td>{{ $loop->iteration }}</td>
                
                {{-- === BAGIAN YANG DIPERBAIKI === --}}
                <td>
                    @if($product->images->isNotEmpty())
                        <img src="{{ asset('storage/' . $product->images->first()->image) }}" alt="{{ $product->name }}" class="img-thumbnail" width="100">
                    @else
                        <span class="text-muted">No Image</span>
                    @endif
                </td>
                {{-- ============================== --}}
                
                <td>{{ $product->name }}</td>
                <td>{{ Str::limit($product->description, 50) }}</td>
                <td>Rp {{ number_format($product->price, 0, ',', '.') }}</td>
                <td><span class="badge bg-primary">{{ $product->category }}</span></td>
                <td>
                    @if(is_array($product->warna))
                        @foreach($product->warna as $item_warna)
                            <span class="badge bg-secondary mb-1">{{ $item_warna }}</span>
                        @endforeach
                    @else
                        <span class="badge bg-secondary mb-1">{{ $product->warna ?? '-' }}</span>
                    @endif
                </td>
                <td>
                    @if(is_array($product->penyimpanan))
                        @foreach($product->penyimpanan as $item_penyimpanan)
                            <span class="badge bg-dark mb-1">{{ $item_penyimpanan }}</span>
                        @endforeach
                    @else
                        <span class="badge bg-dark mb-1">{{ $product->penyimpanan ?? '-' }}</span>
                    @endif
                </td>
                <td>
                    <form action="{{ route('products.destroy', $product->id) }}" method="POST">
                        <a class="btn btn-primary btn-sm" href="{{ route('products.edit', $product->id) }}">Edit</a>
                        @csrf
                        @method('DELETE')
                        <button type="submit" class="btn btn-danger btn-sm" onclick="return confirm('Apakah Anda yakin ingin menghapus produk ini?')">Hapus</button>
                    </form>
                </td>
            </tr>
            @endforeach
        </tbody>
    </table>
@endsection