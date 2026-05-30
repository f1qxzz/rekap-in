# Rekap In — Mobile App

Aplikasi Flutter untuk absensi karyawan dengan GPS, selfie, offline queue, dan real-time dashboard.

## Setup

```bash
cd mobile
flutter pub get
flutter run
```

## Konfigurasi Server

Buka app → Profil → Pengaturan API Server → Masukkan URL backend.

Default: `http://localhost:8080/api` (untuk emulator Android pakai `http://10.0.2.2:8080/api`).

## Build APK

```bash
flutter build apk
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## Struktur

```
lib/
├── app/             # AttendanceApp, AppTheme (light + dark)
├── core/
│   ├── api/         # Dio client, interceptors, retry
│   ├── auth/        # Biometric service
│   ├── camera/      # Selfie capture, face match
│   ├── notifications/ # Push notification service
│   ├── offline/     # Offline queue, background sync
│   ├── realtime/    # SSE service
│   ├── storage/     # Token store (FlutterSecureStorage)
│   ├── utils/       # Formatters, helpers
│   └── widgets/     # Reusable UI components
└── features/
    ├── auth/        # Login, register, onboarding
    ├── dashboard/   # Main dashboard with all role views
    ├── attendance/  # Clock in/out flow, history
    ├── leave/       # Leave requests, balance
    ├── admin/       # Admin panel (user, shift, office, etc.)
    ├── profile/     # User profile, settings
    ├── settings/    # API settings, offline sync
    ├── reports/     # Manager reports
    └── notifications/ # Notification list
```

## Logo

Logo Gemini AI tersedia di `assets/logo/`:
- `logo_icon.svg` — App icon
- `logo_full.svg` — Full logo (icon + text)
- `logo_dark.svg` — Dark mode variant
- `logo_light.svg` — Monochrome variant

App icon Android/iOS sudah di-generate dari SVG menggunakan `sharp`.

## Fitur

- Absen masuk/pulang dengan GPS + selfie
- Offline queue (maks 5 entri, auto-sync)
- Dark mode & Light mode
- SSE real-time updates
- Push notification support
- Biometric login
- Role-based dashboard
