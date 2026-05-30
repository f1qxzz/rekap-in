# Arsitektur Rekap In

## Prinsip

- Server adalah sumber kebenaran untuk validasi radius, status kehadiran, overtime, approval, payroll, dan audit log.
- Mobile melakukan validasi awal untuk UX cepat: permission, GPS presisi, mock-location flag Android, face presence, resize/compress/hash foto, dan offline queue terenkripsi.
- Foto disimpan di local storage atau S3. Database hanya menyimpan URL object, SHA-256 hash, dan metadata verifikasi.
- Audit log bersifat append-only. Tidak ada endpoint update/delete audit log.
- Real-time updates menggunakan SSE (Server-Sent Events) dari server ke mobile.

## Role Hierarchy

```
SUPER_ADMIN (4) → HR (3) → MANAJER (2) → KARYAWAN (1)
```

- Role lebih tinggi bisa mengedit role lebih rendah.
- SUPER_ADMIN tidak bisa diubah oleh role lain.
- Approval izin: Manager (≤3 hari) → HR (>3 hari).

## Flow Absensi

1. Mobile cek token dan refresh jika perlu.
2. Mobile minta permission kamera, lokasi presisi, dan notifikasi.
3. Mobile ambil GPS hardware, blokir mock location, wajib akurasi <= 50m.
4. Mobile ambil selfie dengan watermark nama, NIP, waktu, koordinat, dan UUID sesi.
5. Mobile resize/compress foto di Isolate terpisah (tidak block UI thread).
6. Jika online, kirim attendance ke API. Jika offline, simpan payload terenkripsi di SQLite dan sinkronkan berurutan.
7. Server validasi radius, mock flag, akurasi, shift, duplikat, anomaly, overtime, lalu tulis audit/notification.
8. Server broadcast SSE event ke semua client yang terhubung.

## Real-time Architecture

```
Mobile App ←── SSE ←── Backend ←── PostgreSQL
                ↓
         BroadcastSSE()
```

- SSE endpoint: `GET /api/events?role=KARYAWAN&userId=xxx`
- Events: `attendance:created`, `attendance:anomaly`, `leave:created`, `leave:updated`, `notification:new`
- Dashboard auto-refresh dengan debounce 2 detik

## Security

- JWT RS256 (production) / HS256 (development dengan ephemeral key)
- Rate limiting: global 100 req/min, auth endpoints 10 req/min
- CORS configurable via `CORS_ORIGINS` env variable
- Password hashing dengan Argon2
- Token cleanup otomatis (expired refresh tokens & password reset tokens)

## Batasan

- Google ML Kit FaceDetector hanya mendeteksi wajah, bukan menghasilkan embedding similarity. Untuk similarity 85% yang benar-benar kuat, mobile perlu model on-device tambahan seperti FaceNet/TFLite.
- Pengiriman email/FCM/payroll webhook disiapkan sebagai service boundary. Provider credential tidak di-hardcode.
