import 'package:flutter/material.dart';
import '../core/theme.dart';

// 04 Pilih Shift — 3 opsi + modal awal
class ShiftScreen extends StatelessWidget {
  const ShiftScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const shifts = ['Shift Pagi (07-15)', 'Shift Siang (15-23)', 'Shift Malam (23-07)'];
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Shift')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ...shifts.map((s) => Card(
              child: ListTile(
                leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.mut,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.access_time,
                        color: AppColors.pri)),
                title: Text(s,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
              ),
            )),
        const SizedBox(height: 12),
        const Text('Modal awal kas (Rp)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                hintText: '500.000', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/katalog'),
            child: const Text('Mulai Shift')),
      ]),
    );
  }
}
