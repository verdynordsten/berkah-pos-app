import 'package:flutter/material.dart';
import '../core/theme.dart';

// 03 PIN Kasir — numpad 3x4
class PinScreen extends StatefulWidget {
  const PinScreen({super.key});
  @override
  State<PinScreen> createState() => _P();
}

class _P extends State<PinScreen> {
  String pin = '';
  void tap(String k) {
    setState(() {
      if (k == 'X') {
        if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
      } else if (pin.length < 6) {
        pin += k;
      }
    });
    if (pin.length == 6) {
      Navigator.pushReplacementNamed(context, '/shift');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dots = List.generate(6, (i) => i < pin.length ? '●' : '○').join(' ');
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'X'];
    return Scaffold(
      appBar: AppBar(title: const Text('Masukkan PIN')),
      body: Column(children: [
        const SizedBox(height: 24),
        const Text('Andi - Shift Pagi',
            style: TextStyle(color: AppColors.mfg)),
        const SizedBox(height: 8),
        Text(dots,
            style: const TextStyle(
                fontSize: 26, color: AppColors.pri, letterSpacing: 4)),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(24),
            children: keys
                .map((k) => k.isEmpty
                    ? const SizedBox()
                    : InkWell(
                        onTap: () => tap(k),
                        child: Center(
                            child: Text(k,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600)))))
                .toList(),
          ),
        ),
      ]),
    );
  }
}
