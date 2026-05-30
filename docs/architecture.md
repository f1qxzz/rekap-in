# Arsitektur Absensi

## Prinsip

- Server adalah sumber kebenaran untuk validasi radius, status kehadiran, overtime, approval, payroll, dan audit log.
- Mobile melakukan validasi awal untuk UX cepat: permission, GPS presisi, mock-location flag Android, face presence, resize/compress/hash foto, dan offline queue terenkripsi.
- Foto disimpan di private bucket. Database hanya menyimpan URL object, SHA-256 hash, dan metadata verifikasi.
- Audit log bersifat append-only. Tidak ada endpoint update/delete audit log.

## Flow Absensi

1. Mobile cek token dan refresh jika perlu.
2. Mobile cek koneksi ke `/health`.
3. Mobile minta permission kamera, lokasi presisi, dan notifikasi.
4. Mobile ambil GPS hardware, blokir mock location, wajib akurasi <= 50m.
5. Mobile tampilkan peta pin karyawan dan radius kantor.
6. Mobile ambil selfie dengan watermark nama, NIP, waktu, koordinat, dan UUID sesi.
7. Mobile resize/compress foto, hitung SHA-256, deteksi wajah.
8. Jika online, kirim attendance ke API. Jika offline, simpan payload terenkripsi di SQLite dan sinkronkan berurutan.
9. Server validasi radius, mock flag, akurasi, shift, duplikat, anomaly, overtime, lalu tulis audit/notification.

## Batasan MVP

- Google ML Kit FaceDetector hanya mendeteksi wajah, bukan menghasilkan embedding similarity. Untuk similarity 85% yang benar-benar kuat, mobile perlu model on-device tambahan seperti FaceNet/TFLite. Kode mobile sudah memisahkan adapter supaya bisa diganti tanpa mengubah flow absensi.
- Pengiriman email/FCM/payroll webhook disiapkan sebagai service boundary. Provider credential tidak di-hardcode.

