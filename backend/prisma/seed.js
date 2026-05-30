const argon2 = require("argon2");
require("dotenv").config();
const prisma = require("../src/lib/prisma");

async function findOrCreateShift(data) {
  const existing = await prisma.shift.findFirst({ where: { name: data.name } });
  if (existing) return prisma.shift.update({ where: { id: existing.id }, data });
  return prisma.shift.create({ data });
}

async function findOrCreateOffice(data) {
  const existing = await prisma.officeLocation.findFirst({ where: { name: data.name } });
  if (existing) return prisma.officeLocation.update({ where: { id: existing.id }, data });
  return prisma.officeLocation.create({ data });
}

async function findOrCreateHoliday(data) {
  const existing = await prisma.holiday.findUnique({ where: { date_name: { date: data.date, name: data.name } } });
  if (existing) return prisma.holiday.update({ where: { id: existing.id }, data });
  return prisma.holiday.create({ data });
}

async function upsertUser(user, shiftId, officeIds) {
  const passwordHash = await argon2.hash(user.password);
  const existing = await prisma.user.findFirst({ where: { OR: [{ email: user.email }, { nip: user.nip }] } });
  const data = {
    name: user.name, email: user.email, nip: user.nip, passwordHash,
    role: user.role, departmentId: user.departmentId, shiftId,
    isActive: true, isApproved: true, emailVerified: true,
  };
  if (existing) {
    return prisma.user.update({
      where: { id: existing.id },
      data: { ...data, officeLocations: officeIds?.length ? { set: officeIds.map((id) => ({ id })) } : undefined },
    });
  }
  return prisma.user.create({
    data: { ...data, officeLocations: officeIds?.length ? { connect: officeIds.map((id) => ({ id })) } : undefined },
  });
}

async function upsertLeaveBalance(userId, used = 0) {
  const year = new Date().getFullYear();
  const quota = 12;
  const existing = await prisma.leaveBalance.findFirst({ where: { userId, year } });
  if (existing) {
    return prisma.leaveBalance.update({ where: { id: existing.id }, data: { annualQuota: quota, used, remaining: quota - used } });
  }
  return prisma.leaveBalance.create({ data: { userId, year, annualQuota: quota, used, remaining: quota - used } });
}

function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(0, 0, 0, 0);
  return d;
}

function todayAt(h, m) {
  const d = new Date();
  d.setHours(h, m, 0, 0);
  return d;
}

