import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Warna dari desain pen.dev (15 variables -> 8 inti)
class AppColors {
  static const pri = Color(0xFF2563EB);
  static const onPri = Colors.white;
  static const acc = Color(0xFFEA580C);
  static const bg = Color(0xFFF8FAFC);
  static const fg = Color(0xFF1E293B);
  static const card = Colors.white;
  static const mut = Color(0xFFE9EFF8);
  static const mfg = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const ok = Color(0xFF16A34A);
  static const okBg = Color(0xFFF0FDF4);
  static const dan = Color(0xFFDC2626);
  static const danBg = Color(0xFFFEF2F2);
  static const warn = Color(0xFFD97706);
}

ThemeData appTheme() {
  final base = ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.pri);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: GoogleFonts.outfitTextTheme(base.textTheme),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: AppColors.card,
      foregroundColor: AppColors.fg,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.acc,
        foregroundColor: Colors.white,
        minimumSize: const Size(358, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        textStyle: GoogleFonts.outfit(
          fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

String rp(num n) {
  // Rp 38.610 (titik ribuan, tanpa desimal)
  final s = n.toInt().toString();
  final buf = StringBuffer();
  var c = 0;
  for (var i = s.length - 1; i >= 0; i--) {
    buf.write(s[i]);
    if (++c == 3 && i > 0) {
      buf.write('.');
      c = 0;
    }
  }
  return 'Rp ${buf.toString().split('').reversed.join()}';
}
