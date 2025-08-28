import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- KONFIGURASI ---
const String host = kIsWeb ? '127.0.0.1' : '10.0.2.2';
const String baseUrl = 'http://$host:8000';

// --- MODEL-MODEL DATA ---

class User {
  final int id;
  final String name;
  final String email;
  final String? profilePhotoUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePhotoUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String? photoUrl;
    if (json['profile_photo_path'] != null) {
      photoUrl = '$baseUrl/storage/${json['profile_photo_path']}';
    }

    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      profilePhotoUrl: photoUrl,
    );
  }
}

class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String? category;
  final String? imageUrl;
  final List<String> warna;
  final List<String> penyimpanan;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.category,
    this.imageUrl,
    required this.warna,
    required this.penyimpanan,
  });

  // --- PERBAIKAN DI SINI ---
  factory Product.fromJson(Map<String, dynamic> json) {
    // Fungsi bantuan untuk mem-parsing data yang bisa berupa String atau List
    List<String> _parseOptions(dynamic data) {
      if (data == null) {
        return []; // Kembalikan list kosong jika data null
      }
      if (data is String) {
        // Jika data adalah String, pisahkan berdasarkan baris baru
        // dan hapus spasi kosong di awal/akhir setiap item.
        return data.split('\n').map((item) => item.trim()).toList();
      }
      if (data is List) {
        // Jika sudah berupa List, pastikan semua elemen adalah String
        return data.map((item) => item.toString()).toList();
      }
      return []; // Kembalikan list kosong untuk tipe data lain
    }

    return Product(
      id: json['id'],
      name: json['name'] ?? 'No Name',
      description: json['description'] ?? 'No Description',
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      category: json['category'],
      imageUrl: json['image'] != null
          ? '$baseUrl/storage/${json['image']}'
          : null,
      warna: _parseOptions(json['warna']), // Gunakan fungsi bantuan
      penyimpanan: _parseOptions(json['penyimpanan']), // Gunakan fungsi bantuan
    );
  }
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}

class OrderItem {
  final int id;
  final int quantity;
  final double price;
  final Product? product;

  OrderItem({
    required this.id,
    required this.quantity,
    required this.price,
    required this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      quantity: json['quantity'],
      price: double.parse(json['price'].toString()),
      product: json['product'] != null
          ? Product.fromJson(json['product'])
          : null,
    );
  }
}

class Order {
  final int id;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsFromJson = json['items'] as List;
    List<OrderItem> itemList = itemsFromJson
        .map((item) => OrderItem.fromJson(item))
        .toList();
    return Order(
      id: json['id'],
      totalPrice: double.parse(json['total_price'].toString()),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      items: itemList,
    );
  }
}

// --- STATE MANAGEMENT (PROVIDER) ---

class AuthProvider with ChangeNotifier {
  String? _token;
  User? _user;
  String? _uploadError;

  String? get token => _token;
  User? get user => _user;
  String? get uploadError => _uploadError;
  bool get isLoggedIn => _token != null;

  void _clearUploadError() {
    _uploadError = null;
  }

