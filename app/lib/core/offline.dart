import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'store.dart';

// F7/Gap5b — Mode offline: antre transaksi saat internet mati (SQLite),
// sync otomatis saat online. Status koneksi global via connectivityProvider.

/// true = online, false = offline.
final connectivityProvider =
    StreamProvider<bool>((ref) {
  final c = Connectivity();
  return c.onConnectivityChanged.map((r) =>
      !r.contains(ConnectivityResult.none)).distinct();
});

/// Antrean offline (SQLite lokal): 1 baris = 1 transaksi + items JSON.
class OfflineQueue {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await openDatabase('berkah_offline.db', version: 1,
        onCreate: (d, _) async {
      await d.execute('''CREATE TABLE queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL)''');
    });
    return _db!;
  }

  static Future<int> count() async {
    final d = await db;
    final r = await d.rawQuery('SELECT COUNT(*) c FROM queue');
    return ((r.first['c'] as num?) ?? 0).toInt();
  }

  static Future<void> push(String storeId, Map<String, dynamic> trx) async {
    final d = await db;
    await d.insert('queue', {
      'store_id': storeId,
      'payload': jsonEncode(trx),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> peek(String storeId,
      {int limit = 20}) async {
    final d = await db;
    final rows = await d.query('queue',
        where: 'store_id = ?', whereArgs: [storeId],
        orderBy: 'id ASC', limit: limit);
    return rows
        .map((r) => {
              'qid': r['id'],
              'payload':
                  jsonDecode(r['payload'] as String) as Map<String, dynamic>
            })
        .toList();
  }

  static Future<void> remove(int qid) async {
    final d = await db;
    await d.delete('queue', where: 'id = ?', whereArgs: [qid]);
  }
}

/// Jumlah antrean offline toko aktif (untuk badge di katalog).
final offlineCountProvider = FutureProvider<int>((ref) async {
  final s = ref.watch(sessionProvider);
  if (s == null) return 0;
  // Refresh saat koneksi berubah.
  ref.watch(connectivityProvider);
  return OfflineQueue.count();
});

/// Kirim semua antrean toko ini ke Supabase. Return (sukses, gagal).
/// Dipanggil otomatis saat online / tombol "Sync" manual.
Future<(int, int)> syncOfflineQueue(dynamic db, String storeId) async {
  final items = await OfflineQueue.peek(storeId, limit: 50);
  var ok = 0, fail = 0;
  for (final q in items) {
    final p = q['payload'] as Map<String, dynamic>;
    try {
      final lines = (p['lines'] as List).cast<Map<String, dynamic>>();
      final trx = await db.from('transactions').insert({
        'store_id': storeId,
        'shift_id': p['shift_id'],
        'customer_id': p['customer_id'],
        'code': p['code'],
        'subtotal': p['subtotal'], 'discount': p['discount'],
        'tax': p['tax'], 'total': p['total'],
        'pay_method': p['pay_method'], 'paid': p['paid'],
        'change': p['change'],
        'order_type': p['order_type'] ?? 'takeaway',
        if (p['table_no'] != null) 'table_no': p['table_no'],
      }).select('id').single();
      for (final l in lines) {
        await db.from('transaction_items').insert({
          'transaction_id': trx['id'],
          'product_id': l['product_id'],
          'name': l['name'], 'price': l['price'],
          'qty': l['qty'], 'line_total': l['line_total'],
        });
        await db.from('stock_moves').insert({
          'store_id': storeId, 'product_id': l['product_id'],
          'qty': -(l['qty'] as int), 'reason': 'sale',
        });
        try {
          final cur = await db.from('products').select('stock')
              .eq('id', l['product_id'] as String).single();
          final next = (((cur['stock'] as num?) ?? 0).toInt()) -
              ((l['qty'] as num?) ?? 0).toInt();
          await db.from('products')
              .update({'stock': next < 0 ? 0 : next})
              .eq('id', l['product_id'] as String);
        } catch (_) {}
      }
      await OfflineQueue.remove(q['qid'] as int);
      ok++;
    } catch (_) {
      fail++;
    }
  }
  return (ok, fail);
}
