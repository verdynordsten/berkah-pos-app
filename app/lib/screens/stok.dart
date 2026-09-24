import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/loading.dart';

// F3/Gap3 — Stok: tab Menipis (stok <= ambang) + tab Riwayat (stock_moves)
// + Pembelian (stok masuk dari supplier, otomatis nambah stok).
class StokScreen extends ConsumerStatefulWidget {
  const StokScreen({super.key});
  @override
  ConsumerState<StokScreen> createState() => _St();
}

class _St extends ConsumerState<StokScreen> {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (s == null) {
      return const Scaffold(body: Center(child: Text('Belum login.')));
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelola Stok'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Menipis'),
            Tab(text: 'Riwayat'),
            Tab(text: 'Beli'),
          ]),
        ),
        body: TabBarView(children: [
          _Menipis(storeId: s.storeId),
          _Riwayat(storeId: s.storeId),
          _Beli(storeId: s.storeId),
        ]),
      ),
    );
  }
}

class _Menipis extends ConsumerWidget {
  final String storeId;
  const _Menipis({required this.storeId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.watch(supabaseProvider).from('products').select()
          .eq('store_id', storeId).eq('is_active', true).order('stock'),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppLoader(label: 'Memuat stok');
        }
        if (snap.hasError) return Center(child: Text('Gagal: ${snap.error}'));
        final all = ((snap.data as List?) ?? []).cast<Map<String, dynamic>>();
        final low = all.where((p) =>
            (((p['stock'] as num?) ?? 0).toInt()) <=
            (((p['low_stock_at'] as num?) ?? 5).toInt())).toList();
        if (low.isEmpty) {
          return const Center(child: Text('Semua stok aman.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: low.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final p = low[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.warning, color: AppColors.dan),
                title: Text('${p['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    'Sisa ${p['stock']} (ambang ${p['low_stock_at'] ?? 5})'),
                trailing: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/detail',
                      arguments: p['id'] as String),
                  child: const Text('Atur'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Riwayat extends ConsumerWidget {
  final String storeId;
  const _Riwayat({required this.storeId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.watch(supabaseProvider).from('stock_moves').select()
          .eq('store_id', storeId)
          .order('created_at', ascending: false).limit(100),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppLoader(label: 'Memuat riwayat');
        }
        if (snap.hasError) return Center(child: Text('Gagal: ${snap.error}'));
        final list = ((snap.data as List?) ?? []).cast<Map<String, dynamic>>();
        if (list.isEmpty) return const Center(child: Text('Belum ada mutasi stok.'));
        return _MoveList(moves: list);
      },
    );
  }
}

class _MoveList extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> moves;
  const _MoveList({required this.moves});
  @override
  ConsumerState<_MoveList> createState() => _ML();
}

class _ML extends ConsumerState<_MoveList> {
  Map<String, String> names = {};
  @override
  void initState() {
    super.initState();
    _names();
  }

  Future<void> _names() async {
    try {
      final db = ref.read(supabaseProvider);
      final ids = widget.moves
          .map((m) => m['product_id']).whereType<String>().toSet().toList();
      for (var i = 0; i < ids.length; i += 30) {
        final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
        final rows = await db.from('products').select('id,name').inFilter('id', chunk);
        for (final r in (rows as List).cast<Map<String, dynamic>>()) {
          names[(r['id'] ?? '').toString()] = (r['name'] ?? '-').toString();
        }
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: widget.moves.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final m = widget.moves[i];
        final qty = ((m['qty'] as num?) ?? 0).toInt();
        final masuk = qty >= 0;
        return Card(
          child: ListTile(
            leading: Icon(masuk ? Icons.arrow_downward : Icons.arrow_upward,
                color: masuk ? AppColors.ok : AppColors.dan),
            title: Text(names[(m['product_id'] ?? '').toString()] ?? '...',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${(m['reason'] ?? '').toString()}${(m['note'] ?? '').toString().isNotEmpty ? ' — ${m['note']}' : ''}\n${(m['created_at'] ?? '').toString().substring(0, 16).replaceAll('T', ' ')}'),
            trailing: Text('${masuk ? '+' : ''}$qty',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: masuk ? AppColors.ok : AppColors.dan)),
          ),
        );
      },
    );
  }
}

// Form pembelian: pilih produk + qty + harga modal + supplier -> purchase +
// purchase_items + stock_moves(reason=buy) + products.stock += qty.
class _Beli extends ConsumerStatefulWidget {
  final String storeId;
  const _Beli({required this.storeId});
  @override
  ConsumerState<_Beli> createState() => _Bl();
}

class _Bl extends ConsumerState<_Beli> {
  String? prodId;
  String prodName = '';
  final _qty = TextEditingController(text: '10');
  final _cost = TextEditingController(text: '0');
  final _sup = TextEditingController();
  bool busy = false;

  Future<List<Map<String, dynamic>>> _prods() async {
    final db = ref.read(supabaseProvider);
    final rows = await db.from('products').select('id,name,stock')
        .eq('store_id', widget.storeId).eq('is_active', true).order('name');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _save() async {
    if (prodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih produk dulu.')));
      return;
    }
    final qty = int.tryParse(_qty.text) ?? 0;
    final cost = double.tryParse(_cost.text.replaceAll(',', '.')) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Qty harus > 0.')));
      return;
    }
    setState(() => busy = true);
    try {
      final db = ref.read(supabaseProvider);
      final pur = await db.from('purchases').insert({
        'store_id': widget.storeId,
        'supplier': _sup.text.trim().isEmpty ? '-' : _sup.text.trim(),
        'total': qty * cost,
      }).select('id').single();
      await db.from('purchase_items').insert({
        'purchase_id': pur['id'],
        'product_id': prodId,
        'name': prodName,
        'qty': qty, 'cost': cost, 'line_total': qty * cost,
      });
      await db.from('stock_moves').insert({
        'store_id': widget.storeId, 'product_id': prodId,
        'qty': qty, 'reason': 'buy',
        'note': _sup.text.trim().isEmpty ? null : _sup.text.trim(),
      });
      final cur = await db.from('products').select('stock')
          .eq('id', prodId!).single();
      await db.from('products')
          .update({'stock': (((cur['stock'] as num?) ?? 0).toInt()) + qty})
          .eq('id', prodId!);
      ref.invalidate(productsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$prodName +$qty masuk.')));
        setState(() { _qty.text = '10'; _cost.text = '0'; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _prods(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppLoader(label: 'Memuat produk');
        }
        if (snap.hasError) return Center(child: Text('Gagal: ${snap.error}'));
        final list = snap.data ?? [];
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Produk', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: prodId,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final p in list)
                DropdownMenuItem(
                    value: (p['id'] ?? '').toString(),
                    child: Text('${p['name']} (stok ${p['stock']})')),
            ],
            onChanged: (v) {
              final f = list.firstWhere((p) => (p['id'] ?? '').toString() == v,
                  orElse: () => <String, dynamic>{});
              setState(() {
                prodId = v;
                prodName = (f['name'] ?? '').toString();
              });
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(controller: _qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Qty masuk', border: OutlineInputBorder())),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(controller: _cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Harga modal/pcs', border: OutlineInputBorder())),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _sup,
              decoration: const InputDecoration(
                  labelText: 'Supplier (opsional)',
                  border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: busy ? null : _save,
              child: busy
                  ? const BusyLabel('Menyimpan')
                  : const Text('Simpan Pembelian')),
        ]);
      },
    );
  }
}
