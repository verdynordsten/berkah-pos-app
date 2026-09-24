import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/loading.dart';



// 10 Bayar QRIS — QR + countdown real 5 menit + simpan transaksi saat konfirmasi.
class BayarQrisScreen extends ConsumerStatefulWidget {
  const BayarQrisScreen({super.key});
  @override
  ConsumerState<BayarQrisScreen> createState() => _Q();
}

class _Q extends ConsumerState<BayarQrisScreen> {
  Timer? _t;
  int _left = 300; // 5 menit
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left <= 0) {
        _t?.cancel();
        return;
      }
      setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String get _clock {
    final m = (_left ~/ 60).toString().padLeft(2, '0');
    final s = (_left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _confirm(double total) async {
    setState(() => _saving = true);
    try {
      final db = Supabase.instance.client;
      final session = ref.read(sessionProvider);
      if (session == null) throw StateError('Sesi habis — login ulang.');
      final cart = ref.read(cartProvider);
      final ctl = ref.read(cartProvider.notifier);
      final shift = ref.read(shiftProvider);
      final cust = ref.read(customerProvider);
      final sub = ctl.subtotal;
      final disc = sub * 0.10;
      final tax = (sub - disc) * 0.10;
      final trx = await db.from('transactions').insert({
        'store_id': session.storeId,
        'shift_id': shift?['id'],
        'customer_id': cust?['id'],
        'code': '#${DateTime.now().millisecondsSinceEpoch % 100000}',
        'subtotal': sub, 'discount': disc, 'tax': tax, 'total': total,
        'pay_method': 'QRIS', 'paid': total, 'change': 0,
      }).select('id').single();
      for (final l in cart) {
        await db.from('transaction_items').insert({
          'transaction_id': trx['id'],
          'product_id': l.product.id,
          'name': l.product.name, 'price': l.product.price,
          'qty': l.qty, 'line_total': l.total,
        });
        await db.from('stock_moves').insert({
          'store_id': session.storeId, 'product_id': l.product.id,
          'qty': -l.qty, 'reason': 'sale',
        });
        try {
          final cur = await db.from('products').select('stock')
              .eq('id', l.product.id).single();
          final next = ((cur['stock'] as int?) ?? 0) - l.qty;
          await db.from('products').update({'stock': next < 0 ? 0 : next})
              .eq('id', l.product.id);
        } catch (_) {}
      }
      ref.invalidate(productsProvider);
      ref.read(customerProvider.notifier).state = null;
      ctl.clear();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/sukses', arguments: {
          'total': total, 'paid': total,
          'change': 0.0, 'method': 'QRIS'
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal simpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final cart = ref.watch(cartProvider);
    final ctl = ref.read(cartProvider.notifier);
    final sub = ctl.subtotal;
    final total = args is double
        ? args
        : sub - sub * 0.10 + (sub - sub * 0.10) * 0.10;
    final expired = _left <= 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran QRIS')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
            child: Text('Total ${rp(total)}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700))),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line)),
            child: expired
                ? const SizedBox(
                    width: 220, height: 220,
                    child: Center(
                        child: Text('Kode kedaluwarsa.\nKembali & buat baru.',
                            textAlign: TextAlign.center)))
                : QrImageView(
                    data:
                        'berkahpos://pay?amount=${total.toInt()}',
                    version: QrVersions.auto,
                    size: 220,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
            child: Text('Scan kode di atas dengan e-wallet / m-banking',
                style: TextStyle(color: AppColors.mfg))),
        Center(
            child: expired
                ? const Text('Kedaluwarsa',
                    style: TextStyle(
                        color: AppColors.dan,
                        fontWeight: FontWeight.w700))
                : Column(children: [
                    Text('Berlaku $_clock',
                        style: const TextStyle(
                            color: AppColors.mfg,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 220,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _left / 300,
                          minHeight: 6,
                          backgroundColor: AppColors.mut,
                          valueColor:
                              const AlwaysStoppedAnimation(
                                  AppColors.warn),
                        ),
                      ),
                    ),
                  ])),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.mut,
              borderRadius: BorderRadius.circular(12)),
          child: Center(
              child: Text(
                  '${cart.length} item — kasir pastikan dana masuk sebelum konfirmasi')),
        ),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: expired || _saving
                ? null
                : () => _confirm(total),
            child: _saving
                ? const BusyLabel('Menyimpan')
                : const Text('Saya Sudah Bayar')),
      ]),
    );
  }
}
