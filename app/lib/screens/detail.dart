import 'package:flutter/material.dart';
import '../core/theme.dart';

// 06 Detail Produk — placeholder (navigasi dari katalog bawa argumen)
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Produk')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
            height: 200,
            decoration: BoxDecoration(
                color: AppColors.mut,
                borderRadius: BorderRadius.circular(16)),
            child: const Center(
                child:
                    Icon(Icons.inventory_2, size: 64, color: AppColors.mfg))),
        const SizedBox(height: 10),
        const Text('Kopi Tubruk 200g',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const Text('Minuman - Stok 42',
            style: TextStyle(color: AppColors.mfg)),
        const Text('Rp 28.000',
            style: TextStyle(
                fontSize: 24,
                color: AppColors.pri,
                fontWeight: FontWeight.w700)),
        const Text('Kopi tubruk asli, sangrai medium, kemasan 200 gram.',
            style: TextStyle(color: AppColors.mfg)),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tambah ke Keranjang')),
      ]),
    );
  }
}
