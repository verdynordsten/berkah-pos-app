import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ---- Models (ringkas, sesuai schema.sql) ----
class Product {
  final String id, name;
  final double price;
  final int stock;
  final String? photoUrl, categoryId;
  Product({required this.id, required this.name, required this.price,
    required this.stock, this.photoUrl, this.categoryId});
  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'] as String, name: m['name'] as String,
    price: (m['price'] as num).toDouble(), stock: m['stock'] as int,
    photoUrl: m['photo_url'] as String?, categoryId: m['category_id'] as String?);
}

class CartLine {
  final Product product;
  int qty;
  CartLine(this.product, this.qty);
  double get total => product.price * qty;
}

class Cart extends StateNotifier<List<CartLine>> {
  Cart() : super([]);
  void add(Product p) {
    final i = state.indexWhere((e) => e.product.id == p.id);
    if (i < 0) {
      state = [...state, CartLine(p, 1)];
    } else {
      final c = [...state];
      c[i].qty++;
      state = c;
    }
  }
  void dec(Product p) {
    final i = state.indexWhere((e) => e.product.id == p.id);
    if (i < 0) return;
    final c = [...state];
    if (c[i].qty <= 1) {
      c.removeAt(i);
    } else {
      c[i].qty--;
    }
    state = c;
  }
  void clear() => state = [];
  int get count => state.fold(0, (a, e) => a + e.qty);
  double get subtotal => state.fold(0, (a, e) => a + e.total);
}

final cartProvider = StateNotifierProvider<Cart, List<CartLine>>((ref) => Cart());

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final db = ref.watch(supabaseProvider);
  final rows = await db.from('products')
      .select()
      .eq('is_active', true)
      .order('name');
  return (rows as List).map((e) => Product.fromMap(e)).toList();
});

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(supabaseProvider);
  final rows = await db.from('categories').select().order('sort');
  return (rows as List).cast<Map<String, dynamic>>();
});
