const argon2 = require("argon2");
const prisma = require("../../lib/prisma");
const { writeAuditLog } = require("../../middleware/audit");
const { badRequest, notFound, forbidden } = require("../../utils/errors");
const { canModifyTarget, canAssignRole } = require("../../middleware/auth");
const { createNotification } = require("../notifications/notification.service");

async function listUsers(query = {}) {
  const take = Math.min(parseInt(query.limit, 10) || 50, 200);
  const skip = parseInt(query.offset, 10) || 0;

  const [users, total] = await Promise.all([
    prisma.user.findMany({
      where: {
        role: query.role,
        isActive: query.isActive === undefined ? undefined : query.isActive === "true",
      },
      include: {
        department: true,
        shift: true,
        officeLocations: true,
      },
      orderBy: { createdAt: "desc" },
      take,
      skip,
    }),
    prisma.user.count({
      where: {
        role: query.role,
        isActive: query.isActive === undefined ? undefined : query.isActive === "true",
      },
    }),
  ]);

  return { data: users, total, take, skip };
}

async function summary() {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date(todayStart);
  todayEnd.setDate(todayEnd.getDate() + 1);

  const [
    totalUsers,
    activeUsers,
    activeEmployees,
    pendingApproval,
    pendingLeaves,
    reviewAttendances,
    activeOffices,
    totalShifts,
    totalDepartments,
    todayCheckIns,
  ] = await Promise.all([
    prisma.user.count(),
    prisma.user.count({ where: { isActive: true } }),
    prisma.user.count({ where: { isActive: true, isApproved: true, role: "KARYAWAN" } }),
    prisma.user.count({ where: { isApproved: false } }),
    prisma.leaveRequest.count({
      where: { status: { in: ["MENUNGGU_MANAJER", "MENUNGGU_HR", "ESKALASI"] } },
    }),
    prisma.attendance.count({ where: { anomalyFlag: true } }),
    prisma.officeLocation.count({ where: { isActive: true } }),
    prisma.shift.count(),
    prisma.department.count(),
    prisma.attendance.count({
      where: {
        type: "MASUK",
        timestamp: { gte: todayStart, lt: todayEnd },
      },
    }),
  ]);

  return {
    totalUsers,
    activeUsers,
    activeEmployees,
    pendingApproval,
    pendingLeaves,
    reviewAttendances,
    activeOffices,
    totalShifts,
    totalDepartments,
    todayCheckIns,
  };
}

async function createUser(admin, payload) {
  if (payload.role === "SUPER_ADMIN" && admin.role !== "SUPER_ADMIN") {
    throw forbidden("Hanya Super Admin yang bisa membuat akun Super Admin");
  }
  if (!canAssignRole(admin.role, payload.role)) {
    throw forbidden("Tidak bisa membuat user dengan role " + payload.role);
  }
  const exists = await prisma.user.findFirst({
    where: { OR: [{ email: payload.email }, { nip: payload.nip }] },
  });
  if (exists) throw badRequest("Email atau NIP sudah digunakan");

  const user = await prisma.user.create({
    data: {
      name: payload.name,
      email: payload.email.toLowerCase(),
      nip: payload.nip,
      phone: payload.phone || null,
      passwordHash: await argon2.hash(payload.password),
      departmentId: payload.departmentId || null,
      shiftId: payload.shiftId || null,
      directManagerId: payload.directManagerId || null,
      role: payload.role,
      isApproved: true,
      emailVerified: true,
      officeLocations: payload.officeLocationIds
        ? {
            connect: payload.officeLocationIds.map((officeId) => ({ id: officeId })),
          }
        : undefined,
    },
    include: { department: true, shift: true, officeLocations: true },
  });

  await writeAuditLog({
    adminUserId: admin.id,
    action: "USER_CREATE",
    targetTable: "users",
    targetId: user.id,
    afterData: safeUser(user),
    reason: "Admin created user",
  });

  return safeUser(user);
}

async function updateUser(admin, id, payload) {
  const before = await prisma.user.findUnique({ where: { id }, include: { officeLocations: true } });
  if (!before) throw notFound("User tidak ditemukan");
  if (before.role === "SUPER_ADMIN" && admin.role !== "SUPER_ADMIN") {
    throw forbidden("Tidak bisa mengedit akun Super Admin");
  }
  if (!canModifyTarget(admin.role, before.role)) {
    throw forbidden("Tidak bisa mengedit user dengan role " + before.role);
  }

  const { officeLocationIds, ...data } = payload;
  const updated = await prisma.user.update({
    where: { id },
    data: {
      ...data,
      officeLocations: officeLocationIds
        ? {
            set: officeLocationIds.map((officeId) => ({ id: officeId })),
          }
        : undefined,
    },
    include: { officeLocations: true },
  });

  await writeAuditLog({
    adminUserId: admin.id,
    action: "USER_UPDATE",
    targetTable: "users",
    targetId: id,
    beforeData: safeUser(before),
    afterData: safeUser(updated),
    reason: "Admin updated user",
  });

  return updated;
}

