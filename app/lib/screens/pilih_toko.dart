import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store.dart';
import '../core/loading.dart';

// F6/Gap5c — Pilih Toko: 1 akun bisa punya BANYAK toko (outlet).
// Muncul setelah login owner: pilih toko aktif / tambah toko baru.
class PilihTokoScreen extends ConsumerStatefulWidget {
  const PilihTokoScreen({super.key});
  @override
  ConsumerState<PilihTokoScreen> createState() => _PT();
}

class _PT extends ConsumerState<PilihTokoScreen> {
  bool loading = true;
  String? err;
  List<Map<String, dynamic>> tokos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      final db = ref.read(supabaseProvider);
      final u = db.auth.currentUser;
      if (u == null) throw StateError('Belum login.');
      final mems = await db.from('memberships').select()
          .eq('user_id', u.id).eq('is_active', true).order('created_at');
      final list = (mems as List).cast<Map<String, dynamic>>();
      final out = <Map<String, dynamic>>[];
      for (final m in list) {
        final st = await db.from('stores').select('id,name')
            .eq('id', m['store_id'] as String).maybeSingle();
        out.add({
          'store_id': m['store_id'],
          'store_name': (st?['name'] ?? 'Toko') as String,
          'role': (m['role'] ?? 'staff').toString(),
          'display_name': (m['display_name'] ?? 'Owner').toString(),
        });
      }
      tokos = out;
    } catch (e) {
      err = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _enter(Map<String, dynamic> t) {
    final db = ref.read(supabaseProvider);
    final u = db.auth.currentUser;
    ref.read(sessionProvider.notifier).set(PosSession(
      kind: LoginKind.owner,
      storeId: t['store_id'] as String,
      storeName: t['store_name'] as String,
      actorId: u?.id ?? '',
      displayName: t['display_name'] as String,
      role: t['role'] as String,
    ));
    Navigator.pushReplacementNamed(context, '/pilih');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Toko')),
      body: loading
          ? const AppLoader(label: 'Memuat toko')
          : err != null
              ? Center(child: Text('Gagal: $err'))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const Text('Mau kelola toko yang mana?',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (final t in tokos)
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.store)),
                        title: Text('${t['store_name']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${t['display_name']} — ${(t['role'] as String).toUpperCase()}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _enter(t),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                        context, '/toko_baru', arguments: {'multi': true}),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Toko Baru'),
                  ),
                ]),
    );
  }
}
