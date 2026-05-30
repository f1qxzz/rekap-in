# Agent Rules for Rekap In

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
- Selalu gunakan `surfaceFor(context)` atau `canvasFor(context)` untuk warna yang adaptif dark/light mode.
- Jangan gunakan `AppTheme.surface` langsung — gunakan versi `For(context)`.

## Role Hierarchy

```
SUPER_ADMIN (4) → HR (3) → MANAJER (2) → KARYAWAN (1)
```

- Role lebih tinggi bisa mengedit role lebih rendah.
- Tidak bisa mengubah role SUPER_ADMIN kecuali oleh SUPER_ADMIN sendiri.
- Tidak bisa membuat user dengan role lebih tinggi dari diri sendiri.

## Verification Commands

Dari root project:

```powershell
cd backend; node scripts/check-syntax.js
cd mobile; flutter analyze lib/
```

Build:

```powershell
cd backend; node src/server.js
cd mobile; flutter build apk
```

## Security Boundaries

- Aksi yang susah dibatalkan wajib dikonfirmasi user dulu.
- Jangan menghapus data, migration, atau file konfigurasi runtime tanpa alasan jelas.
- `.env` lokal tidak boleh di-print penuh.
- `.env.example` boleh diedit, tapi hanya pakai placeholder.
- Review perubahan auth, role, export report, upload foto, dan offline sync dengan lebih ketat.
- File `.env`, `cloudflared.exe`, `*.log`, `node_modules/` tidak boleh di-commit.

## Project Memory

- 2026-05-28: Project setup — Flutter + Node.js + PostgreSQL + Redis + Docker.
- 2026-05-28: APK debug berhasil dibuat.
- 2026-05-30: Major update — dark mode, real-time SSE, role hierarchy, logo Gemini AI, security fixes.
