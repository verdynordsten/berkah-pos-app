@echo off
REM ============================================================
REM  EMULATOR.bat — nyalain emulator TANPA buka Android Studio
REM  Taruh di berkah-pos-app\app\ , klik 2x. Jangan tutup jendelanya.
REM  Kalau nama AVD beda, edit baris set AVD=... (lihat via: emulator -list-avds)
REM ============================================================
title Emulator - Berkah POS
cd /d "%~dp0"

set AVD=Pixel_6_API_34

where emulator >nul 2>nul
if errorlevel 1 (
  echo   [X] 'emulator' tidak ada di PATH.
  echo   Tambahkan: C:\Users\%USERNAME%\AppData\Local\Android\Sdk\emulator
  echo   ke PATH, atau buka sekali via Android Studio Device Manager.
  pause
  exit /b 1
)

echo Nyalain emulator: %AVD%
echo Jendela ini JANGAN ditutup selama ngoding. Minimize aja.
echo.
emulator -avd %AVD% -netdelay none -netspeed full
pause
