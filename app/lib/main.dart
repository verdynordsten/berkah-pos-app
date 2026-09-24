import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'screens/splash.dart';
import 'screens/login.dart';
import 'screens/pin.dart';
import 'screens/shift.dart';
import 'screens/katalog.dart';
import 'screens/detail.dart';
import 'screens/keranjang.dart';
import 'screens/pelanggan.dart';
import 'screens/bayar_tunai.dart';
import 'screens/bayar_qris.dart';
import 'screens/sukses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Kunci dibaca dari file .env (runtime). Prioritas:
  // 1. --dart-define (kalau diisi, menang)  2. file .env  3. kosong (mode offline)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env belum ada — lanjut dengan dart-define / mode offline
  }
  const defineUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const defineKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  final url = defineUrl.isNotEmpty ? defineUrl : (dotenv.env['SUPABASE_URL'] ?? '');
  final key = defineKey.isNotEmpty ? defineKey : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');
  if (url.isNotEmpty && key.isNotEmpty) {
    // ignore: deprecated_member_use (supabase_flutter 2.x masih pakai anonKey)
    await Supabase.initialize(url: url, anonKey: key);
  }
  runApp(const ProviderScope(child: BerkahPos()));
}

class BerkahPos extends StatelessWidget {
  const BerkahPos({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Berkah POS',
      theme: appTheme(),
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/pin': (_) => const PinScreen(),
        '/shift': (_) => const ShiftScreen(),
        '/katalog': (_) => const KatalogScreen(),
        '/detail': (_) => const DetailScreen(),
        '/keranjang': (_) => const KeranjangScreen(),
        '/pelanggan': (_) => const PelangganScreen(),
        '/tunai': (_) => const BayarTunaiScreen(),
        '/qris': (_) => const BayarQrisScreen(),
        '/sukses': (_) => const SuksesScreen(),
      },
    );
  }
}
