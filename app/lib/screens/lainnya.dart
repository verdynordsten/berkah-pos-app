import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'shift.dart' show shiftProvider;

// 13 Lainnya — menu owner/kasir: kelola kasir, setup toko, tutup shift, keluar.
class LainnyaScreen extends ConsumerWidget {
  const LainnyaScreen({super.key});

  Future<void> _tutupShift(BuildContext context, WidgetRef ref) async {
    final s = ref.read(sessionProvider);
    final sh = ref.read(shiftProvider);
    if (s == null || sh == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tidak ada shift aktif.')));
      return;
    }
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tutup Shift'),
        content: TextField(controller: ctl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Kas akhir (Rp)',
                border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Tutup')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = ref.read(supabaseProvider);
      await db.from('shifts').update({
        'closing_cash': double.tryParse(
                ctl.text.replaceAll('.', '').replaceAll(',', '.')) ??
            0,
        'closed_at': DateTime.now().toIso8601String(),
      }).eq('id', sh['id'] as String);
      ref.read(shiftProvider.notifier).state = null;
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/shift');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(supabaseProvider).auth.signOut();
    ref.read(sessionProvider.notifier).clear();
    ref.read(shiftProvider.notifier).state = null;
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final sh = ref.watch(shiftProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(s?.displayName ?? '-',
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                '${s?.storeName ?? ''} — ${s?.roleLabel ?? ''}${sh != null ? '\nShift: ${sh['label']}' : '\nBelum buka shift'}'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.switch_account,
                color: AppColors.pri),
            title: const Text('Ganti Pengguna'),
            subtitle: const Text('Switch kasir / admin tanpa logout'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushReplacementNamed(context, '/pilih'),
          ),
        ),
        if (s?.canManageMenu == true) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2,
                  color: AppColors.pri),
              title: const Text('Tambah Produk'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, '/produk_baru'),
            ),
          ),
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.group, color: AppColors.pri),
              title: const Text('Kelola Kasir'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, '/kasir'),
            ),
          ),
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.store, color: AppColors.pri),
              title: const Text('Setup Toko'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, '/toko'),
            ),
          ),
        ],
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_clock,
                color: AppColors.warn),
            title: const Text('Tutup Shift'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _tutupShift(context, ref),
          ),
        ),
        Card(
          child: ListTile(
            leading:
                const Icon(Icons.logout, color: AppColors.dan),
            title: const Text('Keluar',
                style: TextStyle(color: AppColors.dan)),
            onTap: () => _logout(context, ref),
          ),
        ),
      ]),
    );
  }
}
