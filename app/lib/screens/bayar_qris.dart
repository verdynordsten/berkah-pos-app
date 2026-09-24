import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme.dart';

// 10 Bayar QRIS — QR + timer + status
class BayarQrisScreen extends StatelessWidget {
  const BayarQrisScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final total = args is double ? args : 38610.0;
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
            child: QrImageView(
              data: 'berkahpos://pay?amount=${total.toInt()}',
              version: QrVersions.auto,
              size: 220,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
            child: Text('Scan kode di atas dengan e-wallet / m-banking',
                style: TextStyle(color: AppColors.mfg))),
        const Center(
            child: Text('Berlaku 04:59',
                style: TextStyle(
                    color: AppColors.warn,
                    fontWeight: FontWeight.w700))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.mut,
              borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('Menunggu pembayaran...')),
        ),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: () => Navigator.pushReplacementNamed(
                context, '/sukses',
                arguments: {
                  'total': total, 'paid': total,
                  'change': 0.0, 'method': 'QRIS'
                }),
            child: const Text('Saya Sudah Bayar')),
      ]),
    );
  }
}
