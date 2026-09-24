import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';

// 12 Riwayat Transaksi — list transaksi toko aktif (terbaru dulu).
// Tap item -> detail item + total.
class RiwayatScreen extends ConsumerWidget {
  const RiwayatScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
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
                          builder: (_) => _DetailTrx(id: t['id'] as String),
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
  const _DetailTrx({required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Detail Transaksi'),
      content: FutureBuilder(
        future: ref.watch(supabaseProvider)
            .from('transaction_items')
            .select()
            .eq('transaction_id', id),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()));
          }
          final items = (snap.data as List?) ?? [];
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
