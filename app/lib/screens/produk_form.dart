import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';

// 05b Tambah/Edit Produk (owner) — nama + kategori + harga + stok + barcode.
// Simpan -> products (store aktif) -> kembali + refresh katalog.
class ProdukFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  const ProdukFormScreen({super.key, this.existing});
  @override
  ConsumerState<ProdukFormScreen> createState() => _PF();
}

class _PF extends ConsumerState<ProdukFormScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _barcode = TextEditingController();
  String? _catId;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = (e['name'] as String?) ?? '';
      _price.text = '${(e['price'] as num?) ?? 0}';
      _stock.text = '${(e['stock'] as int?) ?? 0}';
      _barcode.text = (e['barcode'] as String?) ?? '';
      _catId = e['category_id'] as String?;
    }
  }

  Future<void> _save() async {
    final s = ref.read(sessionProvider);
    if (s == null) return;
    // KUNCI: kasir tidak boleh tambah/edit produk walau nekat buka route.
    if (!s.canManageMenu) {
      setState(() => _err = 'Hanya Owner / Admin yang boleh kelola menu.');
      return;
    }
    final name = _name.text.trim();
    final price = double.tryParse(
            _price.text.replaceAll('.', '').replaceAll(',', '.')) ??
        -1;
    final stock =
        int.tryParse(_stock.text.replaceAll('.', '')) ?? -1;
    if (name.isEmpty || price < 0 || stock < 0) {
      setState(() => _err = 'Nama wajib isi, harga & stok harus angka.');
      return;
    }
    setState(() { _busy = true; _err = null; });
    try {
      final db = ref.read(supabaseProvider);
      final payload = {
        'store_id': s.storeId,
        'category_id': _catId,
        'name': name,
        'price': price,
        'stock': stock,
        'barcode': _barcode.text.trim().isEmpty
            ? null
            : _barcode.text.trim(),
        'is_active': true,
      };
      if (widget.existing == null) {
        await db.from('products').insert(payload);
      } else {
        await db.from('products')
            .update(payload)
            .eq('id', widget.existing!['id'] as String);
      }
      ref.invalidate(productsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    final cats = catsAsync.valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.existing == null ? 'Tambah Produk' : 'Edit Produk')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Nama produk',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _name,
            decoration: const InputDecoration(
                hintText: 'cth: Kopi Susu Gula Aren',
                border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('Kategori',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: cats.any((c) => c['id'] == _catId) ? _catId : null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: cats.map((c) => DropdownMenuItem(
                value: c['id'] as String,
                child: Text((c['name'] as String?) ?? '-'),
              )).toList(),
          onChanged: (v) => setState(() => _catId = v),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Harga (Rp)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        hintText: '18000',
                        border: OutlineInputBorder())),
              ])),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Stok',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        hintText: '50', border: OutlineInputBorder())),
              ])),
        ]),
        const SizedBox(height: 12),
        const Text('Barcode (opsional)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _barcode,
            decoration: const InputDecoration(
                hintText: 'scan / ketik manual',
                border: OutlineInputBorder())),
        if (_err != null) ...[
          const SizedBox(height: 8),
          Text(_err!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Menyimpan...' : 'Simpan Produk')),
      ]),
    );
  }
}