async function main() {
  const hrDept = await prisma.department.upsert({ where: { name: "HR" }, update: {}, create: { name: "HR" } });
  const opsDept = await prisma.department.upsert({ where: { name: "Operasional" }, update: {}, create: { name: "Operasional" } });

  const shiftPagi = await findOrCreateShift({
    name: "Shift Pagi", startTime: "08:00", endTime: "17:00",
    workDays: [1, 2, 3, 4, 5], lateToleranceMinutes: 10, isFlexible: false, flexibleHours: null,
  });

  const officePusat = await findOrCreateOffice({
    name: "Kantor Pusat", latitude: -6.2, longitude: 106.816666, radiusMeters: 100, isActive: true,
  });
  const officeOps = await findOrCreateOffice({
    name: "Kantor Operasional", latitude: -6.2088, longitude: 106.8456, radiusMeters: 150, isActive: true,
  });

  const year = new Date().getFullYear();
  await findOrCreateHoliday({ name: "Tahun Baru", date: new Date(Date.UTC(year, 0, 1)), isCustom: false });
  await findOrCreateHoliday({ name: "Hari Kemerdekaan", date: new Date(Date.UTC(year, 7, 17)), isCustom: false });

  const users = [
    { name: "Super Admin", email: "superadmin@rekapin.local", nip: "f1qxzz", password: "f1qxzz", role: "SUPER_ADMIN", departmentId: hrDept.id },
    { name: "HR", email: "hr@rekapin.local", nip: "hr", password: "hr123", role: "HR", departmentId: hrDept.id },
    { name: "Manajer", email: "manajer@rekapin.local", nip: "manajer", password: "manajer123", role: "MANAJER", departmentId: opsDept.id },
    { name: "Karyawan", email: "karyawan@rekapin.local", nip: "karyawan", password: "karyawan123", role: "KARYAWAN", departmentId: opsDept.id },
  ];

  const created = {};
  for (const user of users) {
    created[user.role] = await upsertUser(user, shiftPagi.id, [officePusat.id, officeOps.id]);
  }

  await prisma.user.update({ where: { id: created.SUPER_ADMIN.id }, data: { directManagerId: null } });
  await prisma.user.update({ where: { id: created.HR.id }, data: { directManagerId: created.SUPER_ADMIN.id } });
  await prisma.user.update({ where: { id: created.MANAJER.id }, data: { directManagerId: created.SUPER_ADMIN.id } });
  await prisma.user.update({ where: { id: created.KARYAWAN.id }, data: { directManagerId: created.MANAJER.id } });

  console.log("Users seeded. Creating dummy attendance data...");

  const karyawan = created.KARYAWAN;
  const manajer = created.MANAJER;

  for (let i = 5; i >= 1; i--) {
    const d = daysAgo(i);
    const day = d.getDay();
    if (day === 0 || day === 6) continue;

    const checkInTime = new Date(d);
    checkInTime.setHours(8, Math.floor(Math.random() * 12), 0, 0);
    const checkOutTime = new Date(d);
    checkOutTime.setHours(17, Math.floor(Math.random() * 30), 0, 0);

    const isLate = checkInTime.getHours() > 8 || (checkInTime.getHours() === 8 && checkInTime.getMinutes() > 10);

    try {
      await prisma.attendance.create({
        data: {
          userId: karyawan.id, type: "MASUK", timestamp: checkInTime,
          lat: -6.2, lng: 106.816666, accuracy: 8, withinRadius: true,
          photoUrl: "local://dummy", photoHash: "dummy",
          faceDetected: true, faceScore: 0.92,
          distanceM: 45, shiftId: shiftPagi.id,
          status: isLate ? "TERLAMBAT" : "HADIR",
          anomalyFlag: false, anomalyReason: null,
          syncedAt: checkInTime,
        },
      });
      await prisma.attendance.create({
        data: {
          userId: karyawan.id, type: "PULANG", timestamp: checkOutTime,
          lat: -6.2, lng: 106.816666, accuracy: 8, withinRadius: true,
          photoUrl: "local://dummy", photoHash: "dummy",
          faceDetected: true, faceScore: 0.91,
          distanceM: 45, shiftId: shiftPagi.id,
          status: "HADIR",
          anomalyFlag: false, anomalyReason: null,
          syncedAt: checkOutTime,
        },
      });
    } catch (_) {}
  }

  const today = new Date();
  const todayDay = today.getDay();
  if (todayDay !== 0 && todayDay !== 6) {
    try {
      await prisma.attendance.create({
        data: {
          userId: karyawan.id, type: "MASUK", timestamp: todayAt(8, 5),
          lat: -6.2, lng: 106.816666, accuracy: 10, withinRadius: true,
          photoUrl: "local://dummy", photoHash: "dummy",
          faceDetected: true, faceScore: 0.93,
          distanceM: 42, shiftId: shiftPagi.id,
          status: "HADIR", anomalyFlag: false,
          syncedAt: new Date(),
        },
      });
    } catch (_) {}

    try {
      await prisma.attendance.create({
        data: {
          userId: manajer.id, type: "MASUK", timestamp: todayAt(8, 3),
          lat: -6.2, lng: 106.816666, accuracy: 7, withinRadius: true,
          photoUrl: "local://dummy", photoHash: "dummy",
          faceDetected: true, faceScore: 0.95,
          distanceM: 30, shiftId: shiftPagi.id,
          status: "HADIR", anomalyFlag: false,
          syncedAt: new Date(),
        },
      });
    } catch (_) {}
  }

  console.log("Attendance data seeded.");

  const leaveDateFrom = new Date();
  leaveDateFrom.setDate(leaveDateFrom.getDate() + 5);
  const leaveDateTo = new Date(leaveDateFrom);
  leaveDateTo.setDate(leaveDateTo.getDate() + 2);

  try {
    await prisma.leaveRequest.create({
      data: {
        userId: karyawan.id, type: "CUTI_TAHUNAN",
        dateFrom: leaveDateFrom, dateTo: leaveDateTo,
        reason: "Liburan keluarga",
        status: "MENUNGGU_MANAJER",
      },
    });
  } catch (_) {}

  const pastFrom = daysAgo(10);
  const pastTo = daysAgo(8);
  try {
    const approvedLeave = await prisma.leaveRequest.create({
      data: {
        userId: karyawan.id, type: "CUTI_TAHUNAN",
        dateFrom: pastFrom, dateTo: pastTo,
        reason: "Keperluan keluarga",
        status: "DISETUJUI",
        managerApprovedAt: daysAgo(9),
        hrApprovedAt: daysAgo(9),
      },
    });
    const days = Math.floor((pastTo - pastFrom) / (1000 * 60 * 60 * 24)) + 1;
    await upsertLeaveBalance(karyawan.id, days);
  } catch (_) {}

  const sickFrom = daysAgo(15);
  try {
    await prisma.leaveRequest.create({
      data: {
        userId: karyawan.id, type: "SAKIT",
        dateFrom: sickFrom, dateTo: sickFrom,
        reason: "Demam",
        status: "DISETUJUI",
        managerApprovedAt: daysAgo(14),
      },
    });
  } catch (_) {}

  try {
    await prisma.leaveRequest.create({
      data: {
        userId: manajer.id, type: "CUTI_TAHUNAN",
        dateFrom: daysAgo(3), dateTo: daysAgo(2),
        reason: "Urusan pribadi",
        status: "DISETUJUI",
        managerApprovedAt: daysAgo(4),
        hrApprovedAt: daysAgo(4),
      },
    });
  } catch (_) {}

  console.log("Leave requests seeded.");

  const notifTypes = [
    { type: "ATTENDANCE_SUCCESS", title: "Absensi berhasil", body: "Masuk tercatat pukul 08:05" },
    { type: "LEAVE_REQUEST", title: "Pengajuan izin/cuti baru", body: "Karyawan mengajukan cuti tahunan" },
    { type: "CHECK_IN_REMINDER", title: "Pengingat absen masuk", body: "Shift Pagi mulai pukul 08:00" },
  ];
  for (const n of notifTypes) {
    try {
      await prisma.notification.create({
        data: { userId: manajer.id, type: n.type, title: n.title, body: n.body },
      });
    } catch (_) {}
  }

  console.log("Notifications seeded.");
  console.log("\nSeed complete. Accounts:");
  console.log("SUPER_ADMIN: f1qxzz / f1qxzz");
  console.log("HR: hr / hr123");
  console.log("MANAJER: manajer / manajer123");
  console.log("KARYAWAN: karyawan / karyawan123");
  console.log("\nDummy data: attendance (5 hari + hari ini), leave requests, notifications");
}

main()
  .catch((error) => { console.error(error); process.exit(1); })
  .finally(async () => { await prisma.$disconnect(); });
