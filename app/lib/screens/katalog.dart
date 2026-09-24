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
        : '${session.displayName} — ${session.roleLabel}';
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
              if (f.isEmpty) {
                final canMenu = session?.canManageMenu == true;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 96, height: 96,
                            decoration: BoxDecoration(
                                color: AppColors.mut,
                                borderRadius:
                                    BorderRadius.circular(28)),
                            child: const Icon(
                                Icons.coffee,
                                size: 48,
                                color: AppColors.pri),
                          ),
                          const SizedBox(height: 16),
                          Text(
                              q.isNotEmpty
                                  ? 'Tidak ketemu "$q"'
                                  : 'Katalog masih kosong',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                              q.isNotEmpty
                                  ? 'Coba kata lain atau kategori lain.'
                                  : canMenu
                                      ? 'Tambah menu pertama biar bisa jualan.'
                                      : 'Minta owner / admin tambah produk dulu.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.mfg)),
                          if (canMenu &&
                              q.isEmpty) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context,
                                      '/produk_baru'),
                              icon: const Icon(Icons.add),
                              label: const Text(
                                  'Tambah Menu Pertama'),
                            ),
                          ],
                        ]),
                  ),
                );
              }
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
                  final out = p.stock <= 0;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16)),
                    child: InkWell(
                      // Tap = tambah cepat (dibatasi stok). Tahan = detail / edit.
                      onTap: out
                          ? null
                          : () {
                              final ok = ref
                                  .read(cartProvider.notifier)
                                  .add(p);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                      content: Text(ok
                                          ? '${p.name} +1'
                                          : 'Stok ${p.name} cuma ${p.stock}'),
                                      duration: const Duration(
                                          milliseconds:
                                              600)));
                            },
                      onLongPress: () => Navigator.pushNamed(
                          context, '/detail',
                          arguments: p.id),
                      child: Opacity(
                        opacity: out ? 0.55 : 1,
                        child: Padding(
                          padding:
                              const EdgeInsets.all(10),
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(children: [
                                    Container(
                                      decoration:
                                          BoxDecoration(
                                              color: AppColors
                                                  .mut,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      12)),
                                      clipBehavior: Clip.antiAlias,
                                      child: (p.photoUrl?.isNotEmpty ==
                                              true)
                                          ? Image.network(
                                              p.photoUrl!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder: (_, __,
                                                      ___) =>
                                                  const Center(
                                                      child: Icon(
                                                          Icons
                                                              .coffee,
                                                          size: 40,
                                                          color:
                                                              AppColors
                                                                  .pri)),
                                            )
                                          : const Center(
                                              child: Icon(
                                                  Icons
                                                      .coffee,
                                                  size: 40,
                                                  color: AppColors
                                                      .pri)),
                                    ),
                                    if (out)
                                      Positioned(
                                        top: 6, left: 6,
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal:
                                                      8,
                                                  vertical:
                                                      3),
                                          decoration: BoxDecoration(
                                              color:
                                                  AppColors.dan,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8)),
                                          child: const Text(
                                              'HABIS',
                                              style: TextStyle(
                                                  fontSize:
                                                      10,
                                                  fontWeight:
                                                      FontWeight
                                                          .w700,
                                                  color: Colors
                                                      .white)),
                                        ),
                                      ),
                                  ]),
                                ),
                                const SizedBox(height: 8),
                                Text(p.name,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w700,
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(rp(p.price),
                                    style: const TextStyle(
                                        color: AppColors.pri,
                                        fontWeight:
                                            FontWeight.w800,
                                        fontSize: 15)),
                                Text(
                                    out
                                        ? 'Stok habis'
                                        : 'Stok ${p.stock}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: out
                                            ? AppColors.dan
                                            : AppColors.mfg,
                                        fontWeight: out
                                            ? FontWeight.w700
                                            : FontWeight.w400)),
                              ]),
                        ),
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

      // Owner/Admin: tombol + tambah produk. Kasir: disembunyikan.
      floatingActionButton: session?.canManageMenu == true
          ? FloatingActionButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/produk_baru'),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor: AppColors.pri,
        unselectedItemColor: AppColors.mfg,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (i) {
          if (i == 1) {
            Navigator.pushNamed(context, '/keranjang');
          } else if (i == 2) {
            Navigator.pushNamed(context, '/riwayat');
          } else if (i == 3) {
            Navigator.pushNamed(context, '/lainnya');
          }
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
