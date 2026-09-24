import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';

// 04 Pilih Shift — buka shift REAL: insert ke shifts (store+kasir+modal).
// Selesai -> /katalog. Shift id disimpan di provider untuk dipakai checkout.
final shiftProvider = StateProvider<Map<String, dynamic>?>((_) => null);

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});
  @override
  ConsumerState<ShiftScreen> createState() => _Sh();
}

class _Sh extends ConsumerState<ShiftScreen> {
  String label = 'Shift Pagi (07-15)';
  final _modal = TextEditingController(text: '500000');
  bool busy = false;
  String? err;

  Future<void> _start() async {
    final s = ref.read(sessionProvider);
    if (s == null) {
      setState(() => err = 'Belum login.');
      return;
    }
    setState(() { busy = true; err = null; });
    try {
      final db = ref.read(supabaseProvider);
      final modal = double.tryParse(
              _modal.text.replaceAll('.', '').replaceAll(',', '.')) ??
          0;
      final row = await db.from('shifts').insert({
        'store_id': s.storeId,
        'cashier_name': s.displayName,
        'label': label,
        'opening_cash': modal,
        if (s.kind == LoginKind.owner) 'user_id': s.actorId
        else 'staff_id': s.actorId,
      }).select().single();
      ref.read(shiftProvider.notifier).state =
          (row as Map).cast<String, dynamic>();
      if (mounted) Navigator.pushReplacementNamed(context, '/katalog');
    } catch (e) {
      setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const shifts = [
      'Shift Pagi (07-15)',
      'Shift Siang (15-23)',
      'Shift Malam (23-07)'
    ];
    final s = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Shift')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (s != null)
          Text('Halo, ${s.displayName} — ${s.storeName}',
              style: const TextStyle(color: AppColors.mfg)),
        const SizedBox(height: 8),
        ...shifts.map((o) => Card(
              child: RadioGroup<String>(
                groupValue: label,
                onChanged: (v) => setState(() => label = v!),
                child: RadioListTile<String>(
                  value: o,
                  title: Text(o,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            )),
        const SizedBox(height: 12),
        const Text('Modal awal kas (Rp)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
            controller: _modal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                hintText: '500000', border: OutlineInputBorder())),
        if (err != null) ...[
          const SizedBox(height: 8),
          Text(err!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
            onPressed: busy ? null : _start,
            child: Text(busy ? 'Membuka...' : 'Mulai Shift')),
      ]),
    );
  }
}
