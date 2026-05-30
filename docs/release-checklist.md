# Release Checklist

Checklist singkat sebelum build dan distribusi Rekap In.

## Backend

- Jalankan `docker compose up -d postgres redis minio`.
- Isi `backend/.env` dari `backend/.env.example` tanpa membagikan secret.
- Jalankan migrasi database dari folder `backend`: `npx prisma migrate deploy`.
- Jalankan seed hanya untuk environment awal atau demo: `npm run seed`.
- Pastikan API hidup: `npm run dev`, lalu buka `http://localhost:8080/health`.

## Mobile

- Gunakan URL API yang bisa dijangkau perangkat, bukan `localhost` jika memakai HP fisik.
- Build debug untuk tes cepat:

```powershell
cd D:\absensi\mobile
C:\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=http://IP-LAPTOP:8080/api
```

- Build release:

```powershell
cd D:\absensi
.\scripts\build-mobile-release.ps1 -ApiBaseUrl http://IP-LAPTOP:8080/api
```

- Untuk distribusi resmi, siapkan Android signing config di `mobile/android/key.properties` dan Gradle signing tanpa menaruh password di source control.

## Verifikasi

```powershell
cd D:\absensi
.\scripts\verify.ps1 -Backend
.\scripts\verify.ps1 -Mobile
.\scripts\verify.ps1 -Security
```

Setelah APK terpasang, buka Pengaturan Server di aplikasi, isi URL API, lalu tekan Tes Koneksi.
