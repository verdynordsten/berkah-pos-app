import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';

/// Hash PIN kasir: SHA-256("storeId:name:pin"). Disimpan di staff.pin_hash.
/// Verifikasi via RPC verify_staff_pin agar hash tidak perlu dibaca app.
String hashPin(String storeId, String name, String pin) {
  final raw = '$storeId:${name.trim().toLowerCase()}:$pin';
  return sha256.convert(utf8.encode(raw)).toString();
}

// 03b Kelola Kasir (owner) — list staff + tambah (nama+PIN) + nonaktifkan.
// Dibuka setelah setup toko. Selesai -> /katalog (mode owner).
class KasirSetupScreen extends ConsumerStatefulWidget {
  const KasirSetupScreen({super.key});
  @override
  ConsumerState<KasirSetupScreen> createState() => _K();
}

class _K extends ConsumerState<KasirSetupScreen> {
  Future<List<Map<String, dynamic>>> _list(String storeId) async {
    final db = ref.read(supabaseProvider);
    final rows = await db.from('staff').select().eq('store_id', storeId)
        .order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _add(String storeId) async {
    final nameCtl = TextEditingController();
    final pinCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Kasir'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtl,
              decoration: const InputDecoration(
                  labelText: 'Nama kasir', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: pinCtl, obscureText: true,
              keyboardType: TextInputType.number, maxLength: 6,
              decoration: const InputDecoration(
                  labelText: 'PIN 6 digit', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtl.text.trim();
    final pin = pinCtl.text.trim();
    if (name.isEmpty || pin.length != 6 || int.tryParse(pin) == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Nama wajib isi, PIN harus 6 digit angka.')));
      }
      return;
    }
    try {
      final db = ref.read(supabaseProvider);
      await db.from('staff').insert({
        'store_id': storeId,
        'name': name,
        'pin_hash': hashPin(storeId, name, pin),
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    final db = ref.read(supabaseProvider);
    await db.from('staff').update({'is_active': !(row['is_active'] == true)})
        .eq('id', row['id'] as String);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (s == null) {
      return const Scaffold(
          body: Center(child: Text('Belum login. Kembali & masuk dulu.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kasir')),
      body: FutureBuilder(
        future: _list(s.storeId),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Gagal: ${snap.error}'));
          }
          final list = snap.data ?? [];
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Langkah 2/2 — kasir login pakai nama + PIN di HP yang sama',
                style: TextStyle(color: AppColors.mfg)),
            const SizedBox(height: 12),
            ...list.map((r) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        child: Text(((r['name'] as String?) ?? '?')
                            .substring(0, 1).toUpperCase())),
                    title: Text((r['name'] as String?) ?? '-'),
                    subtitle: Text((r['is_active'] == true)
                        ? 'Aktif' : 'Nonaktif'),
                    trailing: TextButton(
                      onPressed: () => _toggle(r),
                      child: Text((r['is_active'] == true)
                          ? 'Nonaktifkan' : 'Aktifkan'),
                    ),
                  ),
                )),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _add(s.storeId),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Kasir')),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/katalog'),
                child: const Text('Selesai — Buka Kasir')),
          ]);
        },
      ),
    );
  }
}
