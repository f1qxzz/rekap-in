# Release Checklist

Checklist sebelum build dan distribusi Rekap In.

## Backend

1. Jalankan Docker services:
```powershell
cd D:\absensi
docker-compose up -d postgres redis
```

2. Setup environment:
```powershell
cd D:\absensi\backend
cp .env.example .env
# Edit .env sesuai environment
```

3. Jalankan migrasi & seed:
```powershell
npx prisma migrate deploy
npm run seed  # hanya untuk environment baru/demo
```

4. Verifikasi backend:
```powershell
node scripts/check-syntax.js
node src/server.js
# Buka http://localhost:8080/health
```

## Mobile

1. Setup server URL:
   - Buka app → Profil → Pengaturan API Server
   - Masukkan URL backend (contoh: `http://192.168.1.7:8080/api`)
   - Tekan **Tes Koneksi**

2. Build APK:
```powershell
cd D:\absensi\mobile
flutter build apk
# Output: build/app/outputs/flutter-apk/app-release.apk
```

3. Untuk distribusi resmi, siapkan Android signing config di `mobile/android/key.properties`.

## Verifikasi

```powershell
# Backend
cd D:\absensi\backend; node scripts/check-syntax.js

# Mobile
cd D:\absensi\mobile; flutter analyze lib/

# Build test
cd D:\absensi\mobile; flutter build apk
```

## Akun Default

| Role | Login | Password |
|------|-------|----------|
| SUPER_ADMIN | `f1qxzz` | `f1qxzz` |
| HR | `hr` | `hr123` |
| MANAJER | `manajer` | `manajer123` |
| KARYAWAN | `karyawan` | `karyawan123` |
