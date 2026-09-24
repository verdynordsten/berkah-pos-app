import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/loading.dart';

// F1/Gap1+Gap4 — Laporan: omzet (hari/minggu/bulan), grafik batang 7 hari,
// top produk, per metode bayar, rekap per kasir + estimasi komisi.
class LaporanScreen extends ConsumerStatefulWidget {
  const LaporanScreen({super.key});
  @override
  ConsumerState<LaporanScreen> createState() => _Lp();
}

class _Lp extends ConsumerState<LaporanScreen> {
  int range = 7; // 1 | 7 | 30 hari
  bool loading = true;
  String? err;
  List<Map<String, dynamic>> trx = [];
  List<Map<String, dynamic>> items = [];
  Map<String, double> komisi = {}; // nama kasir -> % komisi

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      final s = ref.read(sessionProvider);
      if (s == null) throw StateError('Belum login.');
      final db = ref.read(supabaseProvider);
      final since = DateTime.now().subtract(Duration(days: range - 1));
      final rows = await db.from('transactions').select()
          .eq('store_id', s.storeId)
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: false).limit(2000);
      trx = (rows as List).cast<Map<String, dynamic>>();
      final ids = trx.map((t) => t['id'] as String).toList();
      items = [];
      // Ambil item per transaksi (dibatasi 60 trx terbaru biar ringan).
      for (final id in ids.take(60)) {
        final r = await db.from('transaction_items').select().eq('transaction_id', id);
        items.addAll((r as List).cast<Map<String, dynamic>>());
      }
      // Komisi kasir: dari staff + membership toko ini.
      komisi = {};
      try {
        final st = await db.from('staff').select('name,commission_pct')
            .eq('store_id', s.storeId).eq('is_active', true);
        for (final r in (st as List).cast<Map<String, dynamic>>()) {
          komisi[(r['name'] ?? '').toString().toLowerCase()] =
              ((r['commission_pct'] as num?) ?? 0).toDouble();
        }
        final mb = await db.from('memberships').select('display_name,commission_pct')
            .eq('store_id', s.storeId).eq('is_active', true);
        for (final r in (mb as List).cast<Map<String, dynamic>>()) {
          komisi[(r['display_name'] ?? '').toString().toLowerCase()] =
              ((r['commission_pct'] as num?) ?? 0).toDouble();
        }
      } catch (_) {}
    } catch (e) {
      err = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Usaha')),
      body: loading
          ? const AppLoader(label: 'Menghitung laporan')
          : err != null
              ? Center(child: Text('Gagal: $err'))
              : _body(),
    );
  }

  Widget _body() {
    final omzet = trx.fold<double>(0, (a, t) => a + (((t['total'] as num?) ?? 0).toDouble()));
    // Grafik 7 slot harian.
    final days = List.generate(range == 1 ? 1 : 7, (i) {
      final d = DateTime.now().subtract(Duration(days: (range == 1 ? 0 : 6) - i));
      return DateTime(d.year, d.month, d.day);
    });
    final perDay = <String, double>{for (final d in days) _k(d): 0};
    for (final t in trx) {
      final c = DateTime.tryParse((t['created_at'] ?? '').toString());
      if (c == null) continue;
      final k = _k(DateTime(c.year, c.month, c.day));
      if (perDay.containsKey(k)) {
        perDay[k] = perDay[k]! + (((t['total'] as num?) ?? 0).toDouble());
      }
    }
    final maxV = perDay.values.fold<double>(1, (a, b) => b > a ? b : a);
    // Top produk dari items.
    final prodAgg = <String, Map<String, dynamic>>{};
    for (final it in items) {
      final n = (it['name'] ?? '-').toString();
      final e = prodAgg.putIfAbsent(n, () => {'qty': 0, 'total': 0.0});
      e['qty'] = (e['qty'] as int) + (((it['qty'] as num?) ?? 0).toInt());
      e['total'] = (e['total'] as double) + (((it['line_total'] as num?) ?? 0).toDouble());
    }
    final top = prodAgg.entries.toList()
      ..sort((a, b) => (b.value['qty'] as int).compareTo(a.value['qty'] as int));
    // Per metode bayar.
    final method = <String, double>{};
    for (final t in trx) {
      final m = (t['pay_method'] ?? 'Tunai').toString();
      method[m] = (method[m] ?? 0) + (((t['total'] as num?) ?? 0).toDouble());
    }
    // Per kasir: nama kasir disimpan di shift? fallback: join via shift_id tidak
    // ada nama -> pakai customer? Kita pakai kolom kasir dari shifts bila ada.
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Pilihan rentang.
      Row(children: [
        for (final r in [1, 7, 30])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(r == 1 ? 'Hari ini' : '$r hari'),
              selected: range == r,
              onSelected: (_) { setState(() => range = r); _load(); },
            ),
          ),
      ]),
      const SizedBox(height: 12),
      // Kartu ringkasan.
      Row(children: [
        Expanded(child: _stat('Omzet', rp(omzet), AppColors.pri)),
        const SizedBox(width: 8),
        Expanded(child: _stat('Transaksi', '${trx.length}', AppColors.ok)),
      ]),
      const SizedBox(height: 16),
      const Text('Grafik omzet harian',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in days)
                Expanded(
                  child: Column(children: [
                    Container(
                      height: 90 * (perDay[_k(d)]! / maxV) + 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                          color: AppColors.pri,
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    const SizedBox(height: 4),
                    Text('${d.day}/${d.month}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.mfg)),
                  ]),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Text('Produk terlaris', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (top.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Belum ada item.')))
      else
        for (final e in top.take(5))
          Card(
            child: ListTile(
              leading: const Icon(Icons.star, color: AppColors.warn),
              title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${e.value['qty']} terjual'),
              trailing: Text(rp(e.value['total'] as double),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
      const SizedBox(height: 16),
      const Text('Per metode bayar',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in method.entries)
          Chip(label: Text('${m.key}: ${rp(m.value)}')),
      ]),
      const SizedBox(height: 16),
      _KasirRekap(trx: trx, komisi: komisi),
    ]);
  }

  Widget _stat(String label, String val, Color c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.mfg, fontSize: 12)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
        ]),
      ),
    );
  }

  String _k(DateTime d) => '${d.year}-${d.month}-${d.day}';
}

