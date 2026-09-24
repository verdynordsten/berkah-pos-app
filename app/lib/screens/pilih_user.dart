import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'kasir_setup.dart' show hashPin;
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

  /// Masuk sebagai owner (sudah auth email, tanpa PIN lagi).
  void _asOwner() {
    final s = ref.read(sessionProvider);
    if (s == null) return;
    // Kalau sesi sekarang staff (hasil switch), auth owner mungkin masih ada.
    // Kembalikan ke owner via membership tersimpan? Paling aman: kalau auth
    // Supabase masih login, rebuild owner session dari memberships.
    _restoreOwner(s.storeId);
  }

  Future<void> _restoreOwner(String storeId) async {
    try {
      final db = ref.read(supabaseProvider);
      final u = db.auth.currentUser;
      if (u != null) {
        final mem = await db.from('memberships').select()
            .eq('user_id', u.id).eq('store_id', storeId)
            .eq('is_active', true).maybeSingle();
        if (mem != null) {
          final store = await db.from('stores').select()
              .eq('id', storeId).maybeSingle();
          ref.read(sessionProvider.notifier).set(PosSession(
            kind: LoginKind.owner, storeId: storeId,
            storeName: (store?['name'] as String?) ?? 'Toko',
            actorId: u.id,
            displayName: (mem['display_name'] as String?) ?? 'Owner',
            role: (mem['role'] as String?) ?? 'owner'));
          ref.read(cartProvider.notifier).clear();
          ref.read(shiftProvider.notifier).state = null;
          if (mounted) Navigator.pushReplacementNamed(context, '/shift');
          return;
        }
      }
    } catch (_) {}
    // Fallback: sesi sekarang sudah owner-ish -> langsung lanjut.
    if (mounted) Navigator.pushReplacementNamed(context, '/shift');
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
                      'Tiap pengguna punya PIN sendiri. Kasir hanya bisa jualan (tidak bisa tambah menu).',
                      style: TextStyle(color: AppColors.mfg)),
                  const SizedBox(height: 12),
                  // Kartu owner (kalau sesi punya hak kelola).
                  if (isPrivileged)
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.verified_user)),
                        title: Text(s.displayName),
                        subtitle: Text(
                            '${s.roleLabel} — tanpa PIN (sudah login email)'),
                        trailing: const Icon(Icons.chevron_right),
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