  Future<void> _processAuthResponse(Map<String, dynamic> responseData) async {
    _user = User.fromJson(responseData['user']);
    await _saveToken(responseData['access_token']);
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/login');
    try {
      final response = await http.post(
        url,
        body: {'email': email, 'password': password},
      );
      if (response.statusCode == 200) {
        await _processAuthResponse(json.decode(response.body));
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    final url = Uri.parse('$baseUrl/api/register');
    try {
      final response = await http.post(
        url,
        body: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
      if (response.statusCode == 201) {
        await _processAuthResponse(json.decode(response.body));
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('auth_token')) return;
    _token = prefs.getString('auth_token');
    if (_token != null) {
      final url = Uri.parse('$baseUrl/api/user');
      try {
        final response = await http.get(
          url,
          headers: {'Authorization': 'Bearer $_token'},
        );
        if (response.statusCode == 200) {
          _user = User.fromJson(json.decode(response.body));
        } else {
          await logout();
        }
      } catch (e) {
        /* Gagal, biarkan user null */
      }
    }
    notifyListeners();
  }

  Future<bool> updateProfilePicture(File imageFile) async {
    _clearUploadError();
    if (_token == null) {
      _uploadError = "Anda tidak terautentikasi.";
      return false;
    }

    final url = Uri.parse('$baseUrl/api/user/photo');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $_token';
      request.headers['Accept'] = 'application/json';
      request.files.add(
        await http.MultipartFile.fromPath('photo', imageFile.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        await tryAutoLogin();
        return true;
      } else {
        try {
          final decodedBody = json.decode(responseBody);
          _uploadError =
              decodedBody['message'] ?? 'Terjadi kesalahan dari server.';
        } catch (e) {
          _uploadError =
              'Gagal memproses respons server. Status: ${response.statusCode}';
        }
        print("Error upload: $_uploadError");
        return false;
      }
    } catch (e) {
      print("Exception saat upload foto: $e");
      _uploadError = 'Gagal terhubung ke server. Periksa koneksi Anda.';
      return false;
    }
  }
}

class Cart with ChangeNotifier {
  Map<int, CartItem> _items = {};
  final String? authToken;
  Cart(this.authToken, this._items);

  Map<int, CartItem> get items => {..._items};
  int get itemCount => _items.length;
  double get totalPrice {
    var total = 0.0;
    _items.forEach(
      (key, cartItem) => total += cartItem.product.price * cartItem.quantity,
    );
    return total;
  }

  Future<void> fetchCart() async {
    if (authToken == null) return;
    final url = Uri.parse('$baseUrl/api/cart');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        final Map<int, CartItem> loadedItems = {};
        for (var itemData in responseData) {
          if (itemData['product'] != null) {
            loadedItems.putIfAbsent(
              itemData['product']['id'],
              () => CartItem(
                product: Product.fromJson(itemData['product']),
                quantity: itemData['quantity'],
              ),
            );
          }
        }
        _items = loadedItems;
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching cart: $e");
    }
  }

  Future<void> add(Product product) async {
    if (authToken == null) return;
    final url = Uri.parse('$baseUrl/api/cart');
    final existingItem = _items[product.id];
    try {
      if (existingItem != null) {
        await updateQuantity(product.id, existingItem.quantity + 1);
      } else {
        await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({'product_id': product.id, 'quantity': 1}),
        );
        await fetchCart();
      }
    } catch (e) {
      print("Error adding to cart: $e");
    }
  }

  Future<void> updateQuantity(int productId, int quantity) async {
    if (authToken == null) return;
    if (quantity > 0) {
      final url = Uri.parse('$baseUrl/api/cart/item/$productId');
      try {
        await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({'quantity': quantity}),
        );
        await fetchCart();
      } catch (e) {
        print("Error updating quantity: $e");
      }
    } else {
      await removeItem(productId);
    }
  }

  Future<void> removeItem(int productId) async {
    if (authToken == null) return;
    final url = Uri.parse('$baseUrl/api/cart/item/$productId');
    try {
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      if (response.statusCode == 200) {
        _items.remove(productId);
        notifyListeners();
      }
    } catch (e) {
      print("Error removing item: $e");
    }
  }

  Future<bool> checkout() async {
    if (authToken == null || _items.isEmpty) return false;
    final url = Uri.parse('$baseUrl/api/checkout');
    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      if (response.statusCode == 201) {
        _items.clear();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print("Error checkout: $e");
      return false;
    }
  }

  void clearLocalCart() {
    _items = {};
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, Cart>(
          create: (_) => Cart(null, {}),
          update: (ctx, auth, previousCart) =>
              Cart(auth.token, previousCart == null ? {} : previousCart.items),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple E-Commerce',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          centerTitle: true,
        ),
      ),
      home: const HomePage(),
      routes: {
        '/cart': (context) => const CartPage(),
        '/orders': (context) => const OrderHistoryPage(),
        '/profile': (context) => const ProfilePage(),
        '/edit-profile': (context) => const EditProfilePage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Provider.of<AuthProvider>(context, listen: false).tryAutoLogin(),
      builder: (ctx, authResultSnapshot) {
        if (authResultSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Consumer<AuthProvider>(
          builder: (ctx, auth, _) {
            if (auth.isLoggedIn) {
              Provider.of<Cart>(context, listen: false).fetchCart();
              return const MainPage();
            } else {
              return const LoginPage();
            }
          },
        );
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    ProductListPage(),
    OrderHistoryPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            activeIcon: Icon(Icons.store),
            label: 'Toko',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Pesanan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    bool success = await Provider.of<AuthProvider>(
      context,
      listen: false,
    ).login(_emailController.text, _passwordController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login Gagal! Periksa kembali email dan password Anda.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Email tidak boleh kosong'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Password tidak boleh kosong'
                      : null,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Login'),
                      ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const RegisterPage()),
                  ),
                  child: const Text('Belum punya akun? Daftar di sini'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    bool success = await Provider.of<AuthProvider>(context, listen: false)
        .register(
          _nameController.text,
          _emailController.text,
          _passwordController.text,
          _passwordConfirmController.text,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registrasi Gagal!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun Baru')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Nama tidak boleh kosong'
                      : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Email tidak boleh kosong'
                      : null,
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) => (value?.length ?? 0) < 8
                      ? 'Password minimal 8 karakter'
                      : null,
                ),
                TextFormField(
                  controller: _passwordConfirmController,
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi Password',
                  ),
                  obscureText: true,
                  validator: (value) => value != _passwordController.text
                      ? 'Password tidak cocok'
                      : null,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Daftar'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- PRODUCT LIST PAGE DENGAN FILTER DI APPBAR ---
class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});
  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  late Future<List<Product>> _productsFuture;
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  String _selectedCategory = 'Semua';

  final List<String> _categories = const [
    'Semua',
    'LAPTOP',
    'SMARTPHONE',
    'JAM',
  ];

  @override
  void initState() {
    super.initState();
    _productsFuture = fetchProducts();
  }

  Future<List<Product>> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/products'));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        final products = body
            .map((dynamic item) => Product.fromJson(item))
            .toList();

        if (mounted) {
          setState(() {
            _allProducts = products;
            _filterProducts();
          });
        }
        return products;
      } else {
        throw Exception('Gagal memuat produk. Status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  void _filterProducts() {
    setState(() {
      if (_selectedCategory == 'Semua') {
        _filteredProducts = List.from(_allProducts);
      } else {
        _filteredProducts = _allProducts
            .where(
              (product) => product.category?.toUpperCase() == _selectedCategory,
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Toko Kami',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Kategori: $_selectedCategory',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // --- TOMBOL FILTER BARU: POPUP MENU ---
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Kategori',
            onSelected: (String newValue) {
              setState(() {
                _selectedCategory = newValue;
                _filterProducts();
              });
            },
            itemBuilder: (BuildContext context) {
              return _categories.map((String category) {
                return PopupMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList();
            },
          ),
          Consumer<Cart>(
            builder: (context, cart, child) => Badge(
              label: Text(cart.itemCount.toString()),
              isLabelVisible: cart.items.isNotEmpty,
              child: IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'Keranjang',
                onPressed: () => Navigator.pushNamed(context, '/cart'),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (_allProducts.isEmpty) {
            return const Center(child: Text('Tidak ada produk yang tersedia.'));
          } else {
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _allProducts.clear();
                  _productsFuture = fetchProducts();
                });
              },
              child: _filteredProducts.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada produk di kategori "$_selectedCategory".',
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 12.0,
                            childAspectRatio: 0.7,
                          ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) =>
                          ProductCard(product: _filteredProducts[index]),
                    ),
            );
          }
        },
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: product),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.white,
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) =>
                            loadingProgress == null
                            ? child
                            : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image_outlined,
                              size: 50,
                              color: Colors.grey,
                            ),
                      )
                    : const Icon(
                        Icons.hide_image_outlined,
                        size: 50,
                        color: Colors.grey,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatCurrency.format(product.price),
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Future<void> _buyNow() async {
    int quantity = 1;
    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Beli Langsung'),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text('Jumlah:'),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: quantity > 1
                      ? () => setDialogState(() => quantity--)
                      : null,
                ),
                Text(quantity.toString(), style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setDialogState(() => quantity++),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.of(ctx).pop(null),
              ),
              ElevatedButton(
                child: const Text('Konfirmasi'),
                onPressed: () async {
                  final auth = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  if (auth.token == null) {
                    Navigator.of(ctx).pop(false);
                    return;
                  }
                  final url = Uri.parse('$baseUrl/api/checkout/now');
                  try {
                    final response = await http.post(
                      url,
                      headers: {
                        'Authorization': 'Bearer ${auth.token}',
                        'Content-Type': 'application/json',
                      },
                      body: json.encode({
                        'product_id': widget.product.id,
                        'quantity': quantity,
                      }),
                    );
                    Navigator.of(ctx).pop(response.statusCode == 201);
                  } catch (e) {
                    Navigator.of(ctx).pop(false);
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    if (success == true && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pesanan Berhasil'),
          content: const Text('Pesanan Anda telah berhasil dibuat.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacementNamed('/orders');
              },
              child: const Text('Lihat Pesanan'),
            ),
          ],
        ),
      );
    } else if (success == false && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal membuat pesanan.')));
    }
  }

  Widget _buildOptionsSection(String title, List<String> options) {
    if (options.isEmpty || (options.length == 1 && options.first.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: options
              .map(
                (option) => Chip(
                  label: Text(option),
                  backgroundColor: Colors.teal.shade50,
                  labelStyle: TextStyle(color: Colors.teal.shade800),
                  side: BorderSide.none,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.product.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 300,
              color: Colors.white,
              child:
                  widget.product.imageUrl != null &&
                      widget.product.imageUrl!.isNotEmpty
                  ? Image.network(
                      widget.product.imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        size: 100,
                        color: Colors.grey,
                      ),
                    )
                  : const Icon(
                      Icons.hide_image_outlined,
                      size: 100,
                      color: Colors.grey,
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatCurrency.format(widget.product.price),
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),

                  _buildOptionsSection('Pilihan Warna', widget.product.warna),
                  _buildOptionsSection(
                    'Pilihan Penyimpanan',
                    widget.product.penyimpanan,
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Deskripsi Produk',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final cart = Provider.of<Cart>(context, listen: false);
                  await cart.add(widget.product);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${widget.product.name} berhasil ditambahkan!',
                        ),
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.teal),
                  foregroundColor: Colors.teal,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Icon(Icons.add_shopping_cart),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => _buyNow(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('Beli Sekarang'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _isLoading = false;

  void _doCheckout() async {
    setState(() => _isLoading = true);
    final success = await Provider.of<Cart>(context, listen: false).checkout();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Checkout Berhasil!'),
          content: const Text(
            'Pesanan Anda telah kami terima dan sedang diproses.',
          ),
          actions: [
            TextButton(
              child: const Text('Tutup'),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Lihat Pesanan Saya'),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/orders');
              },
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout gagal. Keranjang Anda mungkin kosong.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Cart>(
      builder: (context, cart, child) {
        final formatCurrency = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        );
        return Scaffold(
          appBar: AppBar(title: const Text('Keranjang Belanja')),
          body: cart.items.isEmpty
              ? const Center(child: Text('Keranjang Anda masih kosong.'))
              : ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final cartItem = cart.items.values.toList()[index];
                    return Card(
                      child: ListTile(
                        leading: Image.network(
                          cartItem.product.imageUrl ?? '',
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image,
                            size: 70,
                            color: Colors.grey,
                          ),
                        ),
                        title: Text(cartItem.product.name),
                        subtitle: Text(
                          formatCurrency.format(cartItem.product.price),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () async {
                                await cart.updateQuantity(
                                  cartItem.product.id,
                                  cartItem.quantity - 1,
                                );
                              },
                            ),
                            Text(cartItem.quantity.toString()),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () async {
                                await cart.updateQuantity(
                                  cartItem.product.id,
                                  cartItem.quantity + 1,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          bottomNavigationBar: cart.items.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            formatCurrency.format(cart.totalPrice),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _doCheckout,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Checkout'),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});
  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  late Future<List<Order>> _ordersFuture;
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  String _selectedStatus = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrders();
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterOrders);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = _fetchOrders();
    });
  }

  Future<List<Order>> _fetchOrders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) throw Exception('Not authenticated');
    final url = Uri.parse('$baseUrl/api/orders');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        final orders = responseData
            .map((data) => Order.fromJson(data))
            .toList();

        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (mounted) {
          setState(() {
            _allOrders = orders;
            _filterOrders();
          });
        }
        return orders;
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  void _filterOrders() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        final statusMatch =
            _selectedStatus == 'Semua' ||
            order.status.toLowerCase() == _selectedStatus.toLowerCase();
        final queryMatch =
            query.isEmpty ||
            order.id.toString().contains(query) ||
            order.items.any(
              (item) =>
                  item.product?.name.toLowerCase().contains(query) ?? false,
            );
        return statusMatch && queryMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pesanan')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari pesanan...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 35,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children:
                        [
                              'Semua',
                              'Pending',
                              'Processing',
                              'Shipped',
                              'Completed',
                            ]
                            .map(
                              (status) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                child: ChoiceChip(
                                  label: Text(status),
                                  selected: _selectedStatus == status,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedStatus = status;
                                        _filterOrders();
                                      });
                                    }
                                  },
                                  selectedColor: Colors.teal,
                                  labelStyle: TextStyle(
                                    color: _selectedStatus == status
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Order>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Gagal memuat data: ${snapshot.error}'),
                  );
                } else if (_allOrders.isEmpty) {
                  return const Center(
                    child: Text(
                      'Anda belum memiliki pesanan.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                } else if (_filteredOrders.isEmpty) {
                  return const Center(
                    child: Text(
                      'Pesanan tidak ditemukan.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                } else {
                  return RefreshIndicator(
                    onRefresh: _refreshOrders,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        return OrderCard(order: _filteredOrders[index]);
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;
  const OrderCard({super.key, required this.order});

  Widget _buildStatusChip(String status) {
    Color chipColor;
    Color textColor;
    String statusText;

    switch (status.toLowerCase()) {
      case 'processing':
        chipColor = Colors.blue.shade50;
        textColor = Colors.blue.shade800;
        statusText = 'Diproses';
        break;
      case 'shipped':
        chipColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        statusText = 'Dikirim';
        break;
      case 'completed':
        chipColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        statusText = 'Selesai';
        break;
      default: // pending
        chipColor = Colors.grey.shade200;
        textColor = Colors.grey.shade800;
        statusText = 'Pending';
    }

    return Chip(
      label: Text(
        statusText,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildOrderItemRow(OrderItem item, BuildContext context) {
    final productName = item.product?.name ?? '[Produk Dihapus]';
    final productImageUrl = item.product?.imageUrl ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              productImageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 50,
                height: 50,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'x${item.quantity}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detail Pesanan #${order.id}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...order.items.map((item) {
                final productName = item.product?.name ?? '[Produk Dihapus]';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(productName),
                  trailing: Text(
                    '${item.quantity} x ${formatCurrency.format(item.price)}',
                  ),
                );
              }).toList(),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Pesanan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    formatCurrency.format(order.totalPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final formatDate = DateFormat('d MMMM yyyy', 'id_ID');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pesanan #${order.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildStatusChip(order.status),
              ],
            ),
            Text(
              formatDate.format(order.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const Divider(height: 24),
            ...order.items.map((item) => _buildOrderItemRow(item, context)),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatCurrency.format(order.totalPrice),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showOrderDetails(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Detail Pesanan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.teal),
                      foregroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      order.status.toLowerCase() == 'completed'
                          ? 'Beli Lagi'
                          : 'Lacak',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isUploading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.updateProfilePicture(_imageFile!);

      if (mounted) {
        final message =
            authProvider.uploadError ??
            (success
                ? 'Foto profil berhasil diperbarui!'
                : 'Gagal memperbarui foto.');

        setState(() {
          _isUploading = false;
          _imageFile = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showUpdatePasswordDialog() {
    final passwordFormKey = GlobalKey<FormState>();
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Password'),
        content: Form(
          key: passwordFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Password Saat Ini',
                  ),
                  obscureText: true,
                  validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                ),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: const InputDecoration(labelText: 'Password Baru'),
                  obscureText: true,
                  validator: (v) => v!.length < 8 ? 'Minimal 8 karakter' : null,
                ),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi Password Baru',
                  ),
                  obscureText: true,
                  validator: (v) => v != _newPasswordController.text
                      ? 'Password tidak cocok'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!passwordFormKey.currentState!.validate()) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final url = Uri.parse('$baseUrl/api/user/password');
              try {
                final response = await http.put(
                  url,
                  headers: {
                    'Authorization': 'Bearer ${auth.token}',
                    'Accept': 'application/json',
                  },
                  body: {
                    'current_password': _currentPasswordController.text,
                    'password': _newPasswordController.text,
                    'password_confirmation': _confirmPasswordController.text,
                  },
                );
                Navigator.of(ctx).pop();
                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password berhasil diubah!')),
                  );
                } else {
                  final error = json.decode(response.body)['message'];
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Gagal: $error')));
                }
              } catch (e) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              Provider.of<AuthProvider>(context, listen: false).logout();
              Provider.of<Cart>(context, listen: false).clearLocalCart();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = auth.user!;

        ImageProvider? backgroundImage;
        if (_imageFile != null) {
          backgroundImage = FileImage(_imageFile!);
        } else if (user.profilePhotoUrl != null) {
          backgroundImage = NetworkImage(user.profilePhotoUrl!);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Profil Saya')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: backgroundImage,
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : (backgroundImage == null
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white70,
                                  )
                                : null),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal,
                          border: Border.all(width: 2, color: Colors.white),
                        ),
                        child: InkWell(
                          onTap: _isUploading
                              ? null
                              : _showImageSourceActionSheet,
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                _buildProfileMenu(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          _ProfileMenuItem(
            icon: Icons.edit_outlined,
            title: 'Edit Profil',
            onTap: () {
              Navigator.pushNamed(context, '/edit-profile');
            },
          ),
          _ProfileMenuItem(
            icon: Icons.lock_outline,
            title: 'Ubah Password',
            onTap: _showUpdatePasswordDialog,
          ),
          _ProfileMenuItem(
            icon: Icons.help_outline,
            title: 'Pusat Bantuan',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur ini akan segera hadir!')),
              );
            },
          ),
          const Divider(height: 30),
          _ProfileMenuItem(
            icon: Icons.logout,
            title: 'Logout',
            textColor: Colors.red,
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: textColor ?? Colors.teal),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: textColor == null
          ? const Icon(Icons.chevron_right, color: Colors.grey)
          : null,
    );
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final url = Uri.parse('$baseUrl/api/user/profile-information');

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'name': _nameController.text,
          'email': _emailController.text,
        }),
      );

      if (response.statusCode == 200) {
        await auth.tryAutoLogin();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil berhasil diperbarui!')),
          );
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Gagal memperbarui profil: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                validator: (value) =>
                    value!.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value!.isEmpty ? 'Email tidak valid' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan Perubahan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
