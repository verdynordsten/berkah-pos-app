import 'package:flutter/material.dart';

/// Loading berputar standar aplikasi (pengganti teks "...").
/// [label] opsional — mis. "Memuat katalog".
class AppLoader extends StatelessWidget {
  final String? label;
  final double size;
  const AppLoader({super.key, this.label, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: size, height: size,
          child: const CircularProgressIndicator(strokeWidth: 3),
        ),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(label!,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ]),
    );
  }
}

/// Isi tombol saat busy: spinner kecil + label (tanpa "...").
class BusyLabel extends StatelessWidget {
  final String label;
  final Color color;
  const BusyLabel(this.label,
      {super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(color)),
      ),
      const SizedBox(width: 10),
      Text(label),
    ]);
  }
}
