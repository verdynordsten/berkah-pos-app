import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/loading.dart';
import '../core/store.dart';
import '../core/offline.dart';



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
  String orderType = 'takeaway';
  final _mejaCtl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Paket dari keranjang: {total, disc, promo_id, promo_name, tax_pct}.
    // Fallback hitung manual (tanpa promo, pajak 10%) kalau dibuka langsung.
    final args = ModalRoute.of(context)?.settings.arguments;
    final ctl = ref.read(cartProvider.notifier);
    final pack = args is Map ? args : null;
    final sub = ctl.subtotal;
    final disc = ((pack?['disc'] as num?) ?? 0).toDouble();
    final taxPct = ((pack?['tax_pct'] as num?) ?? 10).toDouble();
    final total = pack != null
        ? (((pack['total'] as num?) ?? 0).toDouble())
        : (sub * (1 - 0) * (1 + taxPct / 100));
    final tax = (sub - disc) * taxPct / 100;
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
                      Navigator.pushReplacementNamed(context, '/qris',
                          arguments: args is Map ? args : null);
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
        const Text('TIPE ORDER',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          for (final t in ['dinein', 'takeaway', 'delivery'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(t == 'dinein'
                    ? 'Makan di sini'
                    : t == 'takeaway'
                        ? 'Bawa pulang'
                        : 'Antar'),
                selected: orderType == t,
                onSelected: (_) => setState(() => orderType = t),
              ),
            ),
        ]),
        if (orderType == 'dinein') ...[
          const SizedBox(height: 8),
          TextField(controller: _mejaCtl,
              decoration: const InputDecoration(
                  labelText: 'No. meja (cth: A3)',
                  border: OutlineInputBorder())),
        ],
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
                      final pack2 = args is Map ? args : null;
                      // OFFLINE: internet mati -> antre lokal, sync nanti.
                      final conn = await Connectivity()
                          .checkConnectivity();
                      final offline = conn.contains(ConnectivityResult.none);
                      int earn = 0;
                      if (offline) {
                        await _queueOffline(ref,
                            method: method,
                            total: total, paid: paid, change: change,
                            disc: disc, tax: tax,
                            orderType: orderType,
                            tableNo: _mejaCtl.text.trim().isEmpty
                                ? null
                                : _mejaCtl.text.trim());
                      } else {
                        earn = await _save(
                            method, total, paid, change, ref,
                            disc: disc,
                            tax: tax,
                            orderType: orderType,
                            tableNo: _mejaCtl.text.trim().isEmpty
                                ? null
                                : _mejaCtl.text.trim(),
                            promoName: (pack2?['promo_name'] ?? '').toString());
                      }
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(
                            context, '/sukses',
                            arguments: {
                              'total': total,
                              'paid': paid,
                              'change': change,
                              'method': method,
                              'promo_name': (pack2?['promo_name'] ?? '').toString(),
                              'order_type': orderType,
                              'table_no': _mejaCtl.text.trim(),
                              'earned_points': earn,
                              'offline': offline,
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
            child: saving
                ? const BusyLabel('Menyimpan')
                : const Text('Selesaikan Transaksi')),
      ]),
    );
  }
}

Future<int> _save(String method, double total, double paid,
    double change, WidgetRef ref,
    {required double disc,
    required double tax,
    required String orderType,
    String? tableNo,
    String promoName = ''}) async {
  final db = Supabase.instance.client;
  final cart = ref.read(cartProvider);
  final ctl = ref.read(cartProvider.notifier);
  final session = ref.read(sessionProvider);
  if (session == null) throw StateError('Sesi habis — login ulang.');
  final shift = ref.read(shiftProvider);
  final cust = ref.read(customerProvider);
  final sub = ctl.subtotal;
  final trx = await db.from('transactions').insert({
    'store_id': session.storeId,
    'shift_id': shift?['id'],
    'customer_id': cust?['id'],
    'code': '#${DateTime.now().millisecondsSinceEpoch % 100000}',
    'subtotal': sub, 'discount': disc, 'tax': tax, 'total': total,
    'pay_method': method, 'paid': paid, 'change': change,
    'order_type': orderType,
    if (tableNo != null) 'table_no': tableNo,
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
  // Poin member: 1 poin tiap kelipatan point_step dari total.
  int earned = 0;
  if (cust != null && cust['id'] != null) {
    try {
      final prof = await db.from('stores')
          .select('point_step').eq('id', session.storeId).maybeSingle();
      final step = (((prof?['point_step'] as num?) ?? 10000).toDouble());
      if (step > 0 && total >= step) {
        earned = (total ~/ step);
        final curPts = await db.from('customers').select('points')
            .eq('id', cust['id'] as String).maybeSingle();
        final next = (((curPts?['points'] as num?) ?? 0).toInt()) + earned;
        await db.from('customers')
            .update({'points': next}).eq('id', cust['id'] as String);
        await db.from('point_moves').insert({
          'store_id': session.storeId,
          'customer_id': cust['id'],
          'transaction_id': trx['id'],
          'points': earned,
          'reason': 'earn',
        });
      }
    } catch (_) {}
  }
  ref.invalidate(productsProvider);
  ref.read(customerProvider.notifier).state = null;
  ctl.clear();
  return earned;
}

/// Antrekan transaksi ke SQLite lokal (mode offline). Keranjang dikosongkan.
Future<void> _queueOffline(WidgetRef ref,
    {required String method,
    required double total,
    required double paid,
    required double change,
    required double disc,
    required double tax,
    required String orderType,
    String? tableNo}) async {
  final session = ref.read(sessionProvider);
  if (session == null) throw StateError('Sesi habis — login ulang.');
  final cart = ref.read(cartProvider);
  final ctl = ref.read(cartProvider.notifier);
  final shift = ref.read(shiftProvider);
  final cust = ref.read(customerProvider);
  if (cart.isEmpty) throw StateError('Keranjang kosong.');
  await OfflineQueue.push(session.storeId, {
    'shift_id': shift?['id'],
    'customer_id': cust?['id'],
    'code': '#${DateTime.now().millisecondsSinceEpoch % 100000}',
    'subtotal': ctl.subtotal,
    'discount': disc, 'tax': tax, 'total': total,
    'pay_method': method, 'paid': paid, 'change': change,
    'order_type': orderType,
    if (tableNo != null) 'table_no': tableNo,
    'lines': [
      for (final l in cart)
        {
          'product_id': l.product.id, 'name': l.product.name,
          'price': l.product.price, 'qty': l.qty,
          'line_total': l.total,
        }
    ],
  });
  ref.read(customerProvider.notifier).state = null;
  ctl.clear();
  ref.invalidate(offlineCountProvider);
}
