# Tutor Lengkap Jalanin Berkah POS (Windows, Nol -> App Jalan)

Target akhir: app kasir kebuka di HP Android (atau emulator),
katalog produk muncul dari Supabase, bisa checkout sampai struk.

Total waktu: ~45 menit kalau internet lancar.
Yang lo butuh: laptop Windows + HP Android + koneksi internet.

---

## BAGIAN A — Install Alat (15 menit, sekali seumur hidup)

### A1. Install Git

1. Buka https://git-scm.com/download/win
2. Download 64-bit, install next-next aja (default semua)
3. Verifikasi — buka CMD, ketik:
```bat
git --version
```
Harus keluar `git version 2.x`. Kalau error, restart laptop dulu.

### A2. Install Flutter (engine app-nya)

1. Buka https://docs.flutter.dev/get-started/install/windows
2. Download `flutter_windows_3.x-stable.zip` (~1.2 GB)
3. Extract ke `C:\src\flutter` (PENTING: path tanpa spasi!
   Jangan taruh di `C:\Program Files\` — bakal error)
4. Tambah ke PATH:
   - Tekan Win > ketik `env` > "Edit the system environment variables"
   - Environment Variables > Path (user) > Edit > New >
     `C:\src\flutter\bin` > OK semua
5. Verifikasi — buka CMD BARU, ketik:
```bat
flutter --version
```
Harus keluar `Flutter 3.x • channel stable`.

### A3. Install Android Studio (emulator + SDK)

1. Buka https://developer.android.com/studio, download, install default
2. Buka Android Studio > More Actions > SDK Manager >
   centang Android 14 (API 34) > OK (download ~3 GB, tungguin)
3. Bikin emulator: More Actions > Virtual Device Manager >
   Create Device > Pixel 7 > System Image API 34 > Finish
4. Balik ke CMD, ketik:
```bat
flutter doctor
```
Target: centang hijau `[✓] Flutter`, `[✓] Android toolchain`,
`[✓] Android Studio`. Kalau ada `[!]` baca pesannya —
biasanya tinggal `flutter doctor --android-licenses` (ketik `y` semua).

### A4. Install VS Code (editor, opsional tapi disarankan)

1. https://code.visualstudio.com, install
2. Extensions (Ctrl+Shift+X): install `Flutter` + `Dart`
   (otomatis dari Dart-Code.org)

---

## BAGIAN B — Supabase / Database (10 menit, sekali aja)

### B1. Bikin project

1. Buka https://supabase.com > Sign Up (pakai GitHub lebih cepat)
2. New Project > nama `berkah-pos` > password DB bebas (catat!) >
   region `Singapore` (terdekat) > Create (tunggu ~2 menit)

### B2. Bikin tabel (copy-paste)

1. Di dashboard Supabase: SQL Editor (ikon `</>` kiri) > New query
2. Buka file `supabase/schema.sql` dari repo (Notepad juga bisa),
   copy SEMUA isinya, paste ke SQL Editor, klik Run (Ctrl+Enter)
3. Harus keluar `Success. No rows returned`. Kalau merah,
   screenshot errornya ke gue.
4. Cek: Table Editor > harus ada 8 tabel
   (stores, categories, products, customers, shifts,
   transactions, transaction_items, stock_moves)
5. Cek seed: Table Editor > products > harus ada 6 baris
   (Kopi Tubruk, Teh Botol, Indomie, Roti, Susu, Chitato).
   Kalau kosong, berarti seed gagal — ulangi B2.

### B3. Catat 2 kunci (jangan share ke siapa pun)

1. Project Settings (ikon gear) > API
2. Catat ke Notepad:
   - `Project URL` → misal `https://xyz.supabase.co`
   - `anon public` key → string panjang `eyJhbGciOi...`
3. Ini yang dipakai app buat konek. Yang `service_role`
   JANGAN dipakai di app (itu kunci admin).

---

## BAGIAN C — Clone + Jalanin App (10 menit)

### C1. Clone repo

```bat
cd C:\
git clone https://github.com/verdynordsten/berkah-pos-app.git
cd berkah-pos-app\app
```

### C2. Install package

```bat
flutter pub get
```
Tunggu sampai `Got dependencies!` (~2 menit pertama).
Verified di server: 119 packages, `flutter analyze` = No issues.

### C3. Jalanin (pilih SALAH SATU)

**Opsi 1 — Emulator (tanpa HP):**
```bat
flutter emulators --launch Pixel_7
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```
Ganti xyz + eyJ... dengan kunci lo dari B3.

**Opsi 2 — HP Android asli (lebih cepat + bisa scan barcode):**
1. HP > Settings > About Phone > tap `Build Number` 7x
   (sampai "You are now a developer!")
2. Settings > Developer Options > nyalakan `USB Debugging`
3. Colok HP ke laptop via USB > di HP tap Allow
4. Verifikasi:
```bat
flutter devices
```
Harus muncul HP lo (misal `SM A546G • android`).
5. Jalanin (sama kayak emulator):
```bat
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

### C4. Flow test (validasi app beneran jalan)

1. Splash biru 2 detik → Login → Masuk
2. PIN: ketik `123456` (PIN apa aja 6 digit lolos di v1)
3. Shift: tap "Mulai Shift" (tanpa isi modal juga bisa)
4. Katalog: 6 produk muncul + search "kopi" nyaring bener
5. Tap produk 2-3x → bar "Lihat Keranjang" muncul
6. Keranjang → "Lanjut ke Pembayaran" → "Lanjut Tanpa Member"
7. Tunai: tap Rp 50rb → kembalian hijau → "Selesaikan Transaksi"
8. Sukses: struk muncul → "Bagikan via WA" → share kebuka
9. Cek Supabase: Table Editor > transactions > ada 1 baris baru.
   Kalau ada = FULL LOOP BERHASIL. 🎉

---

## BAGIAN D — Troubleshooting (yang paling sering kejadian)

| Gejala | Penyebab | Fix |
|---|---|---|
| `flutter` not recognized | PATH belum kepasang / CMD lama | CMD baru, cek `C:\src\flutter\bin` ada di PATH |
| `Unable to locate Android SDK` | SDK belum install / path spasi | Install via Android Studio, path `C:\Users\<nama>\AppData\Local\Android\Sdk` |
| `No devices found` | Emulator mati / USB debug off | Nyalakan emulator dulu ATAU `flutter devices` ulang setelah Allow USB |
| Katalog kosong, spinner muter | URL/key salah ATAU RLS块 | Cek `--dart-define` ketik bener; di Supabase cek Table Editor products ada isinya |
| `Gagal simpan (cek Supabase)` pas bayar | RLS policy / tabel belum dibuat | Ulangi B2 (Run schema.sql), pastikan `Success` |
| Gradle download lama pertama kali | Normal (~5-10 mnt) | Tungguin, jangan cancel. Berikutnya cepat |
| HP panas / lag di emulator | Emulator berat | Pakai HP asli (Opsi 2), jauh lebih enteng |
| Error merah lain | — | Copy FULL error dari CMD (klik kanan > Select All), kirim ke gue |

---

## BAGIAN E — Build File Rilis (kalau mau install permanen / bagi ke toko)

```bat
REM APK buat bagi-bagi via WA (install langsung di HP)
flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
REM hasil: build\app\outputs\flutter-apk\app-release.apk

REM App Bundle buat upload Play Store ($25 sekali daftar)
flutter build appbundle --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
REM hasil: build\app\outputs\bundle\release\app-release.aab
```

CATATAN PENTING: `--dart-define` harus diulang tiap build —
kunci Supabase dibakar ke app pas compile, bukan dibaca pas jalan.
Kalau ganti project Supabase, build ulang.

---

## iOS (nanti, butuh Mac)

Kode sama 100% (1 codebase). Tapi compile iOS wajib di macOS
+ Xcode + Apple Developer $99/thn. Dari Windows nggak bisa.
Jalur termurah tanpa Mac: Codemagic (500 menit free/bulan) —
nanti gue bikinin `codemagic.yaml` kalau lo butuh.
