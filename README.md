# Berkah POS — Flutter + Supabase (Android + iOS)

App kasir toko retail. 1 codebase untuk Android & iOS.
Desain ngikutin `kasir-pos-design` (19 screens pen.dev).

## 1. Supabase (5 menit, sekali aja)

1. Bikin project di https://supabase.com (free tier cukup)
2. Dashboard > SQL Editor > New query > copy-paste isi
   `supabase/schema.sql` > Run (bikin 8 tabel + RLS + seed demo)
3. Project Settings > API > catat `Project URL` + `anon public key`

## 2. Jalanin app

```bash
cd app
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Tanpa Supabase pun app kebuka (splash > login > PIN > shift),
tapi katalog kosong + bayar gagal simpan (ada pesan error jelas).

## 3. Struktur

- `app/lib/main.dart` — entry + routes 11 screen
- `app/lib/core/theme.dart` — warna/font dari desain (Outfit + biru #2563EB)
- `app/lib/core/store.dart` — models + Riverpod (cart, products, categories)
- `app/lib/screens/` — splash/login/pin/shift/katalog/detail/
  keranjang/pelanggan/bayar_tunai/bayar_qris/sukses
- `supabase/schema.sql` — 8 tabel + RLS + seed

## 4. Mapping desain -> app

| pen.dev (19) | Flutter (11 v1) | Keterangan |
|---|---|---|
| 01 Splash | splash.dart | ✅ |
| 02 Login | login.dart | ✅ |
| 03 PIN | pin.dart | ✅ |
| 04 Shift | shift.dart | ✅ |
| 05 Katalog | katalog.dart | ✅ + Supabase live |
| 06 Detail | detail.dart | ✅ placeholder |
| 07 Keranjang | keranjang.dart | ✅ promo+pajak |
| 08 Pelanggan | pelanggan.dart | ✅ |
| 09 Tunai | bayar_tunai.dart | ✅ + simpan trx |
| 10 QRIS | bayar_qris.dart | ✅ QR real |
| 11 Sukses | sukses.dart | ✅ share WA |
| 12 Struk | (gabung sukses) | v2 |
| 13-14 Riwayat | — | v2 |
| 15 Tutup Shift | — | v2 |
| 16-17 Stok | — | v2 |
| 18 Laporan | — | v2 |
| 19 Pengaturan | — | v2 |

## 5. Release

- Android: `flutter build appbundle` > Play Console ($25 sekali)
- iOS: butuh Mac + Apple Developer ($99/thn) + D-U-N-S (organisasi)
