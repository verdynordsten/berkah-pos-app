import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'kasir_setup.dart' show hashPin;

// 03 PIN Kasir — pilih nama kasir -> numpad 6 digit -> verify_staff_pin.
// Dipakai 2 arah:
//  A. Tanpa session (tombol "Saya kasir" di login): WAJIB cari toko dulu
//     (nama toko), daftar kasir HANYA dari toko itu — Vina toko A tidak
//     akan muncul di device yang cari toko B. Ini yang bikin akun lama
//     tetap bisa dipakai tanpa login email owner.
//  B. Dengan session (switch user dari dalam): langsung daftar kasir
//     store aktif (dipakai Ganti Pengguna).
// Sukses -> session staffPin (role kasir/admin) -> /shift.
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});
  @override
  ConsumerState<PinScreen> createState() => _P();
}

class _P extends ConsumerState<PinScreen> {
  String pin = '';
  String? picked;
  String? err;
  bool busy = false;
  List<Map<String, dynamic>> staff = [];
  bool loaded = false;

  // Mode tanpa session: cari toko dulu (anti-global).
  final _storeCtl = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _stores = [];
  Map<String, dynamic>? _storePicked;
  bool _searched = false;

  Future<void> _load() async {
    final s = ref.read(sessionProvider);
    try {
      final db = ref.read(supabaseProvider);
      if (s == null) {
        // Tanpa session: JANGAN load global. Tunggu user pilih toko.
        if (_storePicked != null) {
          final rows = await db.from('staff').select()
              .eq('store_id', _storePicked!['id'] as String)
              .eq('is_active', true).order('name');
          staff = (rows as List).cast<Map<String, dynamic>>();
        } else {
          staff = [];
        }
      } else {
        final rows = await db.from('staff').select()
            .eq('store_id', s.storeId).eq('is_active', true).order('name');
        staff = (rows as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      err = '$e';
    }
    if (mounted) setState(() => loaded = true);
  }

  Future<void> _cariToko() async {
    final q = _storeCtl.text.trim();
    if (q.isEmpty) {
      setState(() => err = 'Ketik nama toko dulu.');
      return;
    }
    setState(() { _searching = true; err = null; });
    try {
      final db = ref.read(supabaseProvider);
      final rows = await db.from('stores').select('id, name')
          .ilike('name', '%$q%').order('name').limit(5);
      _stores = (rows as List).cast<Map<String, dynamic>>();
      _searched = true;
      if (_stores.isEmpty && mounted) {
        setState(
            () => err = 'Toko "$q" tidak ketemu. Cek ejaan nama toko.');
      }
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pilihToko(Map<String, dynamic> t) {
    setState(() {
      _storePicked = t;
      _stores = [];
      _searched = false;
      staff = [];
      picked = null;
      pin = '';
      loaded = false;
      err = null;
    });
    _load();
  }

  Future<void> tap(String k) async {
    setState(() {
      if (k == 'X') {
        if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
      } else if (pin.length < 6) {
        pin += k;
      }
      err = null;
    });
    if (pin.length == 6) await _verify();
  }

  Future<void> _verify() async {
    if (picked == null) {
      setState(() { err = 'Pilih nama kasir dulu.'; pin = ''; });
      return;
    }
    setState(() => busy = true);
    try {
      final db = ref.read(supabaseProvider);
      final row = staff.firstWhere((e) => e['id'] == picked);
      final storeId = row['store_id'] as String;
      final name = row['name'] as String;
      final storeName = (row['stores'] is Map)
          ? ((row['stores'] as Map)['name'] as String? ?? 'Toko')
          : (_storePicked?['name'] as String?) ??
              (ref.read(sessionProvider)?.storeName ?? 'Toko');
      final sid = await db.rpc('verify_staff_pin', params: {
        'p_store_id': storeId,
        'p_name': name,
        'p_pin_hash': hashPin(storeId, name, pin),
      });
      if (sid == null) throw StateError('PIN salah. Coba lagi.');
      ref.read(sessionProvider.notifier).set(PosSession(
        kind: LoginKind.staffPin, storeId: storeId, storeName: storeName,
        actorId: sid as String, displayName: name,
        role: ((row['role'] as String?) == 'admin') ? 'admin' : 'kasir'));
      if (mounted) Navigator.pushReplacementNamed(context, '/shift');
    } catch (e) {
      setState(() { err = '$e'; pin = ''; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (!loaded) _load();
    final dots =
        List.generate(6, (i) => i < pin.length ? '●' : '○').join(' ');
    const keys = [
      '1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'X'
    ];

    // ---- MODE TANPA SESSION: wajib pilih toko dulu (anti-global) ----
    if (s == null && _storePicked == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('PIN Kasir')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const SizedBox(height: 8),
          const Text('Kasir toko apa?',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
              'Ketik nama toko. Daftar kasir yang muncul HANYA dari toko itu — bukan toko lain.',
              style: TextStyle(color: AppColors.mfg)),
          const SizedBox(height: 12),
          TextField(controller: _storeCtl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _cariToko(),
              decoration: const InputDecoration(
                  labelText: 'Nama toko',
                  hintText: 'cth: Berkah Coffee',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store))),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: _searching ? null : _cariToko,
              child: Text(_searching ? 'Mencari...' : 'Cari Toko')),
          if (err != null) ...[
            const SizedBox(height: 8),
            Text(err!, style: const TextStyle(color: Colors.red)),
          ],
          if (_searched && _stores.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Pilih toko:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._stores.map((t) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.store,
                        color: AppColors.pri),
                    title: Text((t['name'] as String?) ?? '-'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pilihToko(t),
                  ),
                )),
          ],
        ]),
      );
    }

    final storeLabel = s != null
        ? s.storeName
        : (_storePicked?['name'] as String? ?? 'Toko');
    return Scaffold(
      appBar: AppBar(
          title: Text('PIN Kasir — $storeLabel'),
          leading: (s == null && _storePicked != null)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() {
                    _storePicked = null;
                    staff = [];
                    picked = null;
                    pin = '';
                    _searched = false;
                  }),
                )
              : null),
      body: Column(children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            initialValue: picked,
            decoration: const InputDecoration(
                labelText: 'Nama kasir', border: OutlineInputBorder()),
            items: staff.map((e) => DropdownMenuItem(
                  value: e['id'] as String,
                  child: Text((e['name'] as String?) ?? '-'),
                )).toList(),
            onChanged: (v) => setState(() => picked = v),
          ),
        ),
        const SizedBox(height: 8),
        Text(dots,
            style: const TextStyle(
                fontSize: 26, color: AppColors.pri, letterSpacing: 4)),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(err!, style: const TextStyle(color: Colors.red)),
          ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(24),
            children: keys
                .map((k) => k.isEmpty
                    ? const SizedBox()
                    : InkWell(
                        onTap: busy ? null : () => tap(k),
                        child: Center(
                            child: Text(k,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600)))))
                .toList(),
          ),
        ),
      ]),
    );
  }
}
