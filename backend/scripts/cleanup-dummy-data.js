require("dotenv").config();
const prisma = require("../src/lib/prisma");

const BASE_EMAILS = [
  "superadmin@rekapin.local",
  "hr@rekapin.local",
  "manajer@rekapin.local",
  "karyawan@rekapin.local",
];

async function main() {
  const extraUsers = await prisma.user.findMany({
    where: {
      email: {
        endsWith: "@rekapin.local",
        notIn: BASE_EMAILS,
      },
    },
    select: { id: true, email: true },
  });
  const extraUserIds = extraUsers.map((user) => user.id);

  if (extraUserIds.length > 0) {
    const attendanceToDelete = await prisma.attendance.findMany({
      where: {
        OR: [
          { userId: { in: extraUserIds } },
          { photoHash: "dummyhash" },
          { photoUrl: "/photos/dummy.jpg" },
        ],
      },
      select: { id: true },
    });
    const attendanceIds = attendanceToDelete.map((item) => item.id);

    if (attendanceIds.length > 0) {
      await prisma.overtimeRecord.deleteMany({
        where: { attendanceId: { in: attendanceIds } },
      });
      await prisma.attendance.deleteMany({
        where: { id: { in: attendanceIds } },
      });
    }

    await prisma.leaveRequest.deleteMany({
      where: {
        OR: [
          { userId: { in: extraUserIds } },
          { reason: { contains: "dummy", mode: "insensitive" } },
          { reason: { in: [
            "Izin mendesak untuk urusan keluarga",
            "Sakit demam",
            "Cuti liburan",
            "Cuti tahunan panjang",
          ] } },
        ],
      },
    });
    await prisma.leaveBalance.deleteMany({ where: { userId: { in: extraUserIds } } });
    await prisma.notification.deleteMany({
      where: {
        OR: [
          { userId: { in: extraUserIds } },
          { title: { contains: "Dummy", mode: "insensitive" } },
          { body: { contains: "dummy", mode: "insensitive" } },
        ],
      },
    });
    await prisma.refreshToken.deleteMany({
      where: {
        OR: [{ userId: { in: extraUserIds } }, { userAgent: "seed" }],
      },
    });
    await prisma.offlineQueue.deleteMany({
      where: {
        OR: [
          { userId: { in: extraUserIds } },
          { payloadEncrypted: { in: ["fake", "fake-encrypted-payload"] } },
        ],
      },
    });
    await prisma.auditLog.deleteMany({
      where: {
        OR: [
          { adminUserId: { in: extraUserIds } },
          { targetId: { in: extraUserIds } },
          { reason: { contains: "seed", mode: "insensitive" } },
        ],
      },
    });
    await prisma.user.updateMany({
      where: { directManagerId: { in: extraUserIds } },
      data: { directManagerId: null },
    });
    await prisma.user.deleteMany({ where: { id: { in: extraUserIds } } });
  }

  await deleteUnusedDepartments(["IT", "Finance"]);
  await deleteUnusedShifts(["Shift Malam"]);
  await deleteOfficesByName(["Kantor Cabang", "Kantor desa"]);
  await dedupeShifts();
  await dedupeOffices();
  await cleanupHolidays();

  console.log(
    JSON.stringify({
      removedExtraUsers: extraUsers.map((user) => user.email),
    }),
  );
}

async function deleteUnusedDepartments(names) {
  for (const name of names) {
    const department = await prisma.department.findUnique({ where: { name } });
    if (!department) continue;
    const users = await prisma.user.count({ where: { departmentId: department.id } });
    if (users === 0) {
      await prisma.department.delete({ where: { id: department.id } });
    }
  }
}

async function deleteUnusedShifts(names) {
  for (const name of names) {
    const shifts = await prisma.shift.findMany({ where: { name } });
    for (const shift of shifts) {
      const [users, attendances] = await Promise.all([
        prisma.user.count({ where: { shiftId: shift.id } }),
        prisma.attendance.count({ where: { shiftId: shift.id } }),
      ]);
      if (users === 0 && attendances === 0) {
        await prisma.shift.delete({ where: { id: shift.id } });
      }
    }
  }
}

async function deleteOfficesByName(names) {
  const offices = await prisma.officeLocation.findMany({
    where: { name: { in: names } },
  });
  for (const office of offices) {
    await prisma.officeLocation.update({
      where: { id: office.id },
      data: { users: { set: [] } },
    });
    await prisma.officeLocation.delete({ where: { id: office.id } });
  }
}

async function dedupeShifts() {
  const shifts = await prisma.shift.findMany({ orderBy: { createdAt: "asc" } });
  const byName = groupBy(shifts, (shift) => shift.name);
  for (const items of byName.values()) {
    if (items.length <= 1) continue;
    const [keeper, ...duplicates] = items;
    const duplicateIds = duplicates.map((item) => item.id);
    await prisma.user.updateMany({
      where: { shiftId: { in: duplicateIds } },
      data: { shiftId: keeper.id },
    });
    await prisma.attendance.updateMany({
      where: { shiftId: { in: duplicateIds } },
      data: { shiftId: keeper.id },
    });
    await prisma.shift.deleteMany({ where: { id: { in: duplicateIds } } });
  }
}

async function dedupeOffices() {
  const offices = await prisma.officeLocation.findMany({
    include: { users: { select: { id: true } } },
    orderBy: { createdAt: "asc" },
  });
  const byName = groupBy(offices, (office) => office.name);
  for (const items of byName.values()) {
    if (items.length <= 1) continue;
    const [keeper, ...duplicates] = items;
    for (const duplicate of duplicates) {
      for (const user of duplicate.users) {
        await prisma.user.update({
          where: { id: user.id },
          data: { officeLocations: { connect: { id: keeper.id } } },
        }).catch(() => null);
      }
      await prisma.officeLocation.update({
        where: { id: duplicate.id },
        data: { users: { set: [] } },
      });
      await prisma.officeLocation.delete({ where: { id: duplicate.id } });
    }
  }
}

async function cleanupHolidays() {
  await prisma.holiday.deleteMany({
    where: {
      OR: [
        { name: { contains: "Dummy", mode: "insensitive" } },
        { name: "Cuti Bersama Idul Fitri" },
        { name: "Tahun Baru 2026" },
      ],
    },
  });

  const holidays = await prisma.holiday.findMany({ orderBy: { createdAt: "asc" } });
  const byDateName = groupBy(
    holidays,
    (holiday) => `${holiday.date.toISOString()}::${holiday.name}`,
  );
  for (const items of byDateName.values()) {
    if (items.length <= 1) continue;
    await prisma.holiday.deleteMany({
      where: { id: { in: items.slice(1).map((item) => item.id) } },
    });
  }
}

function groupBy(items, keyFn) {
  const result = new Map();
  for (const item of items) {
    const key = keyFn(item);
    if (!result.has(key)) result.set(key, []);
    result.get(key).push(item);
  }
  return result;
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
