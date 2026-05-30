const { PrismaClient } = require("@prisma/client");
const fs = require("node:fs/promises");
const path = require("node:path");

const prisma = new PrismaClient();

async function backfillPhotos() {
  const records = await prisma.attendance.findMany({
    where: {
      photoUrl: { startsWith: "local://" },
      photoData: null,
    },
    select: { id: true, photoUrl: true, photoHash: true },
  });

  console.log(`Found ${records.length} records with local:// photoUrl to backfill`);

  let success = 0;
  let failed = 0;

  for (const record of records) {
    const key = record.photoUrl.replace("local://", "");
    const filePath = path.resolve(__dirname, "../storage/private", key);

    try {
      const bytes = await fs.readFile(filePath);
      const base64 = bytes.toString("base64");

      await prisma.attendance.update({
        where: { id: record.id },
        data: { photoData: base64 },
      });

      success++;
      console.log(`  [OK] ${record.id} (${(bytes.length / 1024).toFixed(1)} KB)`);
    } catch (err) {
      failed++;
      console.log(`  [FAIL] ${record.id} - ${err.message}`);
    }
  }

  console.log(`\nDone: ${success} success, ${failed} failed`);
  await prisma.$disconnect();
}

backfillPhotos().catch((err) => {
  console.error(err);
  process.exit(1);
});
