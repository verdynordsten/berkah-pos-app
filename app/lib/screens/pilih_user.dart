import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'kasir_setup.dart' show hashPin, hashOwnerPin;
import 'shift.dart' show shiftProvider;

// 02b Pilih Pengguna — setelah login owner/admin (email), pilih mau
// jualan sebagai siapa: Owner, Admin, atau Kasir.
// Tiap staff punya PIN sendiri. Kasir TIDAK bisa tambah menu (dikunci).
// Switch user kapan aja via menu Lainnya > Ganti Pengguna (tanpa logout).
class PilihUserScreen extends ConsumerStatefulWidget {
  const PilihUserScreen({super.key});
  @override
  ConsumerState<PilihUserScreen> createState() => _PU();
}

class _PU extends ConsumerState<PilihUserScreen> {
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _staff = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    var s = ref.read(sessionProvider);
    if (s == null) {
      // Sesi in-memory hilang tapi auth Supabase mungkin masih ada
      // (habis restart app) -> pulihkan otomatis biar tidak dead-end.
      try {
        final restored =
            await restoreOwnerSession(ref.read(supabaseProvider));
        if (restored != null) {
          ref.read(sessionProvider.notifier).set(restored);
          s = restored;
        }
      } catch (_) {}
    }
    if (s == null) {
      if (mounted) {
        setState(() { _loading = false; _err = 'Belum login.'; });
      }
      return;
    }
    try {
      final db = ref.read(supabaseProvider);
      final rows = await db.from('staff').select()
          .eq('store_id', s.storeId).eq('is_active', true).order('name');
      _staff = (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _err = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  String _roleOf(Map<String, dynamic> r) {
    final v = (r['role'] as String?)?.toLowerCase() ?? 'kasir';
    return v == 'admin' ? 'admin' : 'kasir';
  }

  /// Tap staff -> minta PIN -> verifikasi -> jadi operator aktif -> /shift.
  Future<void> _pickStaff(Map<String, dynamic> row) async {
    final s = ref.read(sessionProvider);
    if (s == null) return;
    final name = (row['name'] as String?) ?? '-';
    final role = _roleOf(row);
    final pinCtl = TextEditingController();
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('PIN — $name'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Peran: ${role == 'admin' ? 'Admin' : 'Kasir'}',
                style: const TextStyle(color: AppColors.mfg)),
            const SizedBox(height: 12),
            TextField(controller: pinCtl, obscureText: true,
                keyboardType: TextInputType.number, maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'PIN 6 digit',
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
                  final pin = pinCtl.text.trim();
                  if (pin.length != 6 || int.tryParse(pin) == null) {
                    setD(() => err = 'PIN harus 6 digit angka.');
                    return;
                  }
                  try {
                    final db = ref.read(supabaseProvider);
                    final sid = await db.rpc('verify_staff_pin', params: {
                      'p_store_id': s.storeId,
                      'p_name': name,
                      'p_pin_hash': hashPin(s.storeId, name, pin),
                    });
                    if (sid == null) {
                      setD(() => err = 'PIN salah. Coba lagi.');
                      return;
                    }
                    ref.read(sessionProvider.notifier).set(PosSession(
                      kind: LoginKind.staffPin,
                      storeId: s.storeId, storeName: s.storeName,
                      actorId: sid as String, displayName: name,
                      role: role));
                    // Ganti operator = keranjang + shift lama dibersihkan.
                    ref.read(cartProvider.notifier).clear();
                    ref.read(shiftProvider.notifier).state = null;
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    setD(() => err = '$e');
                  }
                },
                child: const Text('Masuk')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      Navigator.pushReplacementNamed(context, '/shift');
    }
  }

  /// Masuk sebagai owner — WAJIB PIN owner (bukan tanpa PIN).
  /// Kasir yang pegang HP tidak bisa naik ke owner tanpa tahu PIN ini.
  /// Kalau owner belum pernah pasang PIN (pin_hash NULL = akun lama),
  /// langsung diminta BUAT PIN dulu, sekali aja.
  void _asOwner() {
    final s = ref.read(sessionProvider);
    if (s == null) return;
    _ownerPinFlow(s.storeId);
  }

  Future<void> _ownerPinFlow(String storeId) async {
    final db = ref.read(supabaseProvider);
    final u = db.auth.currentUser;
    if (u == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sesi login email habis. Masuk ulang dulu.')));
      }
      return;
    }
    // Cek apakah owner sudah punya PIN (baca kolom pin_hash saja).
    bool hasPin = false;
    String ownerName = 'Owner';
    try {
      final mem = await db.from('memberships').select('display_name, pin_hash')
          .eq('user_id', u.id).eq('store_id', storeId)
          .eq('is_active', true).maybeSingle();
      if (mem != null) {
        ownerName = (mem['display_name'] as String?) ?? 'Owner';
        hasPin = (mem['pin_hash'] as String?)?.isNotEmpty == true;
      }
    } catch (_) {}
    if (!mounted) return;
    if (!hasPin) {
      await _buatPinOwner(storeId, u.id, ownerName);
      return;
    }
    await _mintaPinOwner(storeId, u.id, ownerName);
  }

