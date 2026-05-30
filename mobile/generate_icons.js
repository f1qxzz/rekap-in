const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const svgPath = path.join(__dirname, 'assets', 'logo', 'logo_icon.svg');
const svgBuffer = fs.readFileSync(svgPath);

const androidSizes = [
  { size: 48, dir: 'mipmap-mdpi' },
  { size: 72, dir: 'mipmap-hdpi' },
  { size: 96, dir: 'mipmap-xhdpi' },
  { size: 144, dir: 'mipmap-xxhdpi' },
  { size: 192, dir: 'mipmap-xxxhdpi' },
];

const androidBase = path.join(__dirname, 'android', 'app', 'src', 'main', 'res');

async function generate() {
  for (const { size, dir } of androidSizes) {
    const outDir = path.join(androidBase, dir);
    fs.mkdirSync(outDir, { recursive: true });
    const outFile = path.join(outDir, 'ic_launcher.png');
    await sharp(svgBuffer).resize(size, size).png().toFile(outFile);
    console.log(`✓ Android ${dir}/ic_launcher.png (${size}x${size})`);
  }

  const iosDir = path.join(__dirname, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset');
  fs.mkdirSync(iosDir, { recursive: true });
  const iosOut = path.join(iosDir, 'Icon-App-1024x1024@1x.png');
  await sharp(svgBuffer).resize(1024, 1024).png().toFile(iosOut);
  console.log(`✓ iOS Icon-App-1024x1024@1x.png (1024x1024)`);

  const adaptiveDir = path.join(androidBase, 'mipmap-anydpi-v26');
  fs.mkdirSync(adaptiveDir, { recursive: true });

  console.log('\nDone! All app icons generated.');
}

generate().catch(console.error);
