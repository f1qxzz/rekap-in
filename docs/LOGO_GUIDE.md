# Membuat Logo Rekap In dengan Gemini AI

## Prompt untuk Gemini

Buka [Gemini](https://gemini.google.com) lalu paste prompt ini:

```
Create a modern, elegant app logo for "Rekap In" - an employee attendance/presence tracking app.

Design requirements:
- Icon: A minimalist clock face with a bold checkmark overlay, symbolizing timely attendance
- Background: Rounded square with gradient from deep purple (#7E22CE) to orchid (#A855F7)
- Style: Clean, flat design with subtle drop shadow, no 3D effects
- Colors: Purple gradient background, white clock and checkmark
- Feel: Professional, trustworthy, modern SaaS aesthetic

Generate these variants:
1. Full logo (icon + "REKAP IN" text below)
2. Icon only (for app icon/favicon)
3. Dark background version (for splash screen)
4. Light/outline version (for watermark)

Output format: SVG, transparent background, 512x512px
```

## Hasil yang Didapat

Setelah Gemini generate, download file SVG lalu simpan:

| File | Lokasi | Kegunaan |
|------|--------|----------|
| `logo_full.svg` | `assets/logo/` | Login page, onboarding, about dialog |
| `logo_icon.svg` | `assets/logo/` | App icon, splash screen, notification |
| `logo_dark.svg` | `assets/logo/` | Dark mode header |
| `logo_light.svg` | `assets/logo/` | Watermark pada foto absensi |

## Konversi ke Format Lain

### PNG untuk App Icon (Android)
```bash
# Install svg2png converter
npm install -g svg2png-cli

# Konversi ke berbagai ukuran
svg2png logo_icon.svg -o icon-48.png -w 48 -h 48
svg2png logo_icon.svg -o icon-72.png -w 72 -h 72
svg2png logo_icon.svg -o icon-96.png -w 96 -h 96
svg2png logo_icon.svg -o icon-144.png -w 144 -h 144
svg2png logo_icon.svg -o icon-192.png -w 192 -h 192
svg2png logo_icon.svg -o icon-512.png -w 512 -h 512
```

### Flutter Asset
Simpan SVG di `assets/logo/` lalu tambah di `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/logo/logo_full.svg
    - assets/logo/logo_icon.svg
```

### Android Adaptive Icon
1. Konversi `logo_icon.svg` ke PNG 512x512
2. Copy ke `android/app/src/main/res/` di folder mipmap:
   - `mipmap-mdpi/` → 48x48
   - `mipmap-hdpi/` → 72x72
   - `mipmap-xhdpi/` → 96x96
   - `mipmap-xxhdpi/` → 144x144
   - `mipmap-xxxhdpi/` → 192x192

### iOS App Icon
1. Konversi `logo_icon.svg` ke PNG 1024x1024
2. Buka `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
3. Replace `Icon-App-1024x1024@1x.png`

## Tips Prompt Gemini

Jika hasil belum sesuai, tambahkan variasi prompt:

**Lebih minimalis:**
```
Make it more minimalistic. Remove unnecessary details. 
Flat design only, no gradients on the icon itself.
```

**Lebih playful:**
```
Add a subtle friendly touch. Slightly rounded edges on the checkmark.
Keep it professional but approachable.
```

**Ganti warna:**
```
Change gradient to blue (#2563EB to #3B82F6) for a more corporate feel.
```

**Ganti ikon:**
```
Replace clock with a clipboard icon. Keep the checkmark.
```

## Referensi Desain

- [Material Design 3 - App Icons](https://m3.material.io/styles/icons/overview)
- [Apple HIG - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Flaticon](https://flaticon.com) - Referensi ikon serupa
