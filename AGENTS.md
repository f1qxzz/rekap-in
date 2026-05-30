# Agent Rules for Absensi

Gunakan file ini sebagai aturan kerja agent untuk repo `D:\absensi`.

## Bahasa dan Gaya

- Jawab user dengan bahasa Indonesia yang natural, ringkas, tegas, dan tidak lebay.
- Untuk command, tampilkan hanya yang penting untuk kontrol atau verifikasi.
- Jangan klaim selesai sebelum verifikasi yang relevan dijalankan atau jelaskan kenapa tidak bisa.

## Struktur Project

- `mobile/`: Flutter app untuk Android/iOS.
- `backend/`: Node.js Express API dengan Prisma.
- `docs/`: arsitektur, acceptance criteria, audit, dan workflow.

Entry point penting:

- Mobile: `mobile/lib/main.dart`.
- App shell/theme: `mobile/lib/app/attendance_app.dart`.
- Login: `mobile/lib/features/auth/login_page.dart`.
- Dashboard: `mobile/lib/features/dashboard/dashboard_page.dart`.
- Flow absensi: `mobile/lib/features/attendance/attendance_flow_page.dart`.
- Backend: `backend/src/server.js`, `backend/src/app.js`, `backend/src/routes.js`.

## Coding Rules

- Ikuti pola file yang sudah ada sebelum membuat abstraksi baru.
- Untuk Flutter, pertahankan Material 3 dan desain mobile-first.
- Jangan hardcode credential, token, private key, atau API key.
- Jangan membocorkan stack trace atau secret lewat pesan error user.
- Untuk data dashboard, jangan tampilkan angka dummy sebagai data real.
- Untuk absensi, server tetap sumber kebenaran untuk radius, shift, duplikat, overtime, approval, dan audit log.
- Offline queue harus tetap aman dan tidak menyimpan secret mentah.

## Verification Commands

Dari root project:

```powershell
.\scripts\verify.ps1 -Mobile
.\scripts\verify.ps1 -Backend
.\scripts\verify.ps1 -Security
.\scripts\verify.ps1 -All
```

Manual jika perlu:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

```powershell
cd backend
npm run check
```

## Security Boundaries

- Aksi yang susah dibatalkan wajib dikonfirmasi user dulu.
- Jangan menghapus data, migration, atau file konfigurasi runtime tanpa alasan jelas.
- `.env` lokal tidak boleh di-print penuh.
- `.env.example` boleh diedit, tapi hanya pakai placeholder.
- Review perubahan auth, role, export report, upload foto, dan offline sync dengan lebih ketat.

## Project Memory

- 2026-05-28: Flutter SDK tersedia dan `flutter analyze` plus `flutter test` berhasil setelah typo import kamera dan dependency `workmanager` diperbaiki.
- 2026-05-28: Build APK debug pernah gagal karena `workmanager 0.5.2` tidak kompatibel dengan Flutter 3.44; project dinaikkan ke `workmanager ^0.9.0+3`.
- 2026-05-28: `android/gradle.properties` memakai `kotlin.incremental=false` untuk menghindari error cache Kotlin di Windows ketika plugin source berada di drive berbeda.
- 2026-05-28: APK debug pernah berhasil dibuat di `mobile/build/app/outputs/flutter-apk/app-debug.apk` setelah proses build yang sebelumnya timeout masih lanjut di background.
