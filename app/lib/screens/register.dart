import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/store.dart';

// 02a Register — daftar owner + bikin toko dalam 1 langkah.
// Flow: signUp -> create_store_with_owner (RPC) -> session owner -> /toko.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _R();
}

class _R extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _store = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _go() async {
    final name = _name.text.trim();
    final store = _store.text.trim();
    final email = _email.text.trim();
    final pass = _pass.text;
    if (name.isEmpty || store.isEmpty || email.isEmpty || pass.length < 6) {
      setState(() => _err = 'Lengkapi semua (password min. 6).');
      return;
    }
    setState(() { _busy = true; _err = null; });
    try {
      final db = ref.read(supabaseProvider);
      final res = await db.auth.signUp(email: email, password: pass);
      final uid = res.user?.id;
      if (uid == null) throw StateError('Registrasi gagal — cek email/password.');
      // Bikin toko + membership owner via RPC (user_id eksplisit dari signUp).
      final sid = await db.rpc('create_store_with_owner', params: {
        'p_user_id': uid,
        'p_store_name': store,
        'p_display_name': name,
      }) as String;
      // Default: kasir contoh + kategori + produk kopi agar katalog langsung isi.
      await db.from('staff').insert({'store_id': sid, 'name': 'Kasir 1', 'pin_hash': '-'});
      final cats = await db.from('categories').insert([
        {'store_id': sid, 'name': 'Minuman', 'sort': 1},
        {'store_id': sid, 'name': 'Makanan', 'sort': 2},
        {'store_id': sid, 'name': 'Snack', 'sort': 3},
      ]).select();
      String? catId(String n) {
        for (final c in (cats as List)) {
          final m = (c as Map).cast<String, dynamic>();
          if ((m['name'] as String?) == n) return m['id'] as String?;
        }
        return null;
      }
      await db.from('products').insert([
        {'store_id': sid, 'category_id': catId('Minuman'), 'name': 'Kopi Susu Gula Aren', 'price': 18000, 'stock': 50},
        {'store_id': sid, 'category_id': catId('Minuman'), 'name': 'Americano', 'price': 15000, 'stock': 50},
        {'store_id': sid, 'category_id': catId('Minuman'), 'name': 'Teh Manis', 'price': 8000, 'stock': 50},
        {'store_id': sid, 'category_id': catId('Makanan'), 'name': 'Indomie Goreng', 'price': 12000, 'stock': 40},
        {'store_id': sid, 'category_id': catId('Snack'), 'name': 'Pisang Goreng', 'price': 10000, 'stock': 30},
      ]);
      ref.read(sessionProvider.notifier).set(PosSession(
        kind: LoginKind.owner, storeId: sid, storeName: store,
        actorId: uid, displayName: name, role: 'owner'));
      if (mounted) Navigator.pushReplacementNamed(context, '/toko');
    } on AuthException catch (e) {
      setState(() => _err = e.message);
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun Toko')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Nama kamu',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _name,
            decoration: const InputDecoration(
                hintText: 'cth: Verdy', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('Nama toko',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _store,
            decoration: const InputDecoration(
                hintText: 'cth: Toko Berkah Jaya',
                border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('Email',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                hintText: 'kamu@toko.id', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('Password (min. 6)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _pass, obscureText: true,
            decoration: const InputDecoration(
                hintText: '••••••••', border: OutlineInputBorder())),
        if (_err != null) ...[
          const SizedBox(height: 8),
          Text(_err!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy ? null : _go,
            child: Text(_busy ? 'Mendaftar...' : 'Daftar & Buat Toko')),
        TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/login'),
            child: const Text('Sudah punya akun? Masuk')),
      ]),
    );
  }
}