// Rekap per kasir: butuh nama kasir per transaksi. Kita baca dari shifts
// (cashier_name) via shift_id. Estimasi komisi = omzet kasir x %.
class _KasirRekap extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> trx;
  final Map<String, double> komisi;
  const _KasirRekap({required this.trx, required this.komisi});
  @override
  ConsumerState<_KasirRekap> createState() => _KR();
}

class _KR extends ConsumerState<_KasirRekap> {
  Map<String, String> shiftKasir = {}; // shift_id -> cashier_name
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = ref.read(sessionProvider);
      if (s == null) return;
      final db = ref.read(supabaseProvider);
      final ids = widget.trx.map((t) => t['shift_id']).whereType<String>().toSet().toList();
      for (final chunk in _chunks(ids, 30)) {
        final rows = await db.from('shifts').select('id,cashier_name')
            .inFilter('id', chunk);
        for (final r in (rows as List).cast<Map<String, dynamic>>()) {
          shiftKasir[(r['id'] ?? '').toString()] = (r['cashier_name'] ?? '-').toString();
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const AppLoader(label: 'Menghitung rekap kasir');
    final agg = <String, Map<String, dynamic>>{};
    for (final t in widget.trx) {
      final sid = (t['shift_id'] ?? '').toString();
      final name = shiftKasir[sid] ?? 'Tanpa shift';
      final e = agg.putIfAbsent(name, () => {'n': 0, 'total': 0.0});
      e['n'] = (e['n'] as int) + 1;
      e['total'] = (e['total'] as double) + (((t['total'] as num?) ?? 0).toDouble());
    }
    final list = agg.entries.toList()
      ..sort((a, b) => (b.value['total'] as double).compareTo(a.value['total'] as double));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Rekap per kasir + komisi',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (list.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Belum ada data.'))),
      for (final e in list)
        Card(
          child: ListTile(
            leading: const Icon(Icons.person, color: AppColors.pri),
            title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${e.value['n']} transaksi — komisi ${(widget.komisi[e.key.toLowerCase()] ?? 0).toStringAsFixed(1)}%'),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(rp(e.value['total'] as double),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('+${rp((e.value['total'] as double) * (widget.komisi[e.key.toLowerCase()] ?? 0) / 100)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.ok)),
            ]),
          ),
        ),
      const SizedBox(height: 4),
      const Text('Atur % komisi tiap kasir di menu Kelola Kasir.',
          style: TextStyle(fontSize: 12, color: AppColors.mfg)),
    ]);
  }

  List<List<String>> _chunks(List<String> l, int n) {
    final out = <List<String>>[];
    for (var i = 0; i < l.length; i += n) {
      out.add(l.sublist(i, i + n > l.length ? l.length : i + n));
    }
    return out;
  }
}
