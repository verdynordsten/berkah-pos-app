import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/store.dart';
import '../core/theme.dart';

// 02 Login — 2 pintu:
//  A. Owner/Admin: email + password (Supabase Auth) -> /pilih (pilih pengguna).
//  B. Kasir: nama + PIN -> layar PIN (/pin) verifikasi via RPC -> /shift.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _L();
}

class _L extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _loginOwner() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _err = 'Isi email + password.');
      return;
    }
    setState(() { _busy = true; _err = null; });
    try {
      final db = ref.read(supabaseProvider);
      final res = await db.auth.signInWithPassword(
          email: email, password: pass);
      final uid = res.user?.id;
      if (uid == null) throw StateError('Login gagal.');
      final mem = await db.from('memberships').select().eq('user_id', uid)
          .eq('is_active', true).order('created_at').limit(1).maybeSingle();
      if (mem == null) {
        // User auth ada tapi belum punya toko (mis. RPC gagal di register)
        // -> arahkan bikin toko.
        if (mounted) Navigator.pushReplacementNamed(context, '/toko_baru');
        return;
      }
      final store = await db.from('stores').select()
          .eq('id', mem['store_id'] as String).maybeSingle();
      ref.read(sessionProvider.notifier).set(PosSession(
        kind: LoginKind.owner,
        storeId: mem['store_id'] as String,
        storeName: (store?['name'] as String?) ?? 'Toko',
        actorId: uid,
        displayName: (mem['display_name'] as String?) ?? 'Owner',
        role: (mem['role'] as String?) ?? 'staff'));
      if (mounted) {
        // Login sukses -> pilih mau jualan sebagai siapa -> shift -> dashboard.
        Navigator.pushReplacementNamed(context, '/pilih');
      }
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
      appBar: AppBar(title: const Text('Masuk')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.mut,
              borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.store, size: 36, color: AppColors.pri),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
            child: Text('Selamat Datang',
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
        const Center(
            child: Text('Masuk untuk mulai berjualan',
                style: TextStyle(color: AppColors.mfg))),
        const SizedBox(height: 16),
        const Text('Email owner / admin',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                hintText: 'kamu@toko.id', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('Password',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(
                hintText: '••••••••', border: OutlineInputBorder())),
        if (_err != null) ...[
          const SizedBox(height: 8),
          Text(_err!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 12),
        FilledButton(
            onPressed: _busy ? null : _loginOwner,
            child: Text(_busy ? 'Masuk...' : 'Masuk')),
        const SizedBox(height: 4),
        OutlinedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/pin'),
            child: const Text('Saya kasir (login PIN)')),
        TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/register'),
            child: const Text('Belum punya akun? Daftar')),
      ]),
    );
  }
}
