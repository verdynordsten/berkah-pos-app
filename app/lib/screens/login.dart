import 'package:flutter/material.dart';
import '../core/theme.dart';

// 02 Login — username + password + fingerprint
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.mut,
              borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.store, size: 36, color: AppColors.pri),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
            child: Text('Selamat Datang',
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
        const Center(
            child: Text('Masuk untuk mulai berjualan',
                style: TextStyle(color: AppColors.mfg))),
        const SizedBox(height: 16),
        const Text('Username',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const TextField(decoration: InputDecoration(
            hintText: 'andi_kasir', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('Password',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const TextField(
            obscureText: true,
            decoration: InputDecoration(
                hintText: '••••••••', border: OutlineInputBorder())),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
              onPressed: () {},
              child: const Text('Lupa password?')),
        ),
        FilledButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/pin'),
            child: const Text('Masuk')),
        const SizedBox(height: 8),
        const Center(
            child: Text('atau masuk dengan fingerprint',
                style:
                    TextStyle(fontSize: 12, color: AppColors.mfg))),
      ]),
    );
  }
}
