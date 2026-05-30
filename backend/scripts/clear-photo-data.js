const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function clearPhotoData() {
  const result = await prisma.attendance.updateMany({
    where: { photoData: { not: null } },
    data: { photoData: null },
  });
  console.log(`Cleared photoData from ${result.count} records`);
  await prisma.$disconnect();
}

clearPhotoData().catch((err) => {
  console.error(err);
  process.exit(1);
});
