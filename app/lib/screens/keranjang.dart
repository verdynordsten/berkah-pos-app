import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/store.dart';

// 07 Keranjang — list + promo + summary + lanjut bayar
class KeranjangScreen extends ConsumerWidget {
  const KeranjangScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final ctl = ref.read(cartProvider.notifier);
    final sub = ctl.subtotal;
    final disc = sub * 0.10; // HEMAT10
    final tax = (sub - disc) * 0.10;
    final total = sub - disc + tax;
    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang')),
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
                                onPressed: () =>
                                    ctl.dec(l.product),
                              ),
                              Text('${l.qty}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              IconButton(
                                icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.pri),
                                onPressed: () =>
                                    ctl.add(l.product),
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
                Text('Promo HEMAT10 -${rp(disc)}',
                    style: const TextStyle(color: AppColors.ok)),
                Text('Pajak 10% ${rp(tax)}'),
                Text('Total ${rp(total)}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                FilledButton(
                    onPressed: cart.isEmpty
                        ? null
                        : () => Navigator.pushNamed(
                            context, '/pelanggan',
                            arguments: total),
                    child: const Text('Lanjut ke Pembayaran')),
              ]),
        ),
      ]),
    );
  }
}
