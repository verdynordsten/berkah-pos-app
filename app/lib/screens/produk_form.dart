import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/loading.dart';

// 05b Tambah/Edit Produk (owner/admin) — nama + KATEGORI PER-TOKO
// (tambah/edit/hapus langsung dari form, bebas sebanyak apa pun) +
// harga + stok + barcode + FOTO (upload ke Supabase Storage).
// Simpan -> products (store aktif) -> kembali + refresh katalog + kategori.
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

  // Foto: file lokal (baru dipilih) + url lama (mode edit).
  XFile? _foto;
  String? _fotoUrlLama;
  bool _uploading = false;

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
      _fotoUrlLama = e['photo_url'] as String?;
    }
  }

  // ---------- KATEGORI: tambah / rename / hapus (per-toko) ----------

  Future<List<Map<String, dynamic>>> _cats(String storeId) async {
    final db = ref.read(supabaseProvider);
    final rows = await db.from('categories').select()
        .eq('store_id', storeId).order('sort');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _catAdd(String storeId) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kategori Baru'),
        content: TextField(controller: ctl, autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Nama kategori',
                hintText: 'cth: Minuman Dingin',
                border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    final name = ctl.text.trim();
    if (name.isEmpty) return;
    try {
      final db = ref.read(supabaseProvider);
      final row = await db.from('categories').insert({
        'store_id': storeId, 'name': name, 'sort': 999,
      }).select('id').single();
      ref.invalidate(categoriesProvider);
      if (mounted) {
        setState(() => _catId = row['id'] as String);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Kategori "$name" ditambah.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _catEdit(
      String storeId, Map<String, dynamic> c) async {
    final ctl =
        TextEditingController(text: (c['name'] as String?) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Kategori'),
        content: TextField(controller: ctl, autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Nama kategori',
                border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    final name = ctl.text.trim();
    if (name.isEmpty) return;
    try {
      final db = ref.read(supabaseProvider);
      await db.from('categories').update({'name': name})
          .eq('id', c['id'] as String);
      ref.invalidate(categoriesProvider);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _catHapus(Map<String, dynamic> c) async {
    final y = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus kategori?'),
        content: Text(
            '"${c['name']}" dihapus. Produk di dalamnya jadi Tanpa Kategori (tidak ikut terhapus).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (y != true) return;
    try {
      final db = ref.read(supabaseProvider);
      // Lepas dulu produk yang pakai kategori ini.
      await db.from('products').update({'category_id': null})
          .eq('category_id', c['id'] as String);
      await db.from('categories').delete().eq('id', c['id'] as String);
      ref.invalidate(categoriesProvider);
      if (mounted) {
        setState(() {
          if (_catId == c['id']) _catId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  /// Sheet kelola kategori: list + tambah + edit + hapus.
  Future<void> _kelolaKategori(String storeId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, ctl) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kelola Kategori',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                    'Khusus toko ini. Bebas tambah sebanyak apa pun.',
                    style: TextStyle(color: AppColors.mfg)),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder(
                    future: _cats(storeId),
                    builder: (_, snap) {
                      if (snap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                            child: Text('Gagal: ${snap.error}'));
                      }
                      final list = snap.data ?? [];
                      if (list.isEmpty) {
                        return const Center(
                            child: Text(
                                'Belum ada kategori.\nTambah yang pertama di bawah.',
                                textAlign: TextAlign.center));
                      }
                      return ListView.separated(
                        controller: ctl,
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = list[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                (c['name'] as String?) ?? '-',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await _catEdit(storeId, c);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Hapus',
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20, color: AppColors.dan),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await _catHapus(c);
                                    },
                                  ),
                                ]),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _catAdd(storeId);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Kategori'),
                ),
              ]),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  // ---------- FOTO: pilih + upload ke Storage ----------

  Future<void> _pilihFoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Ambil dari Kamera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Pilih dari Galeri'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return;
    try {
      final f = await ImagePicker().pickImage(
          source: src, maxWidth: 1280, imageQuality: 80);
      if (f != null && mounted) setState(() => _foto = f);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal ambil foto: $e')));
      }
    }
  }

  /// Upload file ke bucket product-photos, return public URL.
  /// Path: <storeId>/<timestamp>_<nama>. Bikin bucket + policy via
  /// supabase/migrate_v5_kategori_foto.sql SEBELUM pakai fitur ini.
  Future<String> _uploadFoto(String storeId, XFile f) async {
    final db = ref.read(supabaseProvider);
    final ext = f.name.contains('.')
        ? f.name.substring(f.name.lastIndexOf('.'))
        : '.jpg';
    final path =
        '$storeId/${DateTime.now().millisecondsSinceEpoch}$ext';
    setState(() => _uploading = true);
    try {
      await db.storage.from('product-photos').upload(
        path, File(f.path),
        fileOptions: const FileOptions(
            cacheControl: '3600', upsert: true),
      );
      return db.storage.from('product-photos').getPublicUrl(path);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ---------- SIMPAN ----------

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
      String? photoUrl = _fotoUrlLama;
      if (_foto != null) {
        photoUrl = await _uploadFoto(s.storeId, _foto!);
      }
      final payload = {
        'store_id': s.storeId,
        'category_id': _catId,
        'name': name,
        'price': price,
        'stock': stock,
        'barcode': _barcode.text.trim().isEmpty
            ? null
            : _barcode.text.trim(),
        'photo_url': photoUrl,
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
    final s = ref.watch(sessionProvider);
    final catsAsync = ref.watch(categoriesProvider);
    final cats = catsAsync.valueOrNull ?? [];
    // Kalau kategori yang kepilih kehapus dari luar, reset.
    if (_catId != null && cats.isNotEmpty &&
        !cats.any((c) => c['id'] == _catId)) {
      _catId = null;
    }
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.existing == null ? 'Tambah Produk' : 'Edit Produk')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ---- FOTO ----
        const Text('Foto produk',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _uploading ? null : _pilihFoto,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.mut,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: _foto != null
                ? Stack(fit: StackFit.expand, children: [
                    Image.file(File(_foto!.path), fit: BoxFit.cover),
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('Ganti',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ])
                : _fotoUrlLama?.isNotEmpty == true
                    ? Stack(fit: StackFit.expand, children: [
                        Image.network(_fotoUrlLama!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Center(
                                    child: Icon(Icons.broken_image,
                                        size: 40,
                                        color: AppColors.mfg))),
                        Positioned(
                          right: 8, top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius:
                                    BorderRadius.circular(20)),
                            child: const Text('Ganti',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12)),
                          ),
                        ),
                      ])
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 36, color: AppColors.mfg),
                          SizedBox(height: 6),
                          Text('Tap untuk tambah foto',
                              style:
                                  TextStyle(color: AppColors.mfg)),
                        ],
                      ),
          ),
        ),
        if (_uploading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          const Text('Mengupload foto',
              style: TextStyle(fontSize: 12, color: AppColors.mfg)),
        ],
        if (_foto != null || _fotoUrlLama?.isNotEmpty == true) ...[
          TextButton.icon(
            onPressed: () => setState(() {
              _foto = null;
              _fotoUrlLama = null;
            }),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Hapus foto'),
          ),
        ],
        const SizedBox(height: 12),
        const Text('Nama produk',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: _name,
            decoration: const InputDecoration(
                hintText: 'cth: Kopi Susu Gula Aren',
                border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(
            child: Text('Kategori',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton.icon(
            onPressed: s == null ? null : () => _kelolaKategori(s.storeId),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Kelola'),
          ),
        ]),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue:
              cats.any((c) => c['id'] == _catId) ? _catId : null,
          decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Pilih kategori (opsional)'),
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
            onPressed: (_busy || _uploading) ? null : _save,
            child: _busy ? const BusyLabel('Menyimpan') : const Text('Simpan Produk')),
      ]),
    );
  }
}
