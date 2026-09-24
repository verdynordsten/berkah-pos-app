import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'last_session.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ---- Models (ringkas, sesuai schema.sql + schema_v2.sql) ----
class Product {
  final String id, name;
  final double price;
  final int stock;
  final String? photoUrl, categoryId;
  Product({required this.id, required this.name, required this.price,
    required this.stock, this.photoUrl, this.categoryId});
  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'] as String, name: m['name'] as String,
    price: (m['price'] as num).toDouble(), stock: (m['stock'] as int?) ?? 0,
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
  /// Tambah 1 pcs. Return false kalau stok tidak cukup (batas = p.stock).
  bool add(Product p) {
    final i = state.indexWhere((e) => e.product.id == p.id);
    final cur = i < 0 ? 0 : state[i].qty;
    if (cur + 1 > p.stock) return false;
    if (i < 0) {
      state = [...state, CartLine(p, 1)];
    } else {
      final c = [...state];
      c[i].qty++;
      state = c;
    }
    return true;
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

// ============ SESSION (siapa yang buka app + toko aktif) ============
/// Sumber login: owner/admin via Supabase Auth, atau kasir via PIN.
enum LoginKind { owner, staffPin }

class PosSession {
  final LoginKind kind;
  final String storeId;
  final String storeName;
  /// user_id (owner) atau staff_id (kasir PIN)
  final String actorId;
  final String displayName;
  final String role; // owner / admin / kasir
  const PosSession({required this.kind, required this.storeId,
    required this.storeName, required this.actorId,
    required this.displayName, required this.role});
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
  /// Owner + admin boleh kelola menu. Kasir (staff) tidak.
  bool get canManageMenu => isOwner || isAdmin;
  String get roleLabel {
    if (isOwner) return 'Owner';
    if (isAdmin) return 'Admin';
    return 'Kasir';
  }
}

class SessionCtl extends StateNotifier<PosSession?> {
  SessionCtl(this._ref) : super(null);
  // ignore: unused_field
  final Ref _ref;
  void set(PosSession s) {
    // Ganti toko/user = keranjang lama dibuang (produk toko lain
    // tidak boleh kebawa checkout ke toko baru).
    _ref.read(cartProvider.notifier).clear();
    _ref.read(customerProvider.notifier).state = null;
    state = s;
    // Ingat posisi terakhir di device (tahan app ke-kill).
    // Fire-and-forget: jangan tahan UI kalau storage lambat.
    LastSession.saveSpot(s);
  }

  void clear() {
    _ref.read(cartProvider.notifier).clear();
    try {
      _ref.read(customerProvider.notifier).state = null;
    } catch (_) {}
    state = null;
  }
}

/// Pulihkan sesi owner dari Supabase Auth yang masih tersimpan di device.
/// Dipakai layar mana pun kalau sessionProvider (in-memory) hilang tapi
/// auth Supabase masih ada — mis. habis restart app / hot-restart /
/// nyasar ke route tanpa sesi. Return null kalau: belum login sama sekali,
/// atau user auth ada tapi belum punya membership toko.
Future<PosSession?> restoreOwnerSession(SupabaseClient db) async {
  final u = db.auth.currentUser;
  if (u == null) return null;
  final mem = await db.from('memberships').select().eq('user_id', u.id)
      .eq('is_active', true).order('created_at').limit(1).maybeSingle();
  if (mem == null) return null;
  final store = await db.from('stores').select()
      .eq('id', mem['store_id'] as String).maybeSingle();
  return PosSession(
    kind: LoginKind.owner,
    storeId: mem['store_id'] as String,
    storeName: (store?['name'] as String?) ?? 'Toko',
    actorId: u.id,
    displayName: (mem['display_name'] as String?) ?? 'Owner',
    role: (mem['role'] as String?) ?? 'staff');
}

final sessionProvider = StateNotifierProvider<SessionCtl, PosSession?>((ref) => SessionCtl(ref));

/// Provider global (dulu di shift.dart / pelanggan.dart, dipindah ke sini
/// biar SessionCtl bisa reset keduanya saat ganti sesi tanpa circular import).
/// Shift aktif — id dipakai saat simpan transaksi.
final shiftProvider = StateProvider<Map<String, dynamic>?>((_) => null);

/// Pelanggan terpilih — dipakai checkout (customer_id transaksi).
final customerProvider = StateProvider<Map<String, dynamic>?>((_) => null);

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final db = ref.watch(supabaseProvider);
  final session = ref.watch(sessionProvider);
  var q = db.from('products').select().eq('is_active', true);
  if (session != null) q = q.eq('store_id', session.storeId);
  final rows = await q.order('name');
  return (rows as List).map((e) => Product.fromMap(e)).toList();
});

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(supabaseProvider);
  final session = ref.watch(sessionProvider);
  var q = db.from('categories').select();
  if (session != null) q = q.eq('store_id', session.storeId);
  final rows = await q.order('sort');
  return (rows as List).cast<Map<String, dynamic>>();
});

/// Profil toko aktif (nama/alamat/telp/pajak) — dipakai katalog + struk.
final storeProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  final db = ref.watch(supabaseProvider);
  return await db.from('stores').select().eq('id', session.storeId).maybeSingle();
});