async function approveUser(admin, id, { approved, reason }) {
  const before = await prisma.user.findUnique({ where: { id } });
  if (!before) throw notFound("User tidak ditemukan");
  if (before.role === "SUPER_ADMIN" && admin.role !== "SUPER_ADMIN") {
    throw forbidden("Tidak bisa approve/reject akun Super Admin");
  }
  if (!canModifyTarget(admin.role, before.role)) {
    throw forbidden("Tidak bisa approve/reject user dengan role " + before.role);
  }

  const updated = await prisma.user.update({
    where: { id },
    data: { isApproved: approved },
  });

  await writeAuditLog({
    adminUserId: admin.id,
    action: approved ? "USER_APPROVE" : "USER_UNAPPROVE",
    targetTable: "users",
    targetId: id,
    beforeData: safeUser(before),
    afterData: safeUser(updated),
    reason,
  });

  await createNotification({
    userId: id,
    type: "ACCOUNT_APPROVAL",
    title: approved ? "Akun disetujui" : "Akun belum aktif",
    body: approved ? "Akun kamu sudah bisa digunakan." : "Akun kamu perlu ditinjau ulang HR.",
  });

  return updated;
}

async function updateRole(admin, id, { role, reason }) {
  const before = await prisma.user.findUnique({ where: { id } });
  if (!before) throw notFound("User tidak ditemukan");
  if (before.role === "SUPER_ADMIN" && admin.role !== "SUPER_ADMIN") {
    throw forbidden("Tidak bisa mengubah role Super Admin");
  }
  if (role === "SUPER_ADMIN" && admin.role !== "SUPER_ADMIN") {
    throw forbidden("Hanya Super Admin yang bisa menetapkan role Super Admin");
  }
  if (!canAssignRole(admin.role, role)) {
    throw forbidden("Tidak bisa menetapkan role " + role);
  }
  if (!canModifyTarget(admin.role, before.role)) {
    throw forbidden("Tidak bisa mengubah role user dengan role " + before.role);
  }

  const updated = await prisma.user.update({
    where: { id },
    data: { role },
  });

  await writeAuditLog({
    adminUserId: admin.id,
    action: "USER_ROLE_UPDATE",
    targetTable: "users",
    targetId: id,
    beforeData: safeUser(before),
    afterData: safeUser(updated),
    reason,
  });

  return updated;
}

async function importUsers(admin, rows) {
  const results = [];
  for (const row of rows) {
    try {
      const user = await createUser(admin, row);
      results.push({ email: row.email, status: "CREATED", id: user.id });
    } catch (error) {
      results.push({ email: row.email, status: "FAILED", message: error.message });
    }
  }
  return { results };
}

async function createShift(admin, payload) {
  const shift = await prisma.shift.create({ data: payload });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "SHIFT_CREATE",
    targetTable: "shifts",
    targetId: shift.id,
    afterData: shift,
  });
  return shift;
}

async function listShifts() {
  return prisma.shift.findMany({ orderBy: { name: "asc" } });
}

async function updateShift(admin, id, payload) {
  const before = await prisma.shift.findUnique({ where: { id } });
  if (!before) throw notFound("Shift tidak ditemukan");

  const updated = await prisma.shift.update({ where: { id }, data: payload });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "SHIFT_UPDATE",
    targetTable: "shifts",
    targetId: id,
    beforeData: before,
    afterData: updated,
  });
  return updated;
}

async function deleteShift(admin, id) {
  const before = await prisma.shift.findUnique({ where: { id } });
  if (!before) throw notFound("Shift tidak ditemukan");

  const [users, attendances] = await Promise.all([
    prisma.user.count({ where: { shiftId: id } }),
    prisma.attendance.count({ where: { shiftId: id } }),
  ]);
  if (users > 0 || attendances > 0) {
    throw badRequest("Shift masih dipakai user atau data absensi");
  }

  const deleted = await prisma.shift.delete({ where: { id } });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "SHIFT_DELETE",
    targetTable: "shifts",
    targetId: id,
    beforeData: before,
  });
  return deleted;
}

