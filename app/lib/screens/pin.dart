import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'kasir_setup.dart' show hashPin;

// 03 PIN Kasir — pilih nama kasir -> numpad 6 digit -> verify_staff_pin (RPC).
// Sukses -> session staffPin -> /shift. Owner juga bisa lewat sini (skip pilih).
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});
  @override
  ConsumerState<PinScreen> createState() => _P();
}

class _P extends ConsumerState<PinScreen> {
  String pin = '';
  String? picked;
  String? err;
  bool busy = false;
  List<Map<String, dynamic>> staff = [];
  bool loaded = false;

  Future<void> _load() async {
    final s = ref.read(sessionProvider);
    try {
      final db = ref.read(supabaseProvider);
      if (s == null) {
        // Tanpa session (kasir murni): minta store via email owner? MVP:
        // ambil staff dari toko pertama yang punya staff aktif.
        final rows = await db.from('staff').select('*, stores!inner(name)')
            .eq('is_active', true).order('name').limit(20);
        staff = (rows as List).cast<Map<String, dynamic>>();
      } else {
        final rows = await db.from('staff').select()
            .eq('store_id', s.storeId).eq('is_active', true).order('name');
        staff = (rows as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      err = '$e';
    }
    if (mounted) setState(() => loaded = true);
  }

  Future<void> tap(String k) async {
    setState(() {
      if (k == 'X') {
        if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
      } else if (pin.length < 6) {
        pin += k;
      }
      err = null;
    });
    if (pin.length == 6) await _verify();
  }

  Future<void> _verify() async {
    if (picked == null) {
      setState(() { err = 'Pilih nama kasir dulu.'; pin = ''; });
      return;
    }
    setState(() => busy = true);
    try {
      final db = ref.read(supabaseProvider);
      final row = staff.firstWhere((e) => e['id'] == picked);
      final storeId = row['store_id'] as String;
      final name = row['name'] as String;
      final storeName = (row['stores'] is Map)
          ? ((row['stores'] as Map)['name'] as String? ?? 'Toko')
          : (ref.read(sessionProvider)?.storeName ?? 'Toko');
      final sid = await db.rpc('verify_staff_pin', params: {
        'p_store_id': storeId,
        'p_name': name,
        'p_pin_hash': hashPin(storeId, name, pin),
      });
      if (sid == null) throw StateError('PIN salah. Coba lagi.');
      ref.read(sessionProvider.notifier).set(PosSession(
        kind: LoginKind.staffPin, storeId: storeId, storeName: storeName,
        actorId: sid as String, displayName: name, role: 'staff'));
      if (mounted) Navigator.pushReplacementNamed(context, '/shift');
    } catch (e) {
      setState(() { err = '$e'; pin = ''; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) _load();
    final dots = List.generate(6, (i) => i < pin.length ? '●' : '○').join(' ');
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'X'];
    return Scaffold(
      appBar: AppBar(title: const Text('PIN Kasir')),
      body: Column(children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            value: picked,
            decoration: const InputDecoration(
                labelText: 'Nama kasir', border: OutlineInputBorder()),
            items: staff.map((e) => DropdownMenuItem(
                  value: e['id'] as String,
                  child: Text((e['name'] as String?) ?? '-'),
                )).toList(),
            onChanged: (v) => setState(() => picked = v),
          ),
        ),
        const SizedBox(height: 8),
        Text(dots,
            style: const TextStyle(
                fontSize: 26, color: AppColors.pri, letterSpacing: 4)),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(err!, style: const TextStyle(color: Colors.red)),
          ),
        if (busy) const Padding(
          padding: EdgeInsets.only(top: 4),
          child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(24),
            children: keys
                .map((k) => k.isEmpty
                    ? const SizedBox()
                    : InkWell(
                        onTap: busy ? null : () => tap(k),
                        child: Center(
                            child: Text(k,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600)))))
                .toList(),
          ),
        ),
      ]),
    );
  }
}
