import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/last_session.dart';
import '../core/theme.dart';
import '../core/loading.dart';
import 'kasir_setup.dart' show hashOwnerPin;

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
  final _step = TextEditingController();
  final _pval = TextEditingController();
  final _modalDef = TextEditingController();
  List<Map<String, dynamic>> _shifts = [];
  bool _shiftsLoaded = false;
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
    _step.text = '${row['point_step'] ?? 10000}';
    _pval.text = '${row['point_value'] ?? 100}';
    _modalDef.text = '${row['default_opening_cash'] ?? 0}';
    setState(() => _loaded = true);
    // Template shift per-toko (DB lama tanpa tabel v7 -> fallback default).
    try {
      final trows = await db.from('shift_templates').select()
          .eq('store_id', storeId).order('sort');
      _shifts = (trows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      _shifts = [
        {'name': 'Pagi', 'start_hour': 7, 'end_hour': 15, 'sort': 0},
        {'name': 'Siang', 'start_hour': 15, 'end_hour': 23, 'sort': 1},
        {'name': 'Malam', 'start_hour': 23, 'end_hour': 7, 'sort': 2},
      ];
    }
    if (mounted) setState(() => _shiftsLoaded = true);
  }

  String _fmtJam(int h) => '${h.toString().padLeft(2, '0')}:00';

  Future<void> _shiftDialog({Map<String, dynamic>? cur, int? idx}) async {
    final nCtl = TextEditingController(text: (cur?['name'] ?? '').toString());
    int sh = ((cur?['start_hour'] as num?) ?? 7).toInt();
    int eh = ((cur?['end_hour'] as num?) ?? 15).toInt();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(cur == null ? 'Tambah Shift' : 'Ubah Shift'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nCtl,
                decoration: const InputDecoration(
                    labelText: 'Nama shift (cth: Pagi)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: sh,
                  decoration: const InputDecoration(
                      labelText: 'Mulai', border: OutlineInputBorder()),
                  items: [for (var h = 0; h < 24; h++)
                    DropdownMenuItem(value: h, child: Text(_fmtJam(h)))],
                  onChanged: (v) => setD(() => sh = v ?? sh),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: eh,
                  decoration: const InputDecoration(
                      labelText: 'Selesai', border: OutlineInputBorder()),
                  items: [for (var h = 0; h < 24; h++)
                    DropdownMenuItem(value: h, child: Text(_fmtJam(h)))],
                  onChanged: (v) => setD(() => eh = v ?? eh),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Jam selesai boleh < jam mulai (cth: 23→07 = lewat tengah malam).',
              style: TextStyle(fontSize: 11, color: AppColors.mfg)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final nm = nCtl.text.trim();
    if (nm.isEmpty) {
      setState(() => _err = 'Nama shift wajib diisi.');
      return;
    }
    setState(() {
      _err = null;
      final entry = {
        if (cur?['id'] != null) 'id': cur!['id'],
        'name': nm, 'start_hour': sh, 'end_hour': eh,
        'sort': idx ?? _shifts.length,
      };
      if (idx == null) {
        _shifts = [..._shifts, entry];
      } else {
        final c = [..._shifts];
        c[idx] = entry;
        _shifts = c;
      }
    });
  }

  Future<void> _shiftDelete(int idx) async {
    final cur = _shifts[idx];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus shift?'),
        content: Text('${cur['name']} (${_fmtJam((cur['start_hour'] as num).toInt())}–${_fmtJam((cur['end_hour'] as num).toInt())})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (cur['id'] != null) {
        await ref.read(supabaseProvider).from('shift_templates')
            .delete().eq('id', cur['id'] as String);
      }
    } catch (e) {
      if (mounted) setState(() => _err = 'Gagal hapus: $e');
      return;
    }
    setState(() {
      final c = [..._shifts];
      c.removeAt(idx);
      _shifts = c;
    });
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
      final step = double.tryParse(_step.text.replaceAll(',', '.')) ?? 10000;
      final pval = double.tryParse(_pval.text.replaceAll(',', '.')) ?? 100;
      final modalDef = double.tryParse(
              _modalDef.text.replaceAll('.', '').replaceAll(',', '.')) ??
          0;
      await db.from('stores').update({
        'name': _name.text.trim(),
        'address': _addr.text.trim(),
        'phone': _phone.text.trim(),
        'tax_percent': tax,
        'point_step': step > 0 ? step : 10000,
        'point_value': pval < 0 ? 0 : pval,
        'default_opening_cash': modalDef < 0 ? 0 : modalDef,
      }).eq('id', s.storeId);
      // Simpan template shift per-toko (upsert per baris, bawa id kalau ada).
      try {
        for (var i = 0; i < _shifts.length; i++) {
          final t = _shifts[i];
          await db.from('shift_templates').upsert({
            if (t['id'] != null) 'id': t['id'],
            'store_id': s.storeId,
            'name': (t['name'] ?? '').toString(),
            'start_hour': (t['start_hour'] as num).toInt(),
            'end_hour': (t['end_hour'] as num).toInt(),
            'sort': i,
            'is_active': true,
          }, onConflict: 'store_id,name');
        }
      } catch (e) {
        // DB lama tanpa tabel v7: profil toko tetap kesimpan, shift
        // fallback hardcoded di layar shift.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Toko disimpan, tapi daftar shift gagal: $e (jalankan migrasi v7).')));
        }
      }
      ref.read(sessionProvider.notifier).set(PosSession(
        kind: s.kind, storeId: s.storeId,
        storeName: _name.text.trim().isEmpty ? s.storeName : _name.text.trim(),
        actorId: s.actorId, displayName: s.displayName, role: s.role));
      ref.invalidate(storeProfileProvider);
      if (mounted) {
        // Dari Lainnya (push): cukup back. Dari alur register (replace,
        // tidak bisa pop): lanjut ke /kasir.
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Toko disimpan.')));
        } else {
          Navigator.pushReplacementNamed(context, '/kasir');
        }
      }
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
        const SizedBox(height: 12),
        const Text('Aturan poin member',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(controller: _step,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Rp per 1 poin (cth: 10000)',
                    border: OutlineInputBorder())),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(controller: _pval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Nilai 1 poin Rp (cth: 100)',
                    border: OutlineInputBorder())),
          ),
        ]),
        const SizedBox(height: 16),
        const Text('Modal awal kas default (Rp)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        const Text(
          'Dipakai kalau shift terakhir belum ada kas akhir (toko baru). Kalau ada, modal ngikutin kas akhir shift terakhir.',
          style: TextStyle(fontSize: 11, color: AppColors.mfg)),
        const SizedBox(height: 6),
        TextField(controller: _modalDef,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                hintText: 'cth: 200000', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(
            child: Text('Daftar shift toko ini',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton.icon(
            onPressed: () => _shiftDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah'),
          ),
        ]),
        const SizedBox(height: 2),
        const Text(
          'Tiap toko punya jam sendiri. Shift yang lagi jalan (sesuai jam sekarang) kepilih otomatis pas buka shift.',
          style: TextStyle(fontSize: 11, color: AppColors.mfg)),
        const SizedBox(height: 6),
        if (!_shiftsLoaded)
          const Card(
              child: ListTile(
                  leading: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  title: Text('Memuat shift...'))),
        for (var i = 0; i < _shifts.length; i++)
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule, color: AppColors.pri),
              title: Text('${_shifts[i]['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${_fmtJam((_shifts[i]['start_hour'] as num).toInt())} – ${_fmtJam((_shifts[i]['end_hour'] as num).toInt())}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Ubah',
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () =>
                      _shiftDialog(cur: _shifts[i], idx: i),
                ),
                IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.red),
                  onPressed: () => _shiftDelete(i),
                ),
              ]),
            ),
          ),
        if (_shiftsLoaded && _shifts.isEmpty)
          const Card(
              child: ListTile(
                  title: Text(
                      'Belum ada shift — tambah dulu (min. 1).'))),
        if (_err != null) ...[
          const SizedBox(height: 8),
          Text(_err!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy ? const BusyLabel('Menyimpan') : const Text('Simpan & Lanjut')),
      ]),
    );
  }
}

