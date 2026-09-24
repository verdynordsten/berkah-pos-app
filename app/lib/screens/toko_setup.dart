import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';

// 03a Setup Toko (owner) — 2 mode:
//  A. Punya session (normal): edit nama/alamat/telp/pajak. Simpan -> /kasir.
//  B. TANPA session tapi auth Supabase ada (login valid, membership belum ada
//     karena RPC register gagal / akun lama tanpa baris membership):
//     form BIKIN TOKO BARU langsung dari sini -> RPC (fallback insert manual)
//     -> /pilih. Jadi tidak ada lagi loop "Sesi habis -> login -> Sesi habis".
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
  /// Return record: status ('ok' / 'notoko' / 'login') + detail error
  /// (kalau ada) biar layar bisa nampilin PENYEBAB ASLI, bukan cuma
  /// "Sesi habis". Kasus akun lama: auth valid + toko ADA, tapi query
  /// membership/store gagal (RLS / network / Supabase mati) -> status
  /// 'login' + detail error. Jangan dituduh belum punya toko.
  Future<({String status, String? detail})> _restore() async {
    try {
      final db = ref.read(supabaseProvider);
      if (db.auth.currentUser == null) {
        return (status: 'login', detail: null);
      }
      final s = await restoreOwnerSession(db);
      if (s == null) return (status: 'notoko', detail: null);
      ref.read(sessionProvider.notifier).set(s);
      if (mounted) Navigator.pushReplacementNamed(context, '/pilih');
      return (status: 'ok', detail: null);
    } catch (e) {
      return (status: 'login', detail: '$e');
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
          if (snap.data?.status == 'ok') {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          // Auth valid tapi belum punya toko (register kepotong / RPC gagal):
          // langsung kasih form bikin toko, BUKAN layar "Sesi habis".
          if (snap.data?.status == 'notoko') {
            return const _BuatTokoForm();
          }
          // Belum login ATAU query DB gagal (RLS/network/Supabase mati).
          // Tampilkan PENYEBAB ASLI biar ketahuan, jangan cuma "Sesi habis".
          final detail = snap.data?.detail;
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
                      if (detail != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.mut,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Penyebab: $detail',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.mfg),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Screenshot teks ini ke developer.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.mfg),
                        ),
                      ],
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

/// Form bikin toko baru — dipakai kalau auth login VALID tapi membership
/// toko belum ada (akun lama tanpa baris membership / RPC register gagal).
/// Isi nama toko + nama owner -> RPC create_store_with_owner (fallback:
/// insert stores + memberships manual) -> langsung /pilih. Anti-loop.
class _BuatTokoForm extends ConsumerStatefulWidget {
  const _BuatTokoForm();
  @override
  ConsumerState<_BuatTokoForm> createState() => _BTF();
}

class _BTF extends ConsumerState<_BuatTokoForm> {
  final _store = TextEditingController();
  final _name = TextEditingController(text: 'Owner');
  bool _busy = false;
  String? _err;

  Future<void> _go() async {
    final store = _store.text.trim();
    final name = _name.text.trim().isEmpty ? 'Owner' : _name.text.trim();
    if (store.isEmpty) {
      setState(() => _err = 'Isi nama toko dulu.');
      return;
    }
    setState(() { _busy = true; _err = null; });
    try {
      final db = ref.read(supabaseProvider);
      final u = db.auth.currentUser;
      if (u == null) throw StateError('Sesi login hilang. Masuk lagi.');
      String sid;
      try {
        sid = await db.rpc('create_store_with_owner', params: {
          'p_user_id': u.id,
          'p_store_name': store,
          'p_display_name': name,
        }) as String;
      } catch (_) {
        // RPC belum ada / gagal (DB lama): bikin manual 2 langkah.
        final srow = await db.from('stores').insert({'name': store})
            .select('id').single();
        sid = srow['id'] as String;
        await db.from('memberships').upsert({
          'store_id': sid, 'user_id': u.id,
          'role': 'owner', 'display_name': name, 'is_active': true,
        }, onConflict: 'store_id,user_id');
      }
      ref.read(sessionProvider.notifier).set(PosSession(
        kind: LoginKind.owner, storeId: sid, storeName: store,
        actorId: u.id, displayName: name, role: 'owner'));
      if (mounted) Navigator.pushReplacementNamed(context, '/pilih');
    } catch (e) {
      if (mounted) setState(() { _err = '$e'; _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Toko')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Login berhasil, tapi akun ini belum punya toko.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Isi sekali aja — langsung masuk Pilih Pengguna.',
            style: TextStyle(color: AppColors.mfg)),
        const SizedBox(height: 16),
        const Text('Nama toko',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _store,
            decoration: const InputDecoration(
                hintText: 'cth: Berkah Coffee',
                border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('Nama owner',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _name,
            decoration: const InputDecoration(
                hintText: 'cth: Verdy',
                border: OutlineInputBorder())),
        if (_err != null) ...[
          const SizedBox(height: 8),
          Text(_err!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy ? null : _go,
            child: Text(_busy ? 'Membuat...' : 'Buat Toko & Masuk')),
      ]),
    );
  }
}
