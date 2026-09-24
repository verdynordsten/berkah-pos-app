import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/loading.dart';

// F5/Gap6 — Kas: catat pemasukan/pengeluaran non-jualan (belanja bahan,
// gaji, sewa...) + ringkasan arus kas hari ini. PPOB SKIP (nanti).
class KasScreen extends ConsumerStatefulWidget {
  const KasScreen({super.key});
  @override
  ConsumerState<KasScreen> createState() => _Ks();
}

class _Ks extends ConsumerState<KasScreen> {
  Future<List<Map<String, dynamic>>> _list(String storeId) async {
    final db = ref.read(supabaseProvider);
    final rows = await db.from('cash_moves').select()
        .eq('store_id', storeId)
        .order('created_at', ascending: false).limit(100);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _form(String storeId) async {
    final aCtl = TextEditingController();
    final cCtl = TextEditingController(text: 'Belanja bahan');
    final nCtl = TextEditingController();
    String kind = 'out';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Catat Kas'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              for (final k in ['out', 'in'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(k == 'out' ? 'Keluar' : 'Masuk'),
                    selected: kind == k,
                    onSelected: (_) => setD(() => kind = k),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: aCtl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Nominal Rp', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: cCtl,
                decoration: const InputDecoration(
                    labelText: 'Kategori (cth: Gaji, Sewa, Bahan)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: nCtl,
                decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    border: OutlineInputBorder())),
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
    try {
      final amt = double.tryParse(aCtl.text.replaceAll(',', '.')) ?? 0;
      if (amt <= 0) throw StateError('Nominal harus > 0.');
      await ref.read(supabaseProvider).from('cash_moves').insert({
        'store_id': storeId,
        'kind': kind,
        'category': cCtl.text.trim().isEmpty ? 'Lainnya' : cCtl.text.trim(),
        'amount': amt,
        'note': nCtl.text.trim().isEmpty ? null : nCtl.text.trim(),
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (s == null) {
      return const Scaffold(body: Center(child: Text('Belum login.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Kas & Keuangan')),
      body: FutureBuilder(
        future: _list(s.storeId),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoader(label: 'Memuat kas');
          }
          if (snap.hasError) return Center(child: Text('Gagal: ${snap.error}'));
          final list = snap.data ?? [];
          final today = DateTime.now();
          double masuk = 0, keluar = 0;
          for (final m in list) {
            final c = DateTime.tryParse((m['created_at'] ?? '').toString());
            if (c == null || c.year != today.year || c.month != today.month || c.day != today.day) {
              continue;
            }
            final a = (((m['amount'] as num?) ?? 0).toDouble());
            if ((m['kind'] ?? 'out') == 'in') {
              masuk += a;
            } else {
              keluar += a;
            }
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: _stat('Masuk hari ini', rp(masuk), AppColors.ok)),
                const SizedBox(width: 8),
                Expanded(child: _stat('Keluar hari ini', rp(keluar), AppColors.dan)),
                const SizedBox(width: 8),
                Expanded(child: _stat('Bersih', rp(masuk - keluar), AppColors.pri)),
              ]),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('Belum ada catatan kas.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = list[i];
                        final isIn = (m['kind'] ?? 'out') == 'in';
                        return Card(
                          child: ListTile(
                            leading: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isIn ? AppColors.ok : AppColors.dan),
                            title: Text('${m['category']}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${(m['note'] ?? '').toString()}\n${(m['created_at'] ?? '').toString().substring(0, 16).replaceAll('T', ' ')}'),
                            trailing: Text('${isIn ? '+' : '-'}${rp((m['amount'] as num?) ?? 0)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: isIn ? AppColors.ok : AppColors.dan)),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _form(s.storeId),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _stat(String label, String val, Color c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mfg),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 13),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
