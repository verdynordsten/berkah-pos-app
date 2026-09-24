import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/store.dart';

// 05 Katalog — grid produk + search + tab bar (inti kasir)
class KatalogScreen extends ConsumerStatefulWidget {
  const KatalogScreen({super.key});
  @override
  ConsumerState<KatalogScreen> createState() => _K();
}

class _K extends ConsumerState<KatalogScreen> {
  String cat = 'Semua';
  String q = '';

  @override
  Widget build(BuildContext context) {
    final prods = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);
    final catsAsync = ref.watch(categoriesProvider);
    final storeAsync = ref.watch(storeProfileProvider);
    final session = ref.watch(sessionProvider);
    final cats = ['Semua',
      ...((catsAsync.valueOrNull ?? [])
          .map((c) => (c['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty && n != 'Semua'))];
    if (!cats.contains(cat)) cat = 'Semua';
    final catIdOf = <String, String>{};
    for (final c in (catsAsync.valueOrNull ?? [])) {
      catIdOf[(c['name'] as String?) ?? ''] = (c['id'] as String?) ?? '';
    }
    final storeName = (storeAsync.valueOrNull?['name'] as String?)
        ?? session?.storeName ?? 'Toko';
    final cashierLine = session == null
        ? ''
        : '${session.displayName}${session.isOwner ? ' — Owner' : ''}';
    return Scaffold(
      appBar: AppBar(
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(storeName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(cashierLine,
                  style: const TextStyle(fontSize: 11, color: AppColors.mfg)),
            ]),
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: CircleAvatar(
              backgroundColor: AppColors.mut,
              child: Icon(Icons.store, color: AppColors.pri)),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(
              hintText: 'Cari produk / scan barcode...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: AppColors.mut,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(cats[i]),
              selected: cat == cats[i],
              onSelected: (_) => setState(() => cat = cats[i]),
            ),
          ),
        ),
        Expanded(
          child: prods.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text(
                    'Gagal muat. Cek koneksi / .env Supabase.\n$e',
                    textAlign: TextAlign.center)),
            data: (list) {
              final f = list
                  .where((p) =>
                      (cat == 'Semua' ||
                          p.categoryId == (catIdOf[cat] ?? '__')) &&
                      (q.isEmpty ||
                          p.name
                              .toLowerCase()
                              .contains(q.toLowerCase())))
                  .toList();
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.95,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: f.length,
                itemBuilder: (_, i) {
                  final p = f[i];
                  return Card(
                    child: InkWell(
                      onTap: () {
                        ref.read(cartProvider.notifier).add(p);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('${p.name} +1'),
                                duration:
                                    const Duration(milliseconds: 600)));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: AppColors.mut,
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  child: const Center(
                                      child: Icon(Icons.inventory_2,
                                          color: AppColors.mfg)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(p.name,
                                  maxLines: 1,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(rp(p.price),
                                  style: const TextStyle(
                                      color: AppColors.pri,
                                      fontWeight: FontWeight.w700)),
                              Text('Stok ${p.stock}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mfg)),
                            ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                color: AppColors.card,
                border:
                    Border(top: BorderSide(color: AppColors.line))),
            child: Column(children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        '${ref.read(cartProvider.notifier).count} item',
                        style:
                            const TextStyle(color: AppColors.mfg)),
                    Text(
                        'Total ${rp(ref.read(cartProvider.notifier).subtotal)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                  ]),
              const SizedBox(height: 8),
              FilledButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/keranjang'),
                  child: const Text('Lihat Keranjang')),
            ]),
          ),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) Navigator.pushNamed(context, '/keranjang');
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'Keranjang'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt), label: 'Riwayat'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Lainnya'),
        ],
      ),
    );
  }
}
