# Acceptance Criteria Mapping

| Kriteria | Implementasi di repo |
|---|---|
| Absen masuk/pulang dengan foto + GPS | `mobile/lib/features/attendance/attendance_flow_page.dart`, `backend/src/modules/attendance/*` |
| Fake GPS diblokir | Mobile cek `Position.isMocked`, server blokir `isMockLocationDetected` |
| Offline tersimpan dan sync | `OfflineQueue` SQLite AES, endpoint `/api/attendance/offline-sync` |
| Izin approval manajer -> HR | `backend/src/modules/leave/*` |
| Admin set lokasi dan radius | `/api/admin/offices` |
| Laporan PDF/Excel/CSV | `/api/reports/export?format=pdf|xlsx|csv` |
| Audit log append-only | Model `audit_logs`, hanya endpoint read/create internal |
| Android 8+ dan iOS 14+ | Dependency Flutter mendukung target tersebut; native runner digenerate saat Flutter SDK tersedia |
| Dashboard <2 detik | Endpoint dashboard dipisah ringan: `/auth/me`, `/attendance/today`, offline count lokal |

## Hal yang harus diisi sebelum production

- Generate RS256 keypair dan isi `JWT_PRIVATE_KEY`/`JWT_PUBLIC_KEY`.
- Pasang provider email dan FCM.
- Ganti adapter foto lokal ke S3/GCS/Cloudinary private bucket.
- Pasang model face embedding on-device jika similarity 85% wajib secara biometrik.
- Jalankan penetration test, DPIA/UU PDP review, dan hardening TLS di reverse proxy.

