import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/store.dart';
import 'kasir_setup.dart' show hashOwnerPin;
import '../core/loading.dart';

// 02a Register — daftar owner + bikin toko + PASANG PIN OWNER dalam 1 langkah.
// Flow: signUp -> create_store_with_owner (RPC) -> simpan pin_hash owner
// -> session owner -> /toko. Tanpa PIN owner, kasir bisa naik ke owner.
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
  final _pin = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _go() async {
    final name = _name.text.trim();
    final store = _store.text.trim();
    final email = _email.text.trim();
    final pass = _pass.text;
    final pin = _pin.text.trim();
    if (name.isEmpty || store.isEmpty || email.isEmpty || pass.length < 6) {
      setState(() => _err = 'Lengkapi semua (password min. 6).');
      return;
    }
    if (pin.length != 6 || int.tryParse(pin) == null) {
      setState(() => _err = 'PIN owner harus 6 digit angka.');
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
      // Langsung pasang PIN owner biar mode owner terkunci sejak awal.
      try {
        await db.from('memberships').update({
          'pin_hash': hashOwnerPin(sid, uid, pin),
        }).eq('user_id', uid).eq('store_id', sid);
      } catch (_) {}
      // Toko baru = kosong total. Owner isi sendiri via
      // Setup Toko -> Kelola Kasir -> Tambah Produk.
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
        const SizedBox(height: 12),
        const Text('PIN Owner (6 digit)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _pin, obscureText: true,
            keyboardType: TextInputType.number, maxLength: 6,
            decoration: const InputDecoration(
                hintText: 'cth: 123456', border: OutlineInputBorder())),
        if (_err != null) ...[
          const SizedBox(height: 8),
          Text(_err!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy ? null : _go,
            child: _busy ? const BusyLabel('Mendaftar') : const Text('Daftar & Buat Toko')),
        TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/login'),
            child: const Text('Sudah punya akun? Masuk')),
      ]),
    );
  }
}