async function createOffice(admin, payload) {
  const office = await prisma.officeLocation.create({ data: payload });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "OFFICE_CREATE",
    targetTable: "office_locations",
    targetId: office.id,
    afterData: office,
  });
  return office;
}

async function listOffices() {
  return prisma.officeLocation.findMany({ orderBy: { name: "asc" } });
}

async function updateOffice(admin, id, payload) {
  const before = await prisma.officeLocation.findUnique({ where: { id } });
  if (!before) throw notFound("Lokasi kantor tidak ditemukan");

  const updated = await prisma.officeLocation.update({ where: { id }, data: payload });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "OFFICE_UPDATE",
    targetTable: "office_locations",
    targetId: id,
    beforeData: before,
    afterData: updated,
  });
  return updated;
}

async function deleteOffice(admin, id) {
  const before = await prisma.officeLocation.findUnique({ where: { id }, include: { users: true } });
  if (!before) throw notFound("Lokasi kantor tidak ditemukan");

  await prisma.officeLocation.update({
    where: { id },
    data: { users: { set: [] } },
  });
  const deleted = await prisma.officeLocation.delete({ where: { id } });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "OFFICE_DELETE",
    targetTable: "office_locations",
    targetId: id,
    beforeData: before,
  });
  return deleted;
}

async function listLeaveBalances({ year, userId } = {}) {
  return prisma.leaveBalance.findMany({
    where: {
      year,
      userId,
    },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          nip: true,
          role: true,
          department: true,
        },
      },
    },
    orderBy: [{ year: "desc" }, { user: { name: "asc" } }],
  });
}

async function createLeaveBalance(admin, payload) {
  const user = await prisma.user.findUnique({ where: { id: payload.userId } });
  if (!user) throw notFound("User tidak ditemukan");

  const exists = await prisma.leaveBalance.findUnique({
    where: { userId_year: { userId: payload.userId, year: payload.year } },
  });
  if (exists) throw badRequest("Saldo cuti user untuk tahun ini sudah ada");

  const data = normalizeLeaveBalance(payload);
  const balance = await prisma.leaveBalance.create({
    data: {
      userId: payload.userId,
      year: payload.year,
      ...data,
    },
    include: { user: true },
  });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "LEAVE_BALANCE_CREATE",
    targetTable: "leave_balances",
    targetId: balance.id,
    afterData: balance,
  });
  return balance;
}

async function updateLeaveBalance(admin, id, payload) {
  const before = await prisma.leaveBalance.findUnique({ where: { id } });
  if (!before) throw notFound("Saldo cuti tidak ditemukan");

  const data = normalizeLeaveBalance({ ...before, ...payload });
  const updated = await prisma.leaveBalance.update({
    where: { id },
    data,
    include: { user: true },
  });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "LEAVE_BALANCE_UPDATE",
    targetTable: "leave_balances",
    targetId: id,
    beforeData: before,
    afterData: updated,
  });
  return updated;
}

async function deleteLeaveBalance(admin, id) {
  const before = await prisma.leaveBalance.findUnique({ where: { id }, include: { user: true } });
  if (!before) throw notFound("Saldo cuti tidak ditemukan");

  const deleted = await prisma.leaveBalance.delete({ where: { id } });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "LEAVE_BALANCE_DELETE",
    targetTable: "leave_balances",
    targetId: id,
    beforeData: before,
  });
  return deleted;
}

async function listAnomalies() {
  return prisma.attendance.findMany({
    where: { anomalyFlag: true },
    include: { user: true },
    orderBy: { timestamp: "desc" },
  });
}

async function reviewAnomaly(admin, id, payload) {
  const before = await prisma.attendance.findUnique({ where: { id } });
  if (!before) throw notFound("Absensi tidak ditemukan");

  const status = payload.action === "REJECT" ? "DITOLAK" : "HADIR";
  const updated = await prisma.attendance.update({
    where: { id },
    data: {
      status,
      anomalyFlag: payload.action === "WARN",
      notes: payload.notes,
    },
  });

  await writeAuditLog({
    adminUserId: admin.id,
    action: `ATTENDANCE_ANOMALY_${payload.action}`,
    targetTable: "attendances",
    targetId: id,
    beforeData: before,
    afterData: updated,
    reason: payload.notes,
  });

  return updated;
}

