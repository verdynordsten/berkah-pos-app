import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/store.dart';
import '../core/bottom_nav.dart';
import 'promo.dart' show bestPromo;

// 07 Keranjang — promo DINAMIS (terbaik otomatis) + pajak toko + preview poin.
class KeranjangScreen extends ConsumerStatefulWidget {
  const KeranjangScreen({super.key});
  @override
  ConsumerState<KeranjangScreen> createState() => _Kr();
}

class _Kr extends ConsumerState<KeranjangScreen> {
  Map<String, dynamic>? promo;
  double taxPct = 10;
  bool loadingPromo = true;
  // Aturan poin toko.
  double pointStep = 10000;
  double pointValue = 100;

  @override
  void initState() {
    super.initState();
    _loadPromo();
  }

  Future<void> _loadPromo() async {
    final s = ref.read(sessionProvider);
    if (s == null) {
      if (mounted) setState(() => loadingPromo = false);
      return;
    }
    final ctl = ref.read(cartProvider.notifier);
    final db = ref.read(supabaseProvider);
    try {
      final p = await bestPromo(db, s.storeId, ctl.subtotal);
      final prof = await db.from('stores').select('tax_percent,point_step,point_value')
          .eq('id', s.storeId).maybeSingle();
      if (mounted) {
        setState(() {
          promo = p;
          taxPct = (((prof?['tax_percent'] as num?) ?? 10).toDouble());
          pointStep = (((prof?['point_step'] as num?) ?? 10000).toDouble());
          pointValue = (((prof?['point_value'] as num?) ?? 100).toDouble());
          loadingPromo = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadingPromo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final ctl = ref.read(cartProvider.notifier);
    final sub = ctl.subtotal;
    final disc = loadingPromo ? 0.0 : ((promo?['computed_disc'] as num?) ?? 0).toDouble();
    final tax = (sub - disc) * taxPct / 100;
    final total = sub - disc + tax;
    final cust = ref.watch(customerProvider);
    final earnPts = total >= pointStep && pointStep > 0 ? (total ~/ pointStep) : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang')),
      bottomNavigationBar: const PosBottomNav(current: 1),
      body: Column(children: [
        Expanded(
          child: cart.isEmpty
              ? const Center(child: Text('Keranjang kosong'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final l = cart[i];
                    return Card(
                      child: ListTile(
                        leading: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                                color: AppColors.mut,
                                borderRadius:
                                    BorderRadius.circular(12)),
                            child: const Icon(
                                Icons.inventory_2,
                                color: AppColors.mfg)),
                        title: Text(l.product.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${rp(l.product.price)} /pcs'),
                        trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                    Icons.remove_circle_outline),
                                onPressed: () {
                                  ctl.dec(l.product);
                                  _loadPromo();
                                },
                              ),
                              Text('${l.qty}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              IconButton(
                                icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.pri),
                                onPressed: () {
                                  final ok = ctl.add(l.product);
                                  if (!ok && context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                            content: Text(
                                                'Stok ${l.product.name} cuma ${l.product.stock}')));
                                  }
                                  _loadPromo();
                                },
                              ),
                            ]),
                        onTap: () => Navigator.pushNamed(
                            context, '/detail',
                            arguments: l.product.id),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.line))),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Subtotal ${rp(sub)}'),
                if (loadingPromo)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(height: 14,
                        child: LinearProgressIndicator()),
                  )
                else if (promo != null)
                  Text('Promo ${promo!['name']} -${rp(disc)}',
                      style: const TextStyle(color: AppColors.ok))
                else
                  const Text('Tidak ada promo aktif',
                      style: TextStyle(color: AppColors.mfg, fontSize: 12)),
                Text('Pajak ${taxPct.toStringAsFixed(0)}% ${rp(tax)}'),
                if (cust != null && earnPts > 0)
                  Text('+ $earnPts poin untuk ${cust['name']} (≈${rp(earnPts * pointValue)})',
                      style: const TextStyle(color: AppColors.ok, fontSize: 12)),
                Text('Total ${rp(total)}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                FilledButton(
                    onPressed: cart.isEmpty
                        ? null
                        : () => Navigator.pushNamed(
                            context, '/pelanggan',
                            arguments: {
                              'total': total,
                              'disc': disc,
                              'promo_id': promo?['id'],
                              'promo_name': promo?['name'],
                              'tax_pct': taxPct,
                            }),
                    child: const Text('Lanjut ke Pembayaran')),
              ]),
        ),
      ]),
    );
  }
}
