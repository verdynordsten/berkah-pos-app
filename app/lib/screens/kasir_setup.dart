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

/// Hash PIN owner/admin: SHA-256("storeId:userId:pin").
/// Disimpan di memberships.pin_hash, verifikasi via RPC verify_owner_pin.
String hashOwnerPin(String storeId, String userId, String pin) {
  final raw = '$storeId:${userId.trim()}:$pin';
  return sha256.convert(utf8.encode(raw)).toString();
}

// 03b Kelola Kasir (owner/admin) — list staff + tambah + EDIT
// (nama, peran admin/kasir, reset PIN) + nonaktifkan.
// Kasir biasa TIDAK boleh buka layar ini (dijaga di build).
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

  String _roleOf(Map<String, dynamic>? r) {
    final v = (r?['role'] as String?)?.toLowerCase() ?? 'kasir';
    return v == 'admin' ? 'admin' : 'kasir';
  }

  /// Dialog tambah ATAU edit. Kalau [existing] null = tambah baru.
  Future<void> _form(String storeId,
      {Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameCtl =
        TextEditingController(text: (existing?['name'] as String?) ?? '');
    final pinCtl = TextEditingController();
    String role = isEdit ? _roleOf(existing) : 'kasir';
    final komCtl = TextEditingController(
        text: ((existing?['commission_pct'] as num?) ?? 0).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isEdit ? 'Edit Kasir' : 'Tambah Kasir'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtl,
                decoration: const InputDecoration(
                    labelText: 'Nama kasir',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(
                  labelText: 'Peran', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'kasir',
                    child: Text('Kasir — jualan saja')),
                DropdownMenuItem(
                    value: 'admin',
                    child: Text('Admin — bisa kelola menu')),
              ],
              onChanged: (v) => setD(() => role = v ?? 'kasir'),
            ),
            const SizedBox(height: 12),
            TextField(controller: pinCtl, obscureText: true,
                keyboardType: TextInputType.number, maxLength: 6,
                decoration: InputDecoration(
                    labelText: isEdit
                        ? 'PIN baru 6 digit (kosongkan = tidak ganti)'
                        : 'PIN 6 digit',
                    border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: komCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Komisi % (cth: 2 = 2% dari omzet)',
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
    final name = nameCtl.text.trim();
    final pin = pinCtl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Nama wajib diisi.')));
      }
      return;
    }
    if (!isEdit || pin.isNotEmpty) {
      if (pin.length != 6 || int.tryParse(pin) == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('PIN harus 6 digit angka.')));
        }
        return;
      }
    }
    try {
      final db = ref.read(supabaseProvider);
      final kom = double.tryParse(komCtl.text.replaceAll(',', '.')) ?? 0;
      if (!isEdit) {
        await db.from('staff').insert({
          'store_id': storeId,
          'name': name,
          'role': role,
          'pin_hash': hashPin(storeId, name, pin),
          'commission_pct': kom < 0 ? 0 : kom,
        });
      } else {
        final payload = <String, dynamic>{
          'name': name,
          'role': role,
          'commission_pct': kom < 0 ? 0 : kom,
        };
        if (pin.isNotEmpty) {
          payload['pin_hash'] = hashPin(storeId, name, pin);
        }
        await db.from('staff').update(payload)
            .eq('id', existing['id'] as String);
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEdit
                ? 'Kasir diperbarui.'
                : 'Kasir ditambah. PIN tiap user beda-beda.')));
      }
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

  Future<void> _hapus(Map<String, dynamic> row) async {
    final y = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus kasir?'),
        content: Text(
            '${row['name']} tidak bisa login lagi. Riwayat transaksi tetap ada.'),
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
      await db.from('staff').delete().eq('id', row['id'] as String);
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
      return Scaffold(
        appBar: AppBar(title: const Text('Kelola Kasir')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sesi habis. Masuk lagi dulu ya.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (_) => false),
                    child: const Text('Ke Halaman Masuk'),
                  ),
                ]),
          ),
        ),
      );
    }
    // KUNCI: kasir tidak boleh kelola user lain.
    if (!s.canManageMenu) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kelola Kasir')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Hanya Owner / Admin yang boleh kelola kasir.\nAkun kasir hanya bisa jualan.',
              textAlign: TextAlign.center),
          ),
        ),
      );
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
            const Text(
                'Tiap kasir/admin punya PIN sendiri. Kasir hanya bisa jualan.',
                style: TextStyle(color: AppColors.mfg)),
            const SizedBox(height: 12),
            ...list.map((r) {
              final admin = _roleOf(r) == 'admin';
              final active = r['is_active'] == true;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor:
                          admin ? AppColors.pri.withValues(alpha: 0.15) : null,
                      child: Text(
                          (((r['name'] as String?) ?? '?')
                              .substring(0, 1)
                              .toUpperCase()))),
                  title: Text((r['name'] as String?) ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${admin ? 'Admin' : 'Kasir'} — ${active ? 'Aktif' : 'Nonaktif'}'),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) {
                      if (v == 'edit') {
                        _form(s.storeId, existing: r);
                      } else if (v == 'toggle') {
                        _toggle(r);
                      } else if (v == 'hapus') {
                        _hapus(r);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit (nama/peran/PIN)')),
                      PopupMenuItem(
                          value: 'toggle',
                          child: Text(active ? 'Nonaktifkan' : 'Aktifkan')),
                      const PopupMenuItem(
                          value: 'hapus', child: Text('Hapus')),
                    ],
                  ),
                  onTap: () => _form(s.storeId, existing: r),
                ),
              );
            }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _form(s.storeId),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Kasir')),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () {
                  // Datang via push (Lainnya/Pilih User): cukup back.
                  // Datang via replace (alur register): tidak bisa pop -> ke /pilih.
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/pilih');
                  }
                },
                child: const Text('Selesai — Kembali')),
          ]);
        },
      ),
    );
  }
}
