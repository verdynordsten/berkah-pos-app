import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'produk_form.dart';

// 06 Detail Produk — data real dari products by id (arguments).
// Kasir: tambah ke keranjang. Owner: edit + nonaktifkan.
class DetailScreen extends ConsumerWidget {
  const DetailScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    final session = ref.watch(sessionProvider);
    if (id == null) {
      return const Scaffold(
          body: Center(child: Text('Produk tidak ditemukan.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Produk')),
      body: FutureBuilder(
        future:
            ref.watch(supabaseProvider).from('products').select().eq('id', id).maybeSingle(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(
                child: Text('Gagal: ${snap.error ?? 'tidak ada'}'));
          }
          final p = (snap.data as Map).cast<String, dynamic>();
          final prod = Product.fromMap(p);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
                height: 200,
                decoration: BoxDecoration(
                    color: AppColors.mut,
                    borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: ((p['photo_url'] as String?)?.isNotEmpty == true)
                    ? Image.network((p['photo_url'] as String?)!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.inventory_2,
                                size: 64, color: AppColors.mfg)))
                    : const Center(
                        child: Icon(Icons.inventory_2,
                            size: 64, color: AppColors.mfg))),
            const SizedBox(height: 10),
            Text((p['name'] as String?) ?? '-',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            Text(
                'Stok ${(p['stock'] as int?) ?? 0}${(p['barcode'] as String?) != null ? ' — ${p['barcode']}' : ''}',
                style: const TextStyle(color: AppColors.mfg)),
            Text(rp((p['price'] as num?) ?? 0),
                style: const TextStyle(
                    fontSize: 24,
                    color: AppColors.pri,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: () {
                  ref.read(cartProvider.notifier).add(prod);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('${prod.name} +1'),
                          duration:
                              const Duration(milliseconds: 600)));
                  Navigator.pop(context);
                },
                child: const Text('Tambah ke Keranjang')),
            if (session?.canManageMenu == true) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: () async {
                    final ok = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ProdukFormScreen(existing: p)),
                    );
                    if (ok == true && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Edit Produk')),
              TextButton(
                  onPressed: () async {
                    final y = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Nonaktifkan produk?'),
                        content: const Text(
                            'Produk hilang dari katalog tapi riwayat tetap ada.'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Batal')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              child: const Text('Ya')),
                        ],
                      ),
                    );
                    if (y != true) return;
                    try {
                      await ref
                          .read(supabaseProvider)
                          .from('products')
                          .update({'is_active': false})
                          .eq('id', id);
                      ref.invalidate(productsProvider);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal: $e')));
                      }
                    }
                  },
                  child: const Text('Nonaktifkan',
                      style: TextStyle(color: AppColors.dan))),
            ],
          ]);
        },
      ),
    );
  }
}