/// Form bikin toko baru — dipakai kalau auth login VALID tapi membership
/// toko belum ada (akun lama tanpa baris membership / RPC register gagal),
/// ATAU owner nambah toko ke-2/3 (multi-outlet, arguments {'multi': true}).
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
  final _pin = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _go() async {
    final store = _store.text.trim();
    final name = _name.text.trim().isEmpty ? 'Owner' : _name.text.trim();
    final pin = _pin.text.trim();
    if (store.isEmpty) {
      setState(() => _err = 'Isi nama toko dulu.');
      return;
    }
    if (pin.length != 6 || int.tryParse(pin) == null) {
      setState(() => _err = 'PIN owner toko baru harus 6 digit angka.');
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
      // Kunci PIN owner toko baru (konsisten: semua mode owner wajib PIN).
      try {
        final hp = hashOwnerPin(sid, u.id, pin);
        await db.from('memberships').update({'pin_hash': hp})
            .eq('user_id', u.id).eq('store_id', sid);
      } catch (_) {}
      // Seed template shift default (aman double-seed via on-conflict).
      try {
        await db.from('shift_templates').upsert([
          {'store_id': sid, 'name': 'Pagi', 'start_hour': 7, 'end_hour': 15, 'sort': 0},
          {'store_id': sid, 'name': 'Siang', 'start_hour': 15, 'end_hour': 23, 'sort': 1},
          {'store_id': sid, 'name': 'Malam', 'start_hour': 23, 'end_hour': 7, 'sort': 2},
        ], onConflict: 'store_id,name');
      } catch (_) {}
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
    final args = ModalRoute.of(context)?.settings.arguments;
    // Mode multi-outlet (dari Pilih Toko > Tambah Toko): ada tombol back
    // otomatis (push) + judul beda. Mode anti-loop (dari login): tidak ada
    // back, tapi ada tombol keluar biar tidak kejebak.
    final isMulti = args is Map && args['multi'] == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(isMulti ? 'Tambah Toko Baru' : 'Buat Toko'),
        actions: [
          if (!isMulti)
            IconButton(
              tooltip: 'Keluar',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await ref.read(supabaseProvider).auth.signOut();
                ref.read(sessionProvider.notifier).clear();
                await LastSession.clearAll();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (_) => false);
                }
              },
            ),
        ],
      ),
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
        const SizedBox(height: 12),
        const Text('PIN owner toko ini (6 digit)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _pin, obscureText: true,
            keyboardType: TextInputType.number, maxLength: 6,
            decoration: const InputDecoration(
                hintText: 'cth: 123456',
                border: OutlineInputBorder())),
        if (_err != null) ...[
          const SizedBox(height: 8),
          Text(_err!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy ? null : _go,
            child: _busy ? const BusyLabel('Membuat') : const Text('Buat Toko & Masuk')),
      ]),
    );
  }
}
