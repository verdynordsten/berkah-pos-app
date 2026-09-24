import 'package:flutter/material.dart';
import 'theme.dart';

/// Bottom nav 4 tab root: Beranda / Keranjang / Riwayat / Lainnya.
/// Pakai pushReplacement (BUKAN push) biar stack tidak numpuk:
/// back dari tab mana pun = keluar app, tidak melompat ke tab lain.
class PosBottomNav extends StatelessWidget {
  final int current;
  const PosBottomNav({super.key, required this.current});

  static const _routes = ['/katalog', '/keranjang', '/riwayat', '/lainnya'];

  static void goTab(BuildContext context, int i, int current) {
    if (i == current) return;
    Navigator.pushReplacementNamed(context, _routes[i]);
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: current,
      selectedItemColor: AppColors.pri,
      unselectedItemColor: AppColors.mfg,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      onTap: (i) => goTab(context, i, current),
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home), label: 'Beranda'),
        BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart), label: 'Keranjang'),
        BottomNavigationBarItem(
            icon: Icon(Icons.receipt), label: 'Riwayat'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings), label: 'Lainnya'),
      ],
    );
  }
}
