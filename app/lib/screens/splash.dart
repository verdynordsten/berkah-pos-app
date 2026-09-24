import 'package:flutter/material.dart';
import '../core/theme.dart';

// 01 Splash — biru penuh, logo toko, nama, versi
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _S();
}

class _S extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2),
        () => Navigator.pushReplacementNamed(context, '/login'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pri,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(26)),
            child: const Icon(Icons.store, size: 48, color: AppColors.pri),
          ),
          const SizedBox(height: 14),
          const Text('Berkah POS',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const Text('Kasir cepat untuk toko Anda',
              style: TextStyle(fontSize: 14, color: Colors.white)),
          const SizedBox(height: 6),
          const Text('v1.0.0',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 40),
          const Text('Memuat...',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      ),
    );
  }
}
