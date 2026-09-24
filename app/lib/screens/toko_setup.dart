import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';

// 03a Setup Toko (owner) — nama/alamat/telp/pajak. Dibuka setelah
// register & tiap login owner. Simpan -> update stores -> /kasir.
class TokoSetupScreen extends ConsumerStatefulWidget {
  const TokoSetupScreen({super.key});
  @override
  ConsumerState<TokoSetupScreen> createState() => _T();
}

class _T extends ConsumerState<TokoSetupScreen> {
  final _name = TextEditingController();
  final _addr = TextEditingController();
  final _phone = TextEditingController();
  final _tax = TextEditingController();
  bool _busy = false;
  bool _loaded = false;
  String? _err;

  Future<void> _load(String storeId) async {
    final db = ref.read(supabaseProvider);
    final row = await db.from('stores').select().eq('id', storeId).maybeSingle();
    if (row == null) return;
    _name.text = (row['name'] as String?) ?? '';
    _addr.text = (row['address'] as String?) ?? '';
    _phone.text = (row['phone'] as String?) ?? '';
    _tax.text = '${row['tax_percent'] ?? 10}';
    setState(() => _loaded = true);
  }

  /// Coba pulihkan sesi dari auth Supabase yang tersimpan di device.
  /// Return true kalau berhasil (navigasi ke /pilih), false kalau memang
  /// belum login / belum punya toko (tampilkan tombol ke /login).
  Future<bool> _restore() async {
    try {
      final s = await restoreOwnerSession(ref.read(supabaseProvider));
      if (s == null) return false;
      ref.read(sessionProvider.notifier).set(s);
      if (mounted) Navigator.pushReplacementNamed(context, '/pilih');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _save() async {
    final s = ref.read(sessionProvider);
    if (s == null) return;
    // KUNCI: setup toko hanya owner/admin.
    if (!s.canManageMenu) {
      setState(() => _err = 'Hanya Owner / Admin yang boleh ubah toko.');
      return;
    }
    setState(() { _busy = true; _err = null; });
    try {
      final db = ref.read(supabaseProvider);
      final tax = double.tryParse(_tax.text.replaceAll(',', '.')) ?? 10;
      await db.from('stores').update({
        'name': _name.text.trim(),
        'address': _addr.text.trim(),
        'phone': _phone.text.trim(),
        'tax_percent': tax,
      }).eq('id', s.storeId);
      ref.read(sessionProvider.notifier).set(PosSession(
        kind: s.kind, storeId: s.storeId,
        storeName: _name.text.trim().isEmpty ? s.storeName : _name.text.trim(),
        actorId: s.actorId, displayName: s.displayName, role: s.role));
      ref.invalidate(storeProfileProvider);
      if (mounted) Navigator.pushReplacementNamed(context, '/kasir');
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (s == null) {
      // Sesi in-memory hilang (mis. habis restart app) tapi auth Supabase
      // mungkin masih ada -> coba pulihkan otomatis, jangan dead-end.
      return FutureBuilder(
        future: _restore(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snap.data == true) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Setup Toko')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                          'Sesi habis. Masuk lagi dulu ya.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                            context, '/login', (_) => false),
                        child: const Text('Ke Halaman Masuk'),
                      ),
                    ]),
              ),
            ),
          );
        },
      );
    }
    if (!_loaded) _load(s.storeId);
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Toko')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Langkah 1/2 — Profil toko (tampil di struk)',
            style: TextStyle(color: AppColors.mfg)),
        const SizedBox(height: 12),
        const Text('Nama toko', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _name,
            decoration: const InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('Alamat', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _addr,
            decoration: const InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('No. HP / WA', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _phone, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('Pajak (%)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _tax, keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                hintText: '10', border: OutlineInputBorder())),
        if (_err != null) ...[
          const SizedBox(height: 8),
          Text(_err!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Menyimpan...' : 'Simpan & Lanjut')),
      ]),
    );
  }
}
