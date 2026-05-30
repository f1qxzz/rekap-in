# Coding Workflow Absensi

Tujuan: membuat kerja coding lebih rapi dengan planning, security check, verification, dan memory/rules yang konsisten untuk Flutter mobile dan Node.js backend.

## Prinsip Kerja

1. Mulai dari runtime nyata, bukan asumsi.
2. Baca file entrypoint sebelum patch.
3. Simpan credential di `.env`, jangan hardcode.
4. Patch kecil dan terarah.
5. Verifikasi dengan command yang sesuai area perubahan.
6. Catat keputusan penting agar tidak diulang dari nol.

## Planning

Sebelum coding:

- Tulis tujuan dalam 1 kalimat.
- Tentukan area: `mobile`, `backend`, `docs`, atau infra.
- Cari entrypoint:
  - Mobile: `mobile/lib/main.dart`, `mobile/lib/app/attendance_app.dart`.
  - Login: `mobile/lib/features/auth/login_page.dart`.
  - Dashboard: `mobile/lib/features/dashboard/dashboard_page.dart`.
  - Absensi: `mobile/lib/features/attendance/attendance_flow_page.dart`.
  - Backend: `backend/src/server.js`, `backend/src/app.js`, `backend/src/routes.js`.
- Tentukan verifikasi minimal sebelum edit.

Template singkat:

```text
Tujuan:
Area:
File utama:
Risiko:
Verifikasi:
```

## Security Check

Wajib dicek sebelum commit/release:

- Tidak ada token, private key, password, atau URL private hardcoded.
- `.env` tidak masuk repo.
- `.env.example` hanya berisi placeholder aman.
- API auth, refresh token, dan role guard tidak dilewati.
- Upload foto tetap private, bukan public bucket.
- Error ke user tidak membocorkan stack trace.
- Export laporan tidak membuka data lintas role.
- Offline queue tetap terenkripsi dan tidak menyimpan secret mentah.

Command cepat:

```powershell
rg -n "api[_-]?key|secret|password|private[_-]?key|token|Bearer|BEGIN .* KEY" -g "!**/node_modules/**" -g "!**/build/**" -g "!**/.dart_tool/**" .
```

## Verification

Gunakan `scripts/verify.ps1` dari root project.

Mobile cepat:

```powershell
.\scripts\verify.ps1 -Mobile
```

Mobile plus APK debug:

```powershell
.\scripts\verify.ps1 -Mobile -BuildApk
```

Backend:

```powershell
.\scripts\verify.ps1 -Backend
```

Security grep:

```powershell
.\scripts\verify.ps1 -Security
```

Semua check utama:

```powershell
.\scripts\verify.ps1 -All
```

## Memory dan Rules

Gunakan `AGENTS.md` sebagai rule utama agent di repo ini.

Catat keputusan yang berpengaruh panjang di bagian "Project Memory" dalam `AGENTS.md`, misalnya:

- Nama produk final.
- Warna dan token UI final.
- Batasan backend/mobile yang tidak boleh diubah sembarang.
- Command validasi yang terbukti jalan.
- Bug runtime yang pernah terjadi dan penyebabnya.

Jangan catat credential, token, private key, atau data user nyata.

## Quality Gate

Sebelum menyatakan selesai:

- Untuk perubahan Dart/UI: `flutter analyze` dan `flutter test`.
- Untuk perubahan Android native/dependency: `flutter build apk --debug`.
- Untuk backend: `npm run check`.
- Untuk security-sensitive code: jalankan security grep dan review hasilnya.
- Untuk docs/rules saja: cek file bisa dibaca dan link/command masuk akal.

## PR/Change Summary

Gunakan format ringkas:

```text
Perubahan:
- ...

Verifikasi:
- ...

Risiko tersisa:
- ...
```
