# Absensi Mobile

Source Flutter untuk Android dan iOS. Mesin saat ini belum punya `flutter` di PATH, jadi native runner Android/iOS belum bisa digenerate lokal.

Setelah Flutter SDK tersedia:

```bash
cd mobile
flutter create --platforms android,ios .
flutter pub get
flutter analyze
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

Untuk iOS device/simulator, ganti `API_BASE_URL` ke host yang bisa dijangkau perangkat.

