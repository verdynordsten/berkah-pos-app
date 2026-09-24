import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/bottom_nav.dart';

import 'kasir_setup.dart' show hashPin, hashOwnerPin;

// 13 Lainnya — menu owner/kasir: ganti PIN, kelola kasir, setup toko,
// tutup shift, keluar. Switch user via Ganti Pengguna (semua wajib PIN).
class LainnyaScreen extends ConsumerWidget {
  const LainnyaScreen({super.key});

  /// Ganti PIN sendiri: owner (memberships.pin_hash via update langsung,
  /// wajib PIN lama) atau kasir/admin (staff.pin_hash, wajib PIN lama).
  Future<void> _gantiPin(BuildContext context, WidgetRef ref) async {
    final s = ref.read(sessionProvider);
    if (s == null) return;
    final lamaCtl = TextEditingController();
    final baruCtl = TextEditingController();
    final baru2Ctl = TextEditingController();
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Ganti PIN Saya'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: lamaCtl, obscureText: true,
                keyboardType: TextInputType.number, maxLength: 6,
                decoration: const InputDecoration(
                    labelText: 'PIN lama', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: baruCtl, obscureText: true,
                keyboardType: TextInputType.number, maxLength: 6,
                decoration: const InputDecoration(
                    labelText: 'PIN baru 6 digit',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: baru2Ctl, obscureText: true,
                keyboardType: TextInputType.number, maxLength: 6,
                decoration: const InputDecoration(
                    labelText: 'Ulangi PIN baru',
                    border: OutlineInputBorder())),
            if (err != null) ...[
              const SizedBox(height: 8),
              Text(err!, style: const TextStyle(color: Colors.red)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () async {
                  final lama = lamaCtl.text.trim();
                  final b1 = baruCtl.text.trim();
                  final b2 = baru2Ctl.text.trim();
                  if (b1.length != 6 || int.tryParse(b1) == null) {
                    setD(() => err = 'PIN baru harus 6 digit angka.');
                    return;
                  }
                  if (b1 != b2) {
                    setD(() => err = 'PIN baru tidak sama. Ulangi.');
                    return;
                  }
                  try {
                    final db = ref.read(supabaseProvider);
                    if (s.kind == LoginKind.owner) {
                      final u = db.auth.currentUser;
                      if (u == null) throw StateError('Sesi email habis.');
                      final valid = await db.rpc('verify_owner_pin', params: {
                        'p_user_id': u.id,
                        'p_store_id': s.storeId,
                        'p_pin_hash':
                            // ignore: avoid_dynamic_calls
                            hashOwnerPin(s.storeId, u.id, lama),
                      }) as bool;
                      if (!valid) {
                        setD(() => err = 'PIN lama salah.');
                        return;
                      }
                      await db.from('memberships').update({
                        'pin_hash': hashOwnerPin(s.storeId, u.id, b1),
                      }).eq('user_id', u.id).eq('store_id', s.storeId);
                    } else {
                      final valid = await db.rpc('verify_staff_pin', params: {
                        'p_store_id': s.storeId,
                        'p_name': s.displayName,
                        'p_pin_hash': hashPin(
                            s.storeId, s.displayName, lama),
                      });
                      if (valid == null) {
                        setD(() => err = 'PIN lama salah.');
                        return;
                      }
                      await db.from('staff').update({
                        'pin_hash':
                            hashPin(s.storeId, s.displayName, b1),
                      }).eq('id', s.actorId);
                    }
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    setD(() => err = '$e');
                  }
                },
                child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN diganti.')));
    }
  }

  Future<void> _tutupShift(BuildContext context, WidgetRef ref) async {
    final s = ref.read(sessionProvider);
    final sh = ref.read(shiftProvider);
    if (s == null || sh == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tidak ada shift aktif.')));
      return;
    }
    // Hitung kas ekspektasi: modal awal + tunai masuk shift ini
    // (Tunai only — QRIS/Debit/E-Wallet masuk rekening, bukan laci).
    // + kas masuk manual - kas keluar manual (cash_moves shift ini).
    double tunai = 0;
    double kasIn = 0, kasOut = 0;
    try {
      final db = ref.read(supabaseProvider);
      final trx = await db.from('transactions').select('total,pay_method')
          .eq('shift_id', sh['id'] as String);
      for (final t in (trx as List).cast<Map<String, dynamic>>()) {
        if (((t['pay_method'] ?? '').toString()).toLowerCase() == 'tunai') {
          tunai += (((t['total'] as num?) ?? 0).toDouble());
        }
      }
      final since = (sh['opened_at'] ?? '').toString();
      var q = db.from('cash_moves').select('kind,amount')
          .eq('store_id', s.storeId);
      if (since.isNotEmpty) q = q.gte('created_at', since);
      final moves = await q;
      for (final m in (moves as List).cast<Map<String, dynamic>>()) {
        final a = (((m['amount'] as num?) ?? 0).toDouble());
        if ((m['kind'] ?? 'out') == 'in') {
          kasIn += a;
        } else {
          kasOut += a;
        }
      }
    } catch (_) {}
    final modalAwal = (((sh['opening_cash'] as num?) ?? 0).toDouble());
    final ekspektasi = modalAwal + tunai + kasIn - kasOut;
    final ctl = TextEditingController(text: ekspektasi.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final aktual = double.tryParse(
                  ctl.text.replaceAll('.', '').replaceAll(',', '.')) ??
              0;
          final selisih = aktual - ekspektasi;
          return AlertDialog(
            title: const Text('Tutup Shift'),
            content: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _rek('Modal awal', rp(modalAwal)),
                _rek('Tunai masuk', rp(tunai)),
                _rek('Kas masuk', rp(kasIn)),
                _rek('Kas keluar', rp(kasOut)),
                const Divider(),
                _rek('Kas seharusnya (laci)', rp(ekspektasi), bold: true),
                const SizedBox(height: 12),
                TextField(controller: ctl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setD(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Kas aktual di laci (Rp)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 8),
                Text(
                  selisih == 0
                      ? 'Pas — tidak ada selisih.'
                      : selisih > 0
                          ? 'Lebih ${rp(selisih)} dari seharusnya.'
                          : 'Kurang ${rp(-selisih)} dari seharusnya.',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selisih == 0
                          ? AppColors.ok
                          : selisih > 0
                              ? AppColors.pri
                              : AppColors.dan),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal')),
              FilledButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text('Tutup')),
            ],
          );
        },
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
        // Kill-switch: buang SEMUA layar jualan, balik ke shift.
        // Back dari shift = keluar app (tidak bisa nyasar ke katalog
        // tanpa shift aktif).
        Navigator.pushNamedAndRemoveUntil(
            context, '/shift', (_) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Widget _rek(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(k)),
        Text(v,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ]),
    );
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
      bottomNavigationBar: const PosBottomNav(current: 3),
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
            subtitle: const Text('Switch kasir / admin / owner (wajib PIN)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, '/pilih'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_reset,
                color: AppColors.pri),
            title: const Text('Ganti PIN Saya'),
            subtitle: const Text('Wajib tahu PIN lama'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _gantiPin(context, ref),
          ),
        ),
        if (s?.canManageMenu == true) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.bar_chart,
                  color: AppColors.pri),
              title: const Text('Laporan Usaha'),
              subtitle: const Text('Omzet, terlaris, rekap kasir'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, '/laporan'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.discount,
                  color: AppColors.pri),
              title: const Text('Promo & Diskon'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, '/promo'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.warehouse,
                  color: AppColors.pri),
              title: const Text('Kelola Stok'),
              subtitle: const Text('Menipis, riwayat, pembelian'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, '/stok'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet,
                  color: AppColors.pri),
              title: const Text('Kas & Keuangan'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, '/kas'),
            ),
          ),
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
              subtitle: const Text('PIN, peran, komisi %'),
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
              subtitle: const Text('Nama, pajak %, aturan poin'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, '/toko'),
            ),
          ),
          if (s?.kind == LoginKind.owner) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront,
                    color: AppColors.pri),
                title: const Text('Ganti Toko'),
                subtitle: const Text('Multi-outlet 1 akun'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/toko_list', (_) => false),
              ),
            ),
          ],
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
