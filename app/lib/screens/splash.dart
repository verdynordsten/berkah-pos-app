import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/last_session.dart';
import '../core/theme.dart';

// 01 Splash — rute awal cerdas (tahan app ke-kill / ke-swipe):
//  - Tidak ada auth Supabase -> /login.
//  - Ada auth + posisi terakhir tersimpan:
//    a. toko masih ada + membership aktif -> pulihkan sesi toko.
//    b. operator terakhir masih valid (owner PIN terpasang / staff aktif)
//       -> pulihkan operator, langsung /shift (Buka shift / lanjut).
//       PIN TETAP wajib di /pilih saat mau ganti operator — yang
//       dipulihkan cuma posisi, bukan akses tanpa verifikasi.
//    c. shift terakhir masih TERBUKA di DB -> pulihkan shift, langsung
//       /katalog (lanjut jualan). Shift yang sudah closed_at diabaikan.
//  - Posisi tidak valid / 1 toko saja -> /toko_list seperti dulu.
//  - Gagal total -> /login.
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
      if (db.auth.currentSession?.user == null) {
        return _go('/login');
      }
      final uid = db.auth.currentUser!.id;
      final spot = await LastSession.read();

      // Ada posisi terakhir -> coba pulihkan berlapis.
      if (spot != null) {
        // Lapis 1: toko + membership masih valid?
        final mem = await db.from('memberships').select()
            .eq('user_id', uid).eq('store_id', spot.storeId)
            .eq('is_active', true).maybeSingle();
        if (mem != null) {
          final store = await db.from('stores').select()
              .eq('id', spot.storeId).maybeSingle();
          if (store != null) {
            // Lapis 2: operator terakhir masih valid?
            var opOk = false;
            var display = spot.displayName;
            var role = spot.role;
            if (spot.kind == LoginKind.owner) {
              // Owner = yang login auth ini (tidak ganti akun).
              // PIN tetap diminta nanti saat pilih "masuk sebagai owner".
              opOk = true;
              display = (mem['display_name'] as String?) ?? display;
              role = (mem['role'] as String?) ?? role;
            } else {
              // Staff PIN: cek masih aktif di toko ini.
              try {
                final st = await db.from('staff').select('name,role')
                    .eq('id', spot.actorId).eq('store_id', spot.storeId)
                    .eq('is_active', true).maybeSingle();
                if (st != null) {
                  opOk = true;
                  display = (st['name'] as String?) ?? display;
                  final r = (st['role'] as String?)?.toLowerCase();
                  role = r == 'admin' ? 'admin' : 'kasir';
                }
              } catch (_) {}
            }
            if (opOk) {
              ref.read(sessionProvider.notifier).set(PosSession(
                kind: spot.kind, storeId: spot.storeId,
                storeName: (store['name'] as String?) ?? spot.storeName,
                actorId: spot.kind == LoginKind.owner
                    ? uid : spot.actorId,
                displayName: display.isEmpty ? 'Kasir' : display,
                role: role));
              // Lapis 3: shift terakhir masih TERBUKA?
              if (spot.shiftId != null) {
                try {
                  final sh = await db.from('shifts').select()
                      .eq('id', spot.shiftId!)
                      .eq('store_id', spot.storeId)
                      .isFilter('closed_at', null).maybeSingle();
                  if (sh != null) {
                    ref.read(shiftProvider.notifier).state =
                        (sh as Map).cast<String, dynamic>();
                    // Tulis ulang: SessionCtl.set tadi menghapus shift
                    // tersimpan (ganti sesi = reset shift).
                    await LastSession.saveShift(
                        spot.shiftId!, spot.shiftLabel);
                    return _go('/katalog');
                  }
                  // Shift sudah ditutup (mis. dari HP lain) -> buang.
                  await LastSession.clearShift();
                } catch (_) {}
              }
              // Toko + operator pulih, shift tidak -> tinggal buka shift.
              return _go('/shift');
            }
          }
        }
        // Posisi basi (toko dihapus / staff nonaktif / ganti akun):
        // buang biar tidak nyangkut, lanjut fallback lama.
        await LastSession.clearAll();
      }

      // Fallback lama: membership pertama -> /toko_list.
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
        return _go('/toko_list');
      }
    } catch (_) {
      // jatuh ke login
    }
    _go('/login');
  }

  void _go(String route) {
    if (mounted) Navigator.pushReplacementNamed(context, route);
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
