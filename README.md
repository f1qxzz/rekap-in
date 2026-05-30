<div align="center">

<img src="mobile/assets/logo/logo_icon.svg" width="120" alt="Rekap In Logo">

# Rekap In

### Sistem Absensi Karyawan

[![Flutter](https://img.shields.io/badge/Flutter-3.4+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgresql.org)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?style=for-the-badge&logo=redis&logoColor=white)](https://redis.io)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![Prisma](https://img.shields.io/badge/Prisma-5-2D3748?style=for-the-badge&logo=prisma&logoColor=white)](https://prisma.io)
[![License](https://img.shields.io/badge/License-Private-red?style=for-the-badge)](#)

<br>

**GPS check-in/out** · **Selfie verification** · **Offline queue** · **Real-time dashboard**

<br>

</div>

---

## Fitur

<table>
<tr>
<td width="50%">

#### Mobile App

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

#### Backend API

- Auth JWT (RS256/HS256)
- Role hierarchy & access control
- Rate limiting & security headers
- SSE real-time updates
- Scheduler otomatis
- Audit log lengkap
- REST API + OpenAPI docs
- Docker ready

</td>
</tr>
</table>

---

## Arsitektur

```
Flutter App  ──SSE──  Node.js API  ──Prisma──  PostgreSQL
                         │
                         │
                    ┌────┴────┐
                    │         │
                  Redis     MinIO
                 (Cache)   (Storage)
```

---

## Quick Start

### 1. Infrastructure

```bash
docker-compose up -d
```

> Menjalankan PostgreSQL, Redis, dan MinIO.

### 2. Backend

```bash
cd backend
npm install
npx prisma generate
npx prisma migrate dev
npm run seed
npm run dev
```

### 3. Mobile

```bash
cd mobile
flutter pub get
flutter run
```

### Build APK

```bash
cd mobile
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Akun Default

| Role | Login | Password | Akses |
|------|-------|----------|-------|
| `SUPER_ADMIN` | `f1qxzz` | `f1qxzz` | Full akses |
| `HR` | `hr` | `hr123` | Kelola karyawan |
| `MANAJER` | `manajer` | `manajer123` | Approve cuti |
| `KARYAWAN` | `karyawan` | `karyawan123` | Absen & izin |

> Login menggunakan email atau NIP.

---

## Role Hierarchy

```
SUPER_ADMIN (4)  -->  HR (3)  -->  MANAJER (2)  -->  KARYAWAN (1)
```

| Role | Deskripsi |
|------|-----------|
| `SUPER_ADMIN` | Tidak bisa diubah oleh role lain |
| `HR` | Kelola karyawan, approve cuti, review anomali |
| `MANAJER` | Approve cuti team (≤3 hari) |
| `KARYAWAN` | Absen, riwayat, pengajuan izin |

---

## Workflow

```
LOGIN  ──►  ABSEN  ──►  IZIN  ──►  APPROVE
  │            │           │           │
  ▼            ▼           ▼           ▼
JWT Auth   GPS+Selfie  Pilih Jenis  Manager→HR
Role Check Validasi     Upload Doc   Auto Saldo
             Radius      Tanggal     Update
```

| Step | Karyawan | Manager/HR |
|------|----------|------------|
| **Login** | Email/NIP + Password | Email/NIP + Password |
| **Absen** | Tap tombol → Selfie → GPS check | — |
| **Izin** | Buat pengajuan → Upload dokumen | — |
| **Approve** | — | Review → Setujui/Tolak |
| **Dashboard** | Status hari ini, riwayat | Summary, anomali, laporan |

---

## API Endpoints

| Endpoint | Method | Role | Deskripsi |
|----------|--------|------|-----------|
| `/api/auth/login` | `POST` | Public | Login |
| `/api/auth/register` | `POST` | Public | Daftar |
| `/api/attendance/clock` | `POST` | All | Absen |
| `/api/attendance/today` | `GET` | All | Status hari ini |
| `/api/leave-requests` | `POST` | All | Pengajuan izin/cuti |
| `/api/admin/users` | `GET` | HR+ | Kelola user |
| `/api/admin/summary` | `GET` | HR+ | Dashboard summary |
| `/api/events` | `GET` | All | SSE stream |

---

## Tech Stack

<details>
<summary><strong>Backend</strong></summary>

- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **ORM**: Prisma 5
- **Database**: PostgreSQL 16
- **Cache**: Redis 7
- **Auth**: JWT (RS256/HS256) + Argon2
- **Validation**: Zod
- **Storage**: MinIO / Local
- **Docs**: Swagger UI

</details>

<details>
<summary><strong>Mobile</strong></summary>

- **Framework**: Flutter 3.4+
- **State**: Provider
- **HTTP**: Dio
- **Local DB**: SQLite (sqflite)
- **Camera**: camera + Google ML Kit
- **Location**: geolocator + google_maps_flutter
- **Secure Storage**: flutter_secure_storage
- **Push**: Firebase Messaging
- **Biometric**: local_auth

</details>

<details>
<summary><strong>Infrastructure</strong></summary>

- **Container**: Docker + Docker Compose
- **Database**: PostgreSQL 16 Alpine
- **Cache**: Redis 7 Alpine
- **Object Storage**: MinIO
- **Tunnel**: Cloudflare Tunnel (optional)

</details>

---

## Struktur Project

```
absensi/
├── backend/                    # Node.js API
│   ├── src/
│   │   ├── modules/            # Auth, Attendance, Leave, Admin
│   │   ├── middleware/         # Auth, Validate, Audit
│   │   ├── jobs/               # Scheduler
│   │   ├── lib/                # Shared utilities
│   │   └── config/             # App configuration
│   ├── prisma/                 # Schema & Seed
│   ├── scripts/                # Build & check scripts
│   ├── tests/                  # Test files
│   └── storage/                # Local file storage
├── mobile/                     # Flutter App
│   ├── lib/
│   │   ├── features/           # Auth, Dashboard, Attendance, Leave
│   │   ├── core/               # API, Camera, Offline, Realtime
│   │   └── app/                # App shell & theme
│   └── assets/logo/            # Logo SVG
├── docs/                       # Dokumentasi
├── scripts/                    # Root build scripts
└── docker-compose.yml          # Infrastructure
```

---

## Environment

```env
PORT=8080
DATABASE_URL=postgresql://attendance:attendance@localhost:5432/attendance
REDIS_URL=redis://localhost:6379
JWT_PRIVATE_KEY=CHANGE_ME
JWT_PUBLIC_KEY=CHANGE_ME
APP_TIMEZONE=Asia/Jakarta
STORAGE_PROVIDER=local
```

> Lihat `.env.example` untuk konfigurasi lengkap.

---

## License

Private — All rights reserved.

---

<div align="center">

**Rekap In** — Presensi kerja yang tertata.

</div>
