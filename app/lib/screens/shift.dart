import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/loading.dart';

// 04 Pilih Shift — buka shift REAL: insert ke shifts (store+kasir+modal).
// Selesai -> /katalog. Shift id disimpan di provider untuk dipakai checkout.
// NOTE: shiftProvider pindah ke core/store.dart (dipakai SessionCtl reset).
//
// v7: daftar shift + jam dibaca dari shift_templates MILIK TOKO INI
// (diatur owner di Setup Toko), BUKAN hardcoded global. Shift yang lagi
// jalan sesuai jam sekarang kepilih otomatis. Modal awal ngikutin
// closing_cash shift terakhir toko ini (fallback: default_opening_cash
// toko, fallback akhir: 0). Kasir tetap boleh ubah manual.

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});
  @override
  ConsumerState<ShiftScreen> createState() => _Sh();
}

class _ShiftT {
  final String name;
  final int startH, endH;
  const _ShiftT(this.name, this.startH, this.endH);
  String get jam =>
      '${startH.toString().padLeft(2, '0')}:00–${endH.toString().padLeft(2, '0')}:00';
  String get label => '$name ($jam)';

  /// True kalau jam [h] (0-23) masuk rentang shift ini.
  /// endH <= startH = lewat tengah malam (cth 23→07).
  bool contains(int h) {
    if (startH == endH) return true; // 24 jam
    if (endH > startH) return h >= startH && h < endH;
    return h >= startH || h < endH;
  }
}

const _fallbackShifts = [
  _ShiftT('Pagi', 7, 15),
  _ShiftT('Siang', 15, 23),
  _ShiftT('Malam', 23, 7),
];

class _Sh extends ConsumerState<ShiftScreen> {
  List<_ShiftT> _opts = _fallbackShifts;
  String? label;
  final _modal = TextEditingController();
  bool busy = false;
  bool loading = true;
  String? err;
  String? modalInfo; // dari mana angka modal (kas terakhir / default toko)

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final s = ref.read(sessionProvider);
    if (s == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      final db = ref.read(supabaseProvider);
      // 1. Template shift milik toko ini.
      List<_ShiftT> opts = _fallbackShifts;
      try {
        final trows = await db.from('shift_templates').select()
            .eq('store_id', s.storeId)
            .eq('is_active', true)
            .order('sort');
        final list = (trows as List).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) {
          opts = list.map((t) => _ShiftT(
            (t['name'] ?? '').toString(),
            ((t['start_hour'] as num?) ?? 7).toInt(),
            ((t['end_hour'] as num?) ?? 15).toInt(),
          )).toList();
        }
      } catch (_) {}
      // 2. Modal: closing_cash shift terakhir toko ini dulu.
      double? modal;
      String? info;
      try {
        final last = await db.from('shifts').select('closing_cash')
            .eq('store_id', s.storeId)
            .not('closed_at', 'is', null)
            .order('closed_at', ascending: false)
            .limit(1).maybeSingle();
        final c = last == null
            ? null
            : (((last as Map)['closing_cash'] as num?)?.toDouble());
        if (c != null) {
          modal = c;
          info = 'Ngikutin kas akhir shift terakhir (${rp(c)})';
        }
      } catch (_) {}
      // 3. Fallback: default_opening_cash toko.
      if (modal == null) {
        try {
          final store = await db.from('stores')
              .select('default_opening_cash')
              .eq('id', s.storeId).maybeSingle();
          final d = store == null
              ? null
              : (((store as Map)['default_opening_cash'] as num?)?.toDouble());
          if (d != null && d > 0) {
            modal = d;
            info = 'Modal default toko (${rp(d)}) — belum ada kas akhir';
          }
        } catch (_) {}
      }
      modal ??= 0;
      // 4. Auto-pilih shift yang lagi jalan sesuai jam sekarang.
      final nowH = DateTime.now().hour;
      var pick = opts.firstWhere((o) => o.contains(nowH),
          orElse: () => opts.first);
      if (mounted) {
        setState(() {
          _opts = opts;
          label = pick.label;
          _modal.text = modal!.toStringAsFixed(0);
          modalInfo = info;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          err = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> _start() async {
    final s = ref.read(sessionProvider);
    if (s == null) {
      setState(() => err = 'Belum login.');
      return;
    }
    final pick = label;
    if (pick == null) {
      setState(() => err = 'Pilih shift dulu.');
      return;
    }
    setState(() { busy = true; err = null; });
    try {
      final db = ref.read(supabaseProvider);
      final modal = double.tryParse(
              _modal.text.replaceAll('.', '').replaceAll(',', '.')) ??
          0;
      final row = await db.from('shifts').insert({
        'store_id': s.storeId,
        'cashier_name': s.displayName,
        'label': pick,
        'opening_cash': modal,
        if (s.kind == LoginKind.owner) 'user_id': s.actorId
        else 'staff_id': s.actorId,
      }).select().single();
      ref.read(shiftProvider.notifier).state =
          (row as Map).cast<String, dynamic>();
      if (mounted) Navigator.pushReplacementNamed(context, '/katalog');
    } catch (e) {
      setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Shift'),
        actions: [
          IconButton(
            tooltip: 'Ganti pengguna',
            icon: const Icon(Icons.switch_account),
            onPressed: () => Navigator.pushNamed(context, '/pilih'),
          ),
        ],
      ),
      body: loading
          ? const AppLoader(label: 'Memuat shift toko')
          : ListView(padding: const EdgeInsets.all(16), children: [
        if (s != null)
          Text('Halo, ${s.displayName} — ${s.storeName}',
              style: const TextStyle(color: AppColors.mfg)),
        const SizedBox(height: 8),
        ..._opts.map((o) => Card(
              child: RadioGroup<String>(
                groupValue: label,
                onChanged: (v) => setState(() => label = v!),
                child: RadioListTile<String>(
                  value: o.label,
                  title: Text(o.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Jam ${o.jam}'),
                ),
              ),
            )),
        const SizedBox(height: 12),
        const Text('Modal awal kas (Rp)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        if (modalInfo != null) ...[
          const SizedBox(height: 2),
          Text(modalInfo!,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.mfg)),
        ],
        const SizedBox(height: 6),
        TextField(
            controller: _modal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                hintText: 'cth: 200000', border: OutlineInputBorder())),
        if (err != null) ...[
          const SizedBox(height: 8),
          Text(err!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
            onPressed: busy ? null : _start,
            child: busy ? const BusyLabel('Membuka') : const Text('Mulai Shift')),
      ]),
    );
  }
}
