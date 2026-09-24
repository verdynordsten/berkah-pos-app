import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/loading.dart';
import '../core/bottom_nav.dart';

// 12 Riwayat Transaksi — list transaksi toko aktif (terbaru dulu).
// Tap item -> detail item + total.
class RiwayatScreen extends ConsumerWidget {
  const RiwayatScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      bottomNavigationBar: const PosBottomNav(current: 2),
      body: s == null
          ? const Center(child: Text('Belum login.'))
          : FutureBuilder(
              future: ref.watch(supabaseProvider).from('transactions')
                  .select()
                  .eq('store_id', s.storeId)
                  .order('created_at', ascending: false)
                  .limit(100),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Gagal: ${snap.error}'));
                }
                final list = (snap.data as List?) ?? [];
                if (list.isEmpty) {
                  return const Center(
                      child: Text(
                          'Belum ada transaksi.\nJual pertama dari katalog!',
                          textAlign: TextAlign.center));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t =
                        (list[i] as Map).cast<String, dynamic>();
                    return Card(
                      child: ListTile(
                        leading: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                                color: AppColors.mut,
                                borderRadius:
                                    BorderRadius.circular(12)),
                            child: const Icon(Icons.receipt,
                                color: AppColors.pri)),
                        title: Text('${t['code']} — ${t['pay_method']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${(t['created_at'] as String?)?.substring(0, 16).replaceAll('T', ' ') ?? ''}'),
                        trailing: Text(
                            rp((t['total'] as num?) ?? 0),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.pri)),
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => _DetailTrx(
                              id: t['id'] as String,
                              code:
                                  '${t['code']} — ${t['pay_method']}',
                              payMethod:
                                  (t['pay_method'] ?? '').toString(),
                              total: (t['total'] as num?) ?? 0),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _DetailTrx extends ConsumerWidget {
  final String id;
  final String code;
  final String payMethod;
  final num total;
  const _DetailTrx(
      {required this.id,
      this.code = '',
      this.payMethod = '',
      this.total = 0});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text(code.isEmpty ? 'Detail Transaksi' : code),
      content: FutureBuilder(
        future: ref.watch(supabaseProvider)
            .from('transaction_items')
            .select()
            .eq('transaction_id', id),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
                height: 80, child: AppLoader(label: 'Memuat item'));
          }
          if (snap.hasError) {
            return Text('Gagal: ${snap.error}');
          }
          final items = (snap.data as List?) ?? [];
          if (items.isEmpty) {
            return const Text('Tidak ada item.');
          }
          return SizedBox(
            width: double.maxFinite,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items.map((e) {
                    final m = (e as Map).cast<String, dynamic>();
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(
                                    '${m['name']} x${m['qty']}')),
                            Text(rp(
                                (m['line_total'] as num?) ?? 0)),
                          ]),
                    );
                  }),
                  const Divider(),
                  Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(payMethod,
                            style: const TextStyle(
                                color: AppColors.mfg)),
                        Text(rp(total),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ]),
                ]),
          );
        },
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup')),
      ],
    );
  }
}
