<p align="center">
  <img src="mobile/assets/logo/logo_full.svg" width="400" alt="Rekap In Logo">
</p>

<h3 align="center">Sistem Absensi Karyawan</h3>

<p align="center">
  Aplikasi mobile Flutter dengan backend Node.js untuk manajemen kehadiran karyawan.<br>
  GPS check-in/out • selfie verification • offline queue • real-time dashboard
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.4+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Node.js-18+-339933?style=for-the-badge&logo=node.js&logoColor=white" alt="Node.js">
  <img src="https://img.shields.io/badge/PostgreSQL-16-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL">
  <img src="https://img.shields.io/badge/Prisma-5-2D3748?style=for-the-badge&logo=prisma&logoColor=white" alt="Prisma">
</p>

---

## Fitur

<table>
<tr>
<td width="50%">

### Mobile App
- Absen masuk/pulang dengan GPS + selfie
- Validasi radius lokasi kantor
- Riwayat absensi harian & bulanan
- Pengajuan izin/cuti dengan dokumen
- Cek saldo cuti real-time
- Notifikasi push & in-app
- Mode offline dengan auto-sync
- Dark mode & Light mode

</td>
<td width="50%">

### Backend API
- Auth JWT (RS256/HS256) + refresh token
- Role hierarchy & akses control
- Rate limiting & security headers
- SSE real-time updates
- Scheduler otomatis (reminder, eskalasi)
- Audit log lengkap
- REST API dengan OpenAPI docs

</td>
</tr>
</table>

---

## Role Hierarchy

```
SUPER_ADMIN (4) ──► HR (3) ──► MANAJER (2) ──► KARYAWAN (1)
```

| Role | Akses |
|------|-------|
| **SUPER_ADMIN** | Full akses, kelola semua user & role |
| **HR** | Kelola karyawan, approve cuti, review anomali |
| **MANAJER** | Approve cuti team, lihat laporan |
| **KARYAWAN** | Absen, riwayat, pengajuan izin |

---

## Quick Start

### Backend

```powershell
# 1. Start database
cd D:\absensi
docker-compose up -d postgres redis

# 2. Setup & jalankan
cd backend
npm install
npx prisma generate
npx prisma migrate dev
npm run seed
npm run dev
```

### Mobile

```powershell
cd D:\absensi\mobile
flutter pub get
flutter run
```

### Build APK

```powershell
flutter build apk
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Akun Default

| Role | Login | Password |
|------|-------|----------|
| SUPER_ADMIN | `f1qxzz` | `f1qxzz` |
| HR | `hr` | `hr123` |
| MANAJER | `manajer` | `manajer123` |
| KARYAWAN | `karyawan` | `karyawan123` |

> Login menggunakan email atau NIP

---

## Workflow

<table>
<tr>
<td width="30%" align="center">
  <img src="https://img.shields.io/badge/1-LOGIN-7E22CE?style=for-the-badge" alt="Login">
</td>
<td width="70%">

**Login** → Masukkan email/NIP & password → Verifikasi JWT → Akses dashboard sesuai role

</td>
</tr>
<tr>
<td align="center">
  <img src="https://img.shields.io/badge/2-ABSEN-7E22CE?style=for-the-badge" alt="Absen">
</td>
<td>

**Absen Masuk/Pulang** → Tap tombol → Ambil selfie → GPS check → Validasi radius → Kirim ke server

</td>
</tr>
<tr>
<td align="center">
  <img src="https://img.shields.io/badge/3-IZIN-7E22CE?style=for-the-badge" alt="Izin">
</td>
<td>

**Pengajuan Izin** → Pilih jenis → Atur tanggal → Isi alasan → Submit → Menunggu approval

</td>
</tr>
<tr>
<td align="center">
  <img src="https://img.shields.io/badge/4-APPROVAL-7E22CE?style=for-the-badge" alt="Approval">
</td>
<td>

**Approval** → Manager approve (≤3 hari) → HR approve (>3 hari) → Saldo cuti otomatis berkurang

</td>
</tr>
</table>

---

## Struktur Project

```
absensi/
├── backend/
│   ├── src/
│   │   ├── modules/        # auth, attendance, leave, admin, payroll, reports, notifications
│   │   ├── middleware/      # auth, validate, audit, errorHandler
│   │   ├── jobs/            # scheduler
│   │   └── lib/             # prisma, redis, sse
│   ├── prisma/
│   │   ├── schema.prisma
│   │   └── seed.js
│   └── tests/
├── mobile/
│   ├── lib/
│   │   ├── app/             # AttendanceApp, AppTheme
│   │   ├── core/            # api, camera, offline, realtime, storage
│   │   └── features/        # auth, dashboard, attendance, leave, admin, profile
│   └── assets/logo/         # Logo SVG
├── docs/
├── scripts/
└── docker-compose.yml
```

---

## API Endpoints

| Endpoint | Method | Role | Deskripsi |
|----------|--------|------|-----------|
| `/api/auth/login` | POST | Public | Login |
| `/api/auth/register` | POST | Public | Daftar akun |
| `/api/attendance/clock` | POST | All | Absen masuk/pulang |
| `/api/attendance/today` | GET | All | Status hari ini |
| `/api/leave-requests` | POST | All | Buat pengajuan |
| `/api/admin/users` | GET | HR+ | Daftar karyawan |
| `/api/admin/summary` | GET | HR+ | Dashboard summary |
| `/api/events` | GET | All | SSE real-time stream |

> Docs: `http://localhost:8080/api/docs` (development only)

---

## Environment Variables

```env
PORT=8080
DATABASE_URL=postgresql://attendance:attendance@localhost:5432/attendance
REDIS_URL=redis://localhost:6379
JWT_PRIVATE_KEY=...
JWT_PUBLIC_KEY=...
APP_TIMEZONE=Asia/Jakarta
```

---

<p align="center">
  Built with ❤️ by Rekap In Team
</p>
