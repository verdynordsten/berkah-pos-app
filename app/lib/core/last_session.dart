import 'package:shared_preferences/shared_preferences.dart';
import 'store.dart';

/// Posisi terakhir pemakaian app, disimpan di device (SharedPreferences).
/// Dipakai Splash biar app yang ke-swipe/kill balik ke posisi terakhir
/// (toko > operator > shift), bukan mentok di Pilih Toko.
///
/// KEAMANAN: yang disimpan cuma ID + nama tampilan (bukan PIN / password).
/// Masuk sebagai operator TETAP wajib PIN seperti biasa — file ini cuma
/// ngasih tahu "terakhir di toko X sebagai Y", verifikasi tetap via PIN.
class LastSession {
  static const _kStoreId = 'last_store_id';
  static const _kStoreName = 'last_store_name';
  static const _kKind = 'last_kind'; // 'owner' | 'staffPin'
  static const _kActorId = 'last_actor_id';
  static const _kDisplay = 'last_display_name';
  static const _kRole = 'last_role';
  static const _kShiftId = 'last_shift_id';
  static const _kShiftLabel = 'last_shift_label';

  /// Simpan posisi toko + operator aktif (dipanggil tiap ganti toko /
  /// pilih operator). Shift dikosongkan — diisi lagi pas buka shift.
  static Future<void> saveSpot(PosSession s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kStoreId, s.storeId);
    await p.setString(_kStoreName, s.storeName);
    await p.setString(
        _kKind, s.kind == LoginKind.owner ? 'owner' : 'staffPin');
    await p.setString(_kActorId, s.actorId);
    await p.setString(_kDisplay, s.displayName);
    await p.setString(_kRole, s.role);
    await p.remove(_kShiftId);
    await p.remove(_kShiftLabel);
  }

  /// Simpan shift aktif (dipanggil pas buka shift sukses).
  static Future<void> saveShift(String id, String label) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kShiftId, id);
    await p.setString(_kShiftLabel, label);
  }

  /// Buang shift tersimpan (dipanggil pas tutup shift / ganti operator).
  static Future<void> clearShift() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kShiftId);
    await p.remove(_kShiftLabel);
  }

  /// Buang SEMUA posisi tersimpan (dipanggil pas logout / keluar).
  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    for (final k in [
      _kStoreId, _kStoreName, _kKind, _kActorId,
      _kDisplay, _kRole, _kShiftId, _kShiftLabel,
    ]) {
      await p.remove(k);
    }
  }

  /// Baca posisi tersimpan. Return null kalau belum pernah simpan.
  static Future<_Spot?> read() async {
    final p = await SharedPreferences.getInstance();
    final storeId = p.getString(_kStoreId);
    if (storeId == null || storeId.isEmpty) return null;
    return _Spot(
      storeId: storeId,
      storeName: p.getString(_kStoreName) ?? 'Toko',
      kind: p.getString(_kKind) == 'staffPin'
          ? LoginKind.staffPin
          : LoginKind.owner,
      actorId: p.getString(_kActorId) ?? '',
      displayName: p.getString(_kDisplay) ?? '',
      role: p.getString(_kRole) ?? 'staff',
      shiftId: p.getString(_kShiftId),
      shiftLabel: p.getString(_kShiftLabel) ?? '',
    );
  }
}

class _Spot {
  final String storeId, storeName;
  final LoginKind kind;
  final String actorId, displayName, role;
  final String? shiftId;
  final String shiftLabel;
  const _Spot({required this.storeId, required this.storeName,
    required this.kind, required this.actorId, required this.displayName,
    required this.role, this.shiftId, required this.shiftLabel});
}
