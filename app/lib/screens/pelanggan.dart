import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';

// 08 Pelanggan — pilih / skip
class PelangganScreen extends ConsumerWidget {
  const PelangganScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const custs = [
      'Pelanggan Umum', 'Budi (0812-111)', 'Sari (0813-222)',
      'Agung (0819-333)', '+ Tambah Pelanggan'
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Pelanggan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const TextField(
            decoration: InputDecoration(
                hintText: 'Cari nama / nomor HP...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder())),
        const SizedBox(height: 12),
        ...custs.map((c) => Card(
              child: ListTile(
                leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.mut,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.person,
                        color: AppColors.pri)),
                title: Text(c),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.pushNamed(context, '/tunai'),
              ),
            )),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/tunai'),
            child: const Text('Lanjut Tanpa Member')),
      ]),
    );
  }
}
