<div align="center">

<img src="mobile/assets/logo/logo_icon.svg" width="100" alt="Rekap In">

# Rekap In

**Sistem Absensi Karyawan**

[![Flutter](https://img.shields.io/badge/Flutter-3.4+-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?style=flat-square&logo=node.js)](https://nodejs.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=flat-square&logo=postgresql)](https://postgresql.org)
[![License](https://img.shields.io/badge/License-Private-red?style=flat-square)](#)

GPS check-in/out • Selfie verification • Offline queue • Real-time dashboard

</div>

---

## ✨ Fitur

| Mobile | Backend |
|--------|---------|
| Absen masuk/pulang dengan GPS + selfie | Auth JWT (RS256/HS256) |
| Validasi radius lokasi kantor | Role hierarchy & access control |
| Riwayat absensi harian & bulanan | Rate limiting & security headers |
| Pengajuan izin/cuti dengan dokumen | SSE real-time updates |
| Cek saldo cuti real-time | Scheduler otomatis |
| Notifikasi push & in-app | Audit log lengkap |
| Mode offline dengan auto-sync | REST API + OpenAPI docs |
| Dark mode & Light mode | Docker ready |

---

## 🏗️ Arsitektur

```
┌─────────────┐     SSE      ┌─────────────┐     Prisma     ┌─────────────┐
│  Flutter    │ ◄──────────► │   Node.js   │ ◄────────────► │ PostgreSQL  │
│  Mobile App │              │   Backend   │                │   Database  │
└─────────────┘              └─────────────┘                └─────────────┘
                                    │
                                    ▼
                             ┌─────────────┐
                             │    Redis    │
                             │   (Cache)   │
                             └─────────────┘
```

---

## 🚀 Quick Start

### 1. Backend

```bash
# Start database
docker-compose up -d postgres redis

# Setup
cd backend
npm install
npx prisma generate
npx prisma migrate dev
npm run seed
npm run dev
```

### 2. Mobile

```bash
cd mobile
flutter pub get
flutter run
```

### 3. Build APK

```bash
flutter build apk
# → build/app/outputs/flutter-apk/app-release.apk
```

---

## 👥 Akun Default

| Role | Login | Password | Akses |
|------|-------|----------|-------|
| <img src="https://img.shields.io/badge/SUPER__ADMIN-7E22CE?style=flat-square" width="100"> | `f1qxzz` | `f1qxzz` | Full akses |
| <img src="https://img.shields.io/badge/HR-2563EB?style=flat-square" width="60"> | `hr` | `hr123` | Kelola karyawan |
| <img src="https://img.shields.io/badge/MANAJER-059669?style=flat-square" width="80"> | `manajer` | `manajer123` | Approve cuti |
| <img src="https://img.shields.io/badge/KARYAWAN-6B7280?style=flat-square" width="80"> | `karyawan` | `karyawan123` | Absen & izin |

> Login menggunakan email atau NIP

---

## 📱 Workflow

```
┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
│ LOGIN  │───▶│ ABSEN  │───▶│  IZIN  │───▶│APPROVE │
└────────┘    └────────┘    └────────┘    └────────┘
   │              │              │              │
   ▼              ▼              ▼              ▼
JWT Auth      GPS+Selfie    Pilih Jenis    Manager→HR
Role Check    Validasi       Upload Doc     Auto Saldo
              Radius         Tanggal        Update
```

| Step | Karyawan | Manager/HR |
|------|----------|------------|
| **Login** | Email/NIP + Password | Email/NIP + Password |
| **Absen** | Tap tombol → Selfie → GPS check | — |
| **Izin** | Buat pengajuan → Upload dokumen | — |
| **Approve** | — | Review → Setujui/Tolak |
| **Dashboard** | Status hari ini, riwayat | Summary, anomali, laporan |

---

## 🔐 Role Hierarchy

```
SUPER_ADMIN ──▶ HR ──▶ MANAJER ──▶ KARYAWAN
    (4)         (3)      (2)         (1)
```

- **SUPER_ADMIN**: Tidak bisa diubah oleh role lain
- **HR**: Kelola karyawan, approve cuti, review anomali
- **MANAJER**: Approve cuti team (≤3 hari)
- **KARYAWAN**: Absen, riwayat, pengajuan izin

---

## 📂 Struktur Project

```
rekap-in/
├── backend/                # Node.js API
│   ├── src/modules/        # Auth, Attendance, Leave, Admin
│   ├── src/middleware/     # Auth, Validate, Audit
│   ├── src/jobs/           # Scheduler
│   └── prisma/             # Schema & Seed
├── mobile/                 # Flutter App
│   ├── lib/features/       # Auth, Dashboard, Attendance, Leave
│   ├── lib/core/           # API, Camera, Offline, Realtime
│   └── assets/logo/        # Logo SVG
├── docs/                   # Dokumentasi
└── docker-compose.yml      # Infrastructure
```

---

## 🔌 API Endpoints

| Endpoint | Method | Role | Deskripsi |
|----------|--------|------|-----------|
| `/api/auth/login` | POST | Public | Login |
| `/api/auth/register` | POST | Public | Daftar |
| `/api/attendance/clock` | POST | All | Absen |
| `/api/attendance/today` | GET | All | Status hari ini |
| `/api/leave-requests` | POST | All | Pengajuan |
| `/api/admin/users` | GET | HR+ | Kelola user |
| `/api/admin/summary` | GET | HR+ | Dashboard |
| `/api/events` | GET | All | SSE stream |

---

## ⚙️ Environment

```env
PORT=8080
DATABASE_URL=postgresql://attendance:attendance@localhost:5432/attendance
REDIS_URL=redis://localhost:6379
JWT_PRIVATE_KEY=...
JWT_PUBLIC_KEY=...
APP_TIMEZONE=Asia/Jakarta
```

---

<div align="center">

**Rekap In** — Presensi kerja yang tertata.

</div>
