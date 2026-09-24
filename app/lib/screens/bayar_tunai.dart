import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/store.dart';
import 'shift.dart' show shiftProvider;

// 09 Bayar Tunai — metode + denom + kembalian + simpan ke Supabase
class BayarTunaiScreen extends ConsumerStatefulWidget {
  const BayarTunaiScreen({super.key});
  @override
  ConsumerState<BayarTunaiScreen> createState() => _B();
}

class _B extends ConsumerState<BayarTunaiScreen> {
  String method = 'Tunai';
  double paid = 50000;
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final ctl = ref.read(cartProvider.notifier);
    final total = ctl.subtotal * 0.9 * 1.1; // HEMAT10 + pajak (sama dgn keranjang)
    final change = paid - total;
    const methods = ['Tunai', 'QRIS', 'Debit', 'E-Wallet'];
    const icons = [Icons.payments, Icons.qr_code, Icons.credit_card, Icons.wallet];
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.pri,
              borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            const Text('TOTAL TAGIHAN',
                style: TextStyle(color: Colors.white)),
            Text(rp(total),
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 12),
        const Text('METODE PEMBAYARAN',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          children: List.generate(4, (i) => Card(
                color: method == methods[i] ? AppColors.mut : null,
                child: InkWell(
                  onTap: () {
                    setState(() => method = methods[i]);
                    if (method == 'QRIS') {
                      Navigator.pushReplacementNamed(context, '/qris');
                    }
                  },
                  child: Center(
                      child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                        Icon(icons[i], color: AppColors.pri),
                        const SizedBox(width: 6),
                        Text(methods[i],
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ])),
                ),
              )),
        ),
        const SizedBox(height: 12),
        const Text('UANG DITERIMA',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [40000, 50000, 100000].map((d) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                  onPressed: () =>
                      setState(() => paid = d.toDouble()),
                  child: Text('Rp ${d ~/ 1000} rb')),
            ),
          );
        }).toList()),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.okBg,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.ok)),
          child: Center(
              child: Text('Kembalian ${rp(change < 0 ? 0 : change)}',
                  style: const TextStyle(
                      color: AppColors.ok,
                      fontWeight: FontWeight.w700,
                      fontSize: 16))),
        ),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: saving || change < 0
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      await _save(method, total, paid, change, ref);
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(
                            context, '/sukses',
                            arguments: {
                              'total': total,
                              'paid': paid,
                              'change': change,
                              'method': method
                            });
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Gagal simpan (cek Supabase): $e')));
                      }
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: Text(
                saving ? 'Menyimpan...' : 'Selesaikan Transaksi')),
      ]),
    );
  }
}

Future<void> _save(String method, double total, double paid,
    double change, WidgetRef ref) async {
  final db = Supabase.instance.client;
  final cart = ref.read(cartProvider);
  final ctl = ref.read(cartProvider.notifier);
  final session = ref.read(sessionProvider);
  if (session == null) throw StateError('Sesi habis — login ulang.');
  final shift = ref.read(shiftProvider);
  final sub = ctl.subtotal;
  final disc = sub * 0.10;
  final tax = (sub - disc) * 0.10;
  final trx = await db.from('transactions').insert({
    'store_id': session.storeId,
    'shift_id': shift?['id'],
    'code': '#${DateTime.now().millisecondsSinceEpoch % 100000}',
    'subtotal': sub, 'discount': disc, 'tax': tax, 'total': total,
    'pay_method': method, 'paid': paid, 'change': change,
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
    // Kurangi stok produk langsung (MVP; trigger DB bisa menyusul).
    try {
      final cur = await db.from('products').select('stock')
          .eq('id', l.product.id).single();
      final next = ((cur['stock'] as int?) ?? 0) - l.qty;
      await db.from('products').update({'stock': next < 0 ? 0 : next})
          .eq('id', l.product.id);
    } catch (_) {}
  }
  ref.invalidate(productsProvider);
  ctl.clear();
}