async function listAuditLogs({ targetTable, targetId, limit, offset } = {}) {
  const take = Math.min(parseInt(limit, 10) || 100, 500);
  const skip = parseInt(offset, 10) || 0;

  const [logs, total] = await Promise.all([
    prisma.auditLog.findMany({
      where: { targetTable, targetId },
      orderBy: { createdAt: "desc" },
      take,
      skip,
    }),
    prisma.auditLog.count({
      where: { targetTable, targetId },
    }),
  ]);

  return { data: logs, total, take, skip };
}

async function createDepartment(admin, payload) {
  const exists = await prisma.department.findUnique({ where: { name: payload.name } });
  if (exists) throw badRequest("Department sudah ada");

  const department = await prisma.department.create({ data: payload });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "DEPARTMENT_CREATE",
    targetTable: "departments",
    targetId: department.id,
    afterData: department,
  });
  return department;
}

async function listDepartments() {
  return prisma.department.findMany({ orderBy: { name: "asc" } });
}

async function updateDepartment(admin, id, payload) {
  const before = await prisma.department.findUnique({ where: { id } });
  if (!before) throw notFound("Department tidak ditemukan");

  const exists = await prisma.department.findUnique({ where: { name: payload.name } });
  if (exists && exists.id !== id) throw badRequest("Department sudah ada");

  const updated = await prisma.department.update({ where: { id }, data: payload });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "DEPARTMENT_UPDATE",
    targetTable: "departments",
    targetId: id,
    beforeData: before,
    afterData: updated,
  });
  return updated;
}

async function deleteDepartment(admin, id) {
  const before = await prisma.department.findUnique({ where: { id } });
  if (!before) throw notFound("Department tidak ditemukan");

  const users = await prisma.user.count({ where: { departmentId: id } });
  if (users > 0) throw badRequest("Department masih dipakai user");

  const deleted = await prisma.department.delete({ where: { id } });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "DEPARTMENT_DELETE",
    targetTable: "departments",
    targetId: id,
    beforeData: before,
  });
  return deleted;
}

async function createHoliday(admin, payload) {
  const date = new Date(payload.date);
  const exists = await prisma.holiday.findUnique({
    where: { date_name: { date, name: payload.name } },
  });
  if (exists) throw badRequest("Hari libur sudah ada");

  const holiday = await prisma.holiday.create({
    data: {
      name: payload.name,
      date,
      isCustom: payload.isCustom,
    },
  });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "HOLIDAY_CREATE",
    targetTable: "holidays",
    targetId: holiday.id,
    afterData: holiday,
  });
  return holiday;
}

async function listHolidays() {
  return prisma.holiday.findMany({ orderBy: { date: "asc" } });
}

async function updateHoliday(admin, id, payload) {
  const before = await prisma.holiday.findUnique({ where: { id } });
  if (!before) throw notFound("Hari libur tidak ditemukan");

  const data = {
    ...payload,
    date: payload.date ? new Date(payload.date) : undefined,
  };
  const updated = await prisma.holiday.update({ where: { id }, data });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "HOLIDAY_UPDATE",
    targetTable: "holidays",
    targetId: id,
    beforeData: before,
    afterData: updated,
  });
  return updated;
}

async function deleteHoliday(admin, id) {
  const before = await prisma.holiday.findUnique({ where: { id } });
  if (!before) throw notFound("Hari libur tidak ditemukan");

  const deleted = await prisma.holiday.delete({ where: { id } });
  await writeAuditLog({
    adminUserId: admin.id,
    action: "HOLIDAY_DELETE",
    targetTable: "holidays",
    targetId: id,
    beforeData: before,
  });
  return deleted;
}

function normalizeLeaveBalance(payload) {
  const annualQuota = Number(payload.annualQuota ?? 12);
  const used = Number(payload.used ?? 0);
  if (used > annualQuota) throw badRequest("Cuti terpakai tidak boleh lebih besar dari kuota");
  return {
    annualQuota,
    used,
    remaining: annualQuota - used,
  };
}

function safeUser(user) {
  if (!user) return null;
  const { passwordHash, emailVerifyTokenHash, ...safe } = user;
  return safe;
}

module.exports = {
  approveUser,
  createDepartment,
  createHoliday,
  createLeaveBalance,
  createOffice,
  createShift,
  createUser,
  deleteDepartment,
  deleteHoliday,
  deleteLeaveBalance,
  deleteOffice,
  deleteShift,
  importUsers,
  listAnomalies,
  listAuditLogs,
  listDepartments,
  listHolidays,
  listLeaveBalances,
  listOffices,
  listShifts,
  listUsers,
  reviewAnomaly,
  summary,
  updateDepartment,
  updateHoliday,
  updateLeaveBalance,
  updateOffice,
  updateRole,
  updateShift,
  updateUser,
};
