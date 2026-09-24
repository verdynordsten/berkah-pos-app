import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';

// NOTE: customerProvider pindah ke core/store.dart (dipakai SessionCtl reset).
// 08 Pelanggan — list real dari DB + search + tambah + pilih/skip.
class PelangganScreen extends ConsumerStatefulWidget {
  const PelangganScreen({super.key});
  @override
  ConsumerState<PelangganScreen> createState() => _Pl();
}

class _Pl extends ConsumerState<PelangganScreen> {
  String q = '';

  Future<List<Map<String, dynamic>>> _list(String storeId) async {
    final db = ref.read(supabaseProvider);
    final rows = await db.from('customers').select()
        .eq('store_id', storeId).order('name').limit(100);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _add(String storeId) async {
    final nCtl = TextEditingController();
    final pCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Pelanggan'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nCtl,
              decoration: const InputDecoration(
                  labelText: 'Nama', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: pCtl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'No. HP (opsional)',
                  border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true || nCtl.text.trim().isEmpty) return;
    try {
      final db = ref.read(supabaseProvider);
      await db.from('customers').insert({
        'store_id': storeId,
        'name': nCtl.text.trim(),
        'phone': pCtl.text.trim().isEmpty ? null : pCtl.text.trim(),
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  void _pick(Map<String, dynamic>? c) {
    ref.read(customerProvider.notifier).state = c;
    // Teruskan paket promo dari keranjang (Map) ke pembayaran.
    // Fallback: double total lama -> dibungkus jadi Map.
    final args = ModalRoute.of(context)?.settings.arguments;
    final pack = args is Map ? args : {'total': (args is double ? args : 0.0)};
    Navigator.pushNamed(context, '/tunai', arguments: pack);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (s == null) {
      return const Scaffold(
          body: Center(child: Text('Belum login.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Pelanggan')),
      body: FutureBuilder(
        future: _list(s.storeId),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Gagal: ${snap.error}'));
          }
          final all = snap.data ?? [];
          final list = all.where((c) {
            final n = ((c['name'] as String?) ?? '').toLowerCase();
            final p = ((c['phone'] as String?) ?? '').toLowerCase();
            final qq = q.toLowerCase();
            return qq.isEmpty || n.contains(qq) || p.contains(qq);
          }).toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(
                    hintText: 'Cari nama / nomor HP...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            ...list.map((c) => Card(
                  child: ListTile(
                    leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: AppColors.mut,
                            borderRadius:
                                BorderRadius.circular(12)),
                        child: const Icon(Icons.person,
                            color: AppColors.pri)),
                    title: Text(
                        (c['name'] as String?) ?? '-',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    subtitle: (c['phone'] as String?) != null
                        ? Text(c['phone'] as String)
                        : null,
                    trailing:
                        const Icon(Icons.chevron_right),
                    onTap: () => _pick(c),
                  ),
                )),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _add(s.storeId),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Pelanggan')),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: () => _pick(null),
                child: const Text('Lanjut Tanpa Member')),
          ]);
        },
      ),
    );
  }
}
