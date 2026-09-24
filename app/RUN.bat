@echo off
REM ============================================================
REM  Berkah POS — RUN.bat (Windows, klik 2x langsung jalan)
REM  Taruh file ini di dalam folder: berkah-pos-app\app\
REM  Contoh: C:\berkah-pos-app\app\RUN.bat
REM ============================================================
title Berkah POS - runner

REM --- Pindah ke folder file ini (wajib! biar pubspec.yaml ketemu) ---
cd /d "%~dp0"
echo Folder kerja: %CD%
echo.

REM --- GANTI 2 BARIS INI DENGAN KUNCI SUPABASE LO ---
set SUPABASE_URL=https://xyz.supabase.co
set SUPABASE_ANON_KEY=eyJhbGciOi...

echo.
echo  [1/4] Cek Flutter...
flutter --version || (echo   [X] Flutter tidak ketemu. Install dulu + tambah ke PATH. & pause & exit /b 1)

echo.
echo  [2/4] Cek device (HP / emulator nyala?)...
flutter devices

echo.
echo  [3/4] Install package (pertama kali agak lama)...
call flutter pub get || (echo   [X] pub get gagal. Cek internet. & pause & exit /b 1)

echo.
echo  [4/4] Jalanin app ke device pertama yang ketemu...
echo  Kalau ada lebih dari 1 device, tutup salah satu ATAU
echo  jalankan manual: flutter run -d <device-id> ...
echo.
call flutter run --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY% || (echo   [X] flutter run gagal. Baca error merah di atas. & pause & exit /b 1)

echo.
echo  SUKSES — app jalan. Tekan r = hot reload, R = restart, q = keluar.
pause
