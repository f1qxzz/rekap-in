# Assets Directory

Place the following files here:

- `app_icon.png` — App icon (1024x1024 PNG, no alpha)
- `splash_logo.png` — Splash screen logo (512x512 PNG with transparency)
- `onboarding_*.png` — Onboarding illustrations (optional)

## Generating Icons

After placing `app_icon.png`, run:

```bash
flutter pub run flutter_launcher_icons
```

Add to `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/app_icon.png"
```
