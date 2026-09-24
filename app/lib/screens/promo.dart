import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/loading.dart';

// F2/Gap2 — Kelola Promo: diskon % / nominal + min belanja + periode.
// Satu promo aktif terbaik otomatis dipakai saat checkout (lihat cart_promo).
class PromoScreen extends ConsumerStatefulWidget {
  const PromoScreen({super.key});
  @override
  ConsumerState<PromoScreen> createState() => _Pr();
}

class _Pr extends ConsumerState<PromoScreen> {
  Future<List<Map<String, dynamic>>> _list(String storeId) async {
    final db = ref.read(supabaseProvider);
    final rows = await db.from('promos').select()
        .eq('store_id', storeId).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _form(String storeId, {Map<String, dynamic>? ex}) async {
    final isEdit = ex != null;
    final nCtl = TextEditingController(text: (ex?['name'] ?? '').toString());
    final vCtl = TextEditingController(text: ((ex?['value'] as num?) ?? 10).toString());
    final mCtl = TextEditingController(text: ((ex?['min_total'] as num?) ?? 0).toString());
    String kind = ((ex?['kind'] ?? 'percent') as String);
    bool aktif = (ex?['is_active'] ?? true) as bool;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isEdit ? 'Edit Promo' : 'Tambah Promo'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nCtl,
                  decoration: const InputDecoration(
                      labelText: 'Nama (cth: HEMAT10)',
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(
                    labelText: 'Jenis', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('Persen %')),
                  DropdownMenuItem(value: 'nominal', child: Text('Nominal Rp')),
                ],
                onChanged: (v) => setD(() => kind = v ?? 'percent'),
              ),
              const SizedBox(height: 12),
              TextField(controller: vCtl, keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: kind == 'percent' ? 'Besar % (cth: 10)' : 'Besar Rp (cth: 5000)',
                      border: const OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: mCtl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Min. belanja Rp (0 = tanpa min.)',
                      border: OutlineInputBorder())),
              SwitchListTile(
                title: const Text('Aktif'),
                value: aktif,
                onChanged: (v) => setD(() => aktif = v),
              ),
            ]),
          ),
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
      final db = ref.read(supabaseProvider);
      final payload = <String, dynamic>{
        'store_id': storeId,
        'name': nCtl.text.trim().toUpperCase(),
        'kind': kind,
        'value': double.tryParse(vCtl.text.replaceAll(',', '.')) ?? 0,
        'min_total': double.tryParse(mCtl.text.replaceAll(',', '.')) ?? 0,
        'is_active': aktif,
      };
      if (nCtl.text.trim().isEmpty) throw StateError('Nama wajib diisi.');
      if (!isEdit) {
        await db.from('promos').insert(payload);
      } else {
        await db.from('promos').update(payload).eq('id', ex['id'] as String);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _hapus(Map<String, dynamic> r) async {
    final y = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus promo?'),
        content: Text('${r['name']} tidak bisa dipakai lagi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (y != true) return;
    await ref.read(supabaseProvider).from('promos').delete().eq('id', r['id'] as String);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (s == null) {
      return const Scaffold(body: Center(child: Text('Belum login.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Promo & Diskon')),
      body: FutureBuilder(
        future: _list(s.storeId),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoader(label: 'Memuat promo');
          }
          if (snap.hasError) return Center(child: Text('Gagal: ${snap.error}'));
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Belum ada promo.\nBuat promo pertama di bawah.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = list[i];
              final kind = (p['kind'] ?? 'percent').toString();
              final val = (p['value'] as num?) ?? 0;
              return Card(
                child: ListTile(
                  leading: Icon(Icons.discount,
                      color: (p['is_active'] == true) ? AppColors.ok : AppColors.mfg),
                  title: Text('${p['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${kind == 'percent' ? '$val%' : rp(val)}'
                      '${((p['min_total'] as num?) ?? 0) > 0 ? ' • min. ${rp((p['min_total'] as num?) ?? 0)}' : ''}'
                      '${p['is_active'] == true ? '' : ' • nonaktif'}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit),
                        onPressed: () => _form(s.storeId, ex: p)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.dan),
                        onPressed: () => _hapus(p)),
                  ]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _form(s.storeId),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Helper promo dipakai keranjang + pembayaran.
/// Return promo aktif terbaik untuk [subtotal] (diskon terbesar), atau null.
Future<Map<String, dynamic>?> bestPromo(
    dynamic db, String storeId, double subtotal) async {
  try {
    final rows = await db.from('promos').select()
        .eq('store_id', storeId).eq('is_active', true);
    Map<String, dynamic>? best;
    double bestDisc = 0;
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final min = ((r['min_total'] as num?) ?? 0).toDouble();
      if (subtotal < min) continue;
      final kind = (r['kind'] ?? 'percent').toString();
      final val = ((r['value'] as num?) ?? 0).toDouble();
      final disc = kind == 'percent' ? subtotal * val / 100 : val;
      final capped = disc > subtotal ? subtotal : disc;
      if (capped > bestDisc) {
        bestDisc = capped;
        best = {...r, 'computed_disc': capped};
      }
    }
    return best;
  } catch (_) {
    return null;
  }
}
