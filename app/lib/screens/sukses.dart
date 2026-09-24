import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';

// 11 Sukses — check + struk + cetak/bagi + transaksi baru
class SuksesScreen extends StatelessWidget {
  const SuksesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final m = args is Map ? args : {};
    final total = (m['total'] ?? 38610.0) as double;
    final paid = (m['paid'] ?? 50000.0) as double;
    final change = (m['change'] ?? 11390.0) as double;
    final method = (m['method'] ?? 'Tunai').toString();
    final struk = 'TOKO BERKAH JAYA\n'
        'Jl. Merdeka No.12 - 0812-3456-7890\n'
        'Total ${rp(total)}\n'
        '$method ${rp(paid)} - Kembali ${rp(change)}\n'
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
              child: Text('Tunai - ${DateTime.now().hour}.${DateTime.now().minute} WIB',
                  style:
                      const TextStyle(color: AppColors.mfg))),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(struk,
                  style: const TextStyle(fontFamily: 'monospace')),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: () =>
                  Share.share(struk, subject: 'Struk Berkah POS'),
              icon: const Icon(Icons.share),
              label: const Text('Bagikan via WA')),
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
