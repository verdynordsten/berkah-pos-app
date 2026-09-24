import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../core/store.dart';
import '../core/theme.dart';

// 11 Sukses — struk REAL (toko + kasir + jam + metode) + cetak + bagi + baru.
class SuksesScreen extends ConsumerWidget {
  const SuksesScreen({super.key});

  Future<void> _print(String struk) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (_) => pw.Text(struk,
          style: const pw.TextStyle(fontSize: 10)),
    ));
    await Printing.layoutPdf(
        onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final m = args is Map ? args : {};
    final total = ((m['total'] as num?) ?? 0).toDouble();
    final paid = ((m['paid'] as num?) ?? 0).toDouble();
    final change = ((m['change'] as num?) ?? 0).toDouble();
    final method = (m['method'] ?? 'Tunai').toString();
    final promoName = (m['promo_name'] ?? '').toString();
    final orderType = (m['order_type'] ?? '').toString();
    final tableNo = (m['table_no'] ?? '').toString();
    final earned = ((m['earned_points'] as num?) ?? 0).toInt();
    final s = ref.watch(sessionProvider);
    final storeAsync = ref.watch(storeProfileProvider);
    final sp = storeAsync.valueOrNull;
    final now = DateTime.now();
    final jam =
        '${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
    final orderLabel = orderType == 'dinein'
        ? 'Makan di sini${tableNo.isNotEmpty ? ' — Meja $tableNo' : ''}'
        : orderType == 'delivery'
            ? 'Antar'
            : orderType == 'takeaway'
                ? 'Bawa pulang'
                : '';
    final struk =
        '${((sp?['name'] as String?) ?? s?.storeName ?? 'TOKO').toUpperCase()}\n'
        '${(sp?['address'] as String?) ?? ''}${(sp?['phone'] as String?) != null ? ' - ${sp!['phone']}' : ''}\n'
        'Kasir: ${s?.displayName ?? '-'}  $jam WIB\n'
        '${orderLabel.isNotEmpty ? '$orderLabel\n' : ''}'
        '--------------------------------\n'
        'Total ${rp(total)}\n'
        '${promoName.isNotEmpty ? 'Promo: $promoName\n' : ''}'
        '$method ${rp(paid)} - Kembali ${rp(change)}\n'
        '${earned > 0 ? '+$earned poin member\n' : ''}'
        'Terima kasih!';
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(
                  color: AppColors.okBg, shape: BoxShape.circle),
              child: const Icon(Icons.check,
                  size: 44, color: AppColors.ok),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
              child: Text('Pembayaran Berhasil',
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w700))),
          Center(
              child: Text('$method - $jam WIB',
                  style:
                      const TextStyle(color: AppColors.mfg))),
          const SizedBox(height: 16),
          if ((m['offline'] == true))
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warn)),
              child: const Row(children: [
                Icon(Icons.cloud_off, color: AppColors.warn),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Tersimpan offline — otomatis terkirim saat online.')),
              ]),
            ),
          if ((m['offline'] == true)) const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(struk,
                  style:
                      const TextStyle(fontFamily: 'monospace')),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: () =>
                  Share.share(struk, subject: 'Struk Belanja'),
              icon: const Icon(Icons.share),
              label: const Text('Bagikan via WA')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: () => _print(struk),
              icon: const Icon(Icons.print),
              label: const Text('Cetak Struk')),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/katalog', (_) => false),
              child: const Text('Transaksi Baru +')),
        ]),
      ),
    );
  }
}