  /// Owner belum punya PIN (akun lama) -> buat sekali, langsung masuk.
  Future<void> _buatPinOwner(
      String storeId, String uid, String ownerName) async {
    final pinCtl = TextEditingController();
    final pin2Ctl = TextEditingController();
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Buat PIN Owner'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'Mulai sekarang masuk mode Owner wajib PIN 6 digit. Buat sekali aja.',
                style: TextStyle(color: AppColors.mfg)),
            const SizedBox(height: 12),
            TextField(controller: pinCtl, obscureText: true,
                keyboardType: TextInputType.number, maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'PIN 6 digit baru',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: pin2Ctl, obscureText: true,
                keyboardType: TextInputType.number, maxLength: 6,
                decoration: const InputDecoration(
                    labelText: 'Ulangi PIN',
                    border: OutlineInputBorder())),
            if (err != null) ...[
              const SizedBox(height: 8),
              Text(err!, style: const TextStyle(color: Colors.red)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Nanti')),
            FilledButton(
                onPressed: () async {
                  final p1 = pinCtl.text.trim();
                  final p2 = pin2Ctl.text.trim();
                  if (p1.length != 6 || int.tryParse(p1) == null) {
                    setD(() => err = 'PIN harus 6 digit angka.');
                    return;
                  }
                  if (p1 != p2) {
                    setD(() => err = 'PIN tidak sama. Ulangi.');
                    return;
                  }
                  try {
                    final db = ref.read(supabaseProvider);
                    await db.from('memberships').update({
                      'pin_hash': hashOwnerPin(storeId, uid, p1),
                    }).eq('user_id', uid).eq('store_id', storeId);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    setD(() => err = '$e');
                  }
                },
                child: const Text('Simpan PIN')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      _enterOwner(storeId, uid);
    }
  }

  /// Owner sudah punya PIN -> wajib masukin dengan benar baru bisa masuk.
  Future<void> _mintaPinOwner(
      String storeId, String uid, String ownerName) async {
    final pinCtl = TextEditingController();
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('PIN — $ownerName'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Mode Owner — wajib PIN.',
                style: TextStyle(color: AppColors.mfg)),
            const SizedBox(height: 12),
            TextField(controller: pinCtl, obscureText: true,
                keyboardType: TextInputType.number, maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'PIN 6 digit',
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
                  final pin = pinCtl.text.trim();
                  if (pin.length != 6 || int.tryParse(pin) == null) {
                    setD(() => err = 'PIN harus 6 digit angka.');
                    return;
                  }
                  try {
                    final db = ref.read(supabaseProvider);
                    final valid = await db.rpc('verify_owner_pin', params: {
                      'p_user_id': uid,
                      'p_store_id': storeId,
                      'p_pin_hash': hashOwnerPin(storeId, uid, pin),
                    }) as bool;
                    if (!valid) {
                      setD(() => err = 'PIN salah. Coba lagi.');
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    setD(() => err = '$e');
                  }
                },
                child: const Text('Masuk')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      _enterOwner(storeId, uid);
    }
  }

  /// PIN owner valid -> bangun sesi owner -> /shift.
  Future<void> _enterOwner(String storeId, String uid) async {
    try {
      final db = ref.read(supabaseProvider);
      final mem = await db.from('memberships').select()
          .eq('user_id', uid).eq('store_id', storeId)
          .eq('is_active', true).maybeSingle();
      final store = await db.from('stores').select()
          .eq('id', storeId).maybeSingle();
      if (mem == null) return;
      ref.read(sessionProvider.notifier).set(PosSession(
        kind: LoginKind.owner, storeId: storeId,
        storeName: (store?['name'] as String?) ?? 'Toko',
        actorId: uid,
        displayName: (mem['display_name'] as String?) ?? 'Owner',
        role: (mem['role'] as String?) ?? 'owner'));
      ref.read(cartProvider.notifier).clear();
      ref.read(shiftProvider.notifier).state = null;
      if (mounted) Navigator.pushReplacementNamed(context, '/shift');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pilih Pengguna')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_err ?? 'Sesi habis. Masuk lagi dulu ya.',
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
    final isPrivileged = s.canManageMenu;
    return Scaffold(
      appBar: AppBar(
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.storeName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Login sebagai ${s.displayName} — ${s.roleLabel}',
                  style: const TextStyle(fontSize: 11, color: AppColors.mfg)),
            ]),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(supabaseProvider).auth.signOut();
              ref.read(sessionProvider.notifier).clear();
              ref.read(shiftProvider.notifier).state = null;
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false);
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null && _staff.isEmpty
              ? Center(child: Text('Gagal: $_err'))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const Text('Mau jualan sebagai siapa?',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                      'SEMUA peran wajib PIN — termasuk Owner. Kasir hanya bisa jualan (tidak bisa tambah menu).',
                      style: TextStyle(color: AppColors.mfg)),
                  const SizedBox(height: 12),
                  // Kartu owner: WAJIB PIN owner (bukan tanpa PIN).
                  if (isPrivileged)
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.verified_user)),
                        title: Text(s.displayName),
                        subtitle: Text(
                            '${s.roleLabel} — wajib PIN owner'),
                        trailing: const Icon(Icons.lock),
                        onTap: _asOwner,
                      ),
                    ),
                  ..._staff.map((r) {
                    final name = (r['name'] as String?) ?? '-';
                    final role = _roleOf(r);
                    final admin = role == 'admin';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: admin
                                ? AppColors.pri.withValues(alpha: 0.15)
                                : null,
                            child: Icon(admin
                                ? Icons.manage_accounts
                                : Icons.point_of_sale)),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(admin
                            ? 'Admin — PIN sendiri, bisa kelola menu'
                            : 'Kasir — PIN sendiri, jualan saja'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: admin
                                ? AppColors.pri
                                : AppColors.mut,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(admin ? 'ADMIN' : 'KASIR',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: admin
                                      ? Colors.white
                                      : AppColors.mfg)),
                        ),
                        onTap: () => _pickStaff(r),
                      ),
                    );
                  }),
                  if (_staff.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                        'Belum ada kasir. Owner bisa tambah dulu via Kelola Kasir.',
                        style: TextStyle(color: AppColors.mfg)),
                  ],
                  const SizedBox(height: 16),
                  if (isPrivileged) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/kasir'),
                      icon: const Icon(Icons.group),
                      label: const Text('Kelola Kasir (tambah / edit / PIN)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/toko'),
                      icon: const Icon(Icons.store),
                      label: const Text('Setup Toko'),
                    ),
                  ],
                ]),
    );
  }
}
