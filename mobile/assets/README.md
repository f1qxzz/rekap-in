# Assets

## Logo

Logo dari Gemini AI SVG di `assets/logo/`:

| File | Kegunaan |
|------|----------|
| `logo_icon.svg` | App icon (Android/iOS) |
| `logo_full.svg` | Full logo (icon + "REKAP IN" text) |
| `logo_dark.svg` | Dark mode variant dengan glow |
| `logo_light.svg` | Monochrome untuk watermark |

### Generate App Icon dari SVG

```bash
# Install sharp
npm install sharp

# Generate icons
node generate_icons.js
```

Output:
- Android: `android/app/src/main/res/mipmap-*/ic_launcher*.png`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`

## Flutter Assets

Assets di-register di `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/
    - assets/logo/
```
