import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/theme.dart';

// 01 Splash — cek Supabase session: ada -> pulihkan membership -> /pilih.
// Tidak ada -> /login. Register selalu tersedia dari login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _S();
}

class _S extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      final db = ref.read(supabaseProvider);
      final sess = db.auth.currentSession;
      if (sess?.user != null) {
        final uid = sess!.user.id;
        final mem = await db.from('memberships').select().eq('user_id', uid)
            .eq('is_active', true).order('created_at').limit(1).maybeSingle();
        if (mem != null) {
          final store = await db.from('stores').select()
              .eq('id', mem['store_id'] as String).maybeSingle();
          ref.read(sessionProvider.notifier).set(PosSession(
            kind: LoginKind.owner,
            storeId: mem['store_id'] as String,
            storeName: (store?['name'] as String?) ?? 'Toko',
            actorId: uid,
            displayName: (mem['display_name'] as String?) ?? 'Owner',
            role: (mem['role'] as String?) ?? 'staff'));
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/pilih');
          return;
        }
      }
    } catch (_) {
      // jatuh ke login
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
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
          const SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation(Colors.white)),
          ),
        ]),
      ),
    );
  }
}
