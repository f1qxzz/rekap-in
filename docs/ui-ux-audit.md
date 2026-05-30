# UI/UX Audit Mobile Absensi

Tanggal audit: 2026-05-28

Scope: login, onboarding, dashboard, warna, layout mobile, dan flow absensi.

## Ringkasan

UI saat ini sudah fungsional dan cukup konsisten memakai Material 3. Masalah utamanya bukan "jelek", tapi masih terasa seperti scaffold MVP: brand belum jelas, dashboard belum punya hirarki operasional yang kuat, beberapa data ringkasan masih statis, dan status/error belum cukup membantu user saat proses absensi gagal.

Prioritas perbaikan:

1. Perjelas identitas app dan hierarchy login/dashboard.
2. Ganti data dummy dashboard dengan data API atau label "contoh".
3. Buat status absensi lebih actionable: jam masuk, jam pulang, lokasi, dan next action.
4. Rapikan layout mobile kecil supaya tombol dan kartu tidak terasa padat.
5. Standarkan warna/status agar hijau, kuning, merah punya arti yang sama di semua halaman.

## Temuan Login

File utama: `mobile/lib/features/auth/login_page.dart`

- P1: Login terlalu polos untuk aplikasi operasional. Judul hanya `Absensi`, tidak ada konteks perusahaan, status environment, atau value yang menenangkan user sebelum memasukkan akun.
- P1: Input belum memakai `autofillHints`, `textInputAction`, validasi kosong, dan submit dari keyboard. Ini memperlambat UX mobile harian.
- P1: Error login terlalu umum. Pesan `Login gagal. Cek email, password, dan approval akun.` bagus sebagai fallback, tapi user perlu tahu apakah akun belum approve, password salah, atau server tidak bisa dihubungi jika API menyediakan detail aman.
- P2: Password tidak punya toggle lihat/sembunyikan. Untuk mobile, ini sering dibutuhkan.
- P2: Loading indicator ada di icon tombol, tapi tidak ada pencegahan visual bahwa form sedang dikunci selain tombol disabled.

Rekomendasi desain:

- Pakai nama app final di judul, misalnya `Rekap In`, bukan `Absensi`.
- Tambah subtitle singkat: `Masuk untuk mencatat kehadiran dan rekap kerja.`
- Tambah validasi lokal sebelum hit API.
- Tambah `AutofillHints.email`, `AutofillHints.password`, `TextInputAction.next`, dan `TextInputAction.done`.
- Tambah password visibility toggle.

## Temuan Dashboard

File utama: `mobile/lib/features/dashboard/dashboard_page.dart`

- P0: `_WeeklySummary` masih hardcoded: Hadir 4, Terlambat 1, Izin 0, Cuti 8 hari. Untuk app absensi, data palsu di dashboard bisa menyesatkan user dan HR.
- P0: `_CalendarPreview` juga masih dummy 7 hari tanpa tanggal aktual, label hari, atau legenda. Ini perlu diganti data real atau disembunyikan sampai API tersedia.
- P1: Status hari ini hanya menampilkan enum seperti `BELUM ABSEN` atau `SUDAH MASUK`. User butuh informasi operasional: jam masuk, shift, keterlambatan, lokasi, dan action berikutnya.
- P1: Dua tombol utama `Absen Masuk` dan `Absen Pulang` sejajar. Di layar kecil, ini bisa terasa sempit dan kedua action punya bobot visual mirip. Action yang aktif sebaiknya dominan, action yang tidak tersedia menjadi secondary atau dijelaskan alasannya.
- P1: Refresh/sync hanya icon di AppBar. Untuk user non-teknis, status offline queue dan sinkronisasi perlu lebih eksplisit saat ada pending data.
- P2: Kartu ringkasan mingguan menggunakan empat `Expanded` dalam satu row. Pada layar kecil, label seperti `Terlambat` dan `8 hari` rawan terlihat padat. Lebih aman memakai grid 2 kolom.

Rekomendasi desain:

- Buat hero status kecil di atas: `Belum absen`, `Sudah masuk 08:03`, `Pulang belum dicatat`.
- Tombol utama mengikuti status:
  - Belum absen: satu tombol dominan `Absen Masuk`.
  - Sudah masuk: satu tombol dominan `Absen Pulang`.
  - Selesai: tombol disabled dengan ringkasan hari ini.
- Ringkasan mingguan jadi grid 2x2, bukan 4 kolom penuh.
- Calendar preview wajib punya label hari dan tanggal, atau pindahkan ke halaman detail.

## Warna dan Visual System

File utama: `mobile/lib/app/attendance_app.dart`

- P1: Theme hanya memakai `ColorScheme.fromSeed` dengan seed teal. Ini cukup untuk MVP, tapi belum ada semantic token untuk status absensi.
- P1: Status penting perlu warna tetap:
  - Sukses/hadir: hijau.
  - Terlambat/perlu perhatian: amber.
  - Gagal/anomali: merah.
  - Offline/sync: biru atau abu-abu netral.
- P2: Cards masih default Material. Untuk aplikasi operasional, gunakan radius 8, border tipis, dan surface yang lebih tenang agar dashboard tidak terasa seperti kumpulan kartu demo.

Rekomendasi desain:

- Buat helper warna status agar dashboard, kalender, anomali, dan info banner konsisten.
- Hindari palette satu warna penuh. Teal boleh jadi primary, tapi status harus memakai warna semantik.
- Tetapkan ukuran icon, radius, spacing, dan typography di satu tempat.

## Layout Mobile

- P1: Layout sudah memakai `ListView` dan `SafeArea`, ini benar untuk mobile.
- P1: Beberapa area masih terlalu padat untuk layar kecil: action buttons dashboard, weekly summary 4 kolom, dan dialog preview foto.
- P2: Login memakai `Center` dengan `Column(mainAxisAlignment: center)`. Saat keyboard muncul, form bisa terasa naik/turun mendadak. Lebih stabil memakai `ListView` dengan `keyboardDismissBehavior`.
- P2: Onboarding cukup jelas, tapi belum ada skip atau indikator izin yang benar-benar diminta nanti. Jangan membuat user mengira permission sudah diberikan hanya karena membaca onboarding.

## Flow Absensi

File utama: `mobile/lib/features/attendance/attendance_flow_page.dart`

- P1: Status proses memakai string `_status` yang berubah. Ini fungsional, tapi belum membedakan loading, success, warning, dan error secara visual.
- P1: Error menampilkan `error.toString()`. Untuk user, pesan seperti `StateError:` sebaiknya dibersihkan.
- P1: Permission kamera dan notifikasi diminta bersamaan. Untuk UX, lebih natural minta permission tepat saat dibutuhkan dan jelaskan kenapa.
- P2: Checklist awal bagus, tapi bisa dibuat sebagai progress stepper agar user tahu posisi proses: izin, GPS, kamera, wajah, simpan.

## Rekomendasi Urutan Implementasi

1. Ganti nama app visible ke nama final.
2. Perbaiki login form: autofill, validasi, password toggle, error aman.
3. Hilangkan data dummy dashboard atau beri label jelas.
4. Ubah dashboard action menjadi single primary action sesuai status.
5. Tambah semantic status colors dan shared UI tokens.
6. Ubah weekly summary ke responsive grid.
7. Bersihkan error/status flow absensi agar natural untuk user.
