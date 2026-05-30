const prisma = require("../../lib/prisma");
const env = require("../../config/env");
const crypto = require("node:crypto");
const { startOfMonth, endOfMonth } = require("../../utils/date");
const { badRequest } = require("../../utils/errors");

async function attendanceSummary({ month, userId }) {
  if (!/^\d{4}-\d{2}$/.test(month)) throw badRequest("Format month harus YYYY-MM");

  const where = {
    timestamp: {
      gte: startOfMonth(month),
      lte: endOfMonth(month),
    },
    userId: userId || undefined,
  };

  const [attendances, overtime] = await Promise.all([
    prisma.attendance.findMany({ where }),
    prisma.overtimeRecord.findMany({
      where: {
        status: "DISETUJUI",
        attendance: where,
      },
      include: { attendance: true },
    }),
  ]);

  const grouped = new Map();

  for (const attendance of attendances) {
    const current = grouped.get(attendance.userId) || emptySummary(attendance.userId, month);
    if (attendance.status === "HADIR") current.totalHadir += 1;
    if (attendance.status === "TERLAMBAT") current.totalTerlambat += 1;
    if (attendance.status === "IZIN") current.totalIzin += 1;
    if (attendance.status === "CUTI") current.totalCuti += 1;
    if (attendance.status === "ABSEN") current.totalKetidakhadiranTidakSah += 1;
    grouped.set(attendance.userId, current);
  }

  for (const item of overtime) {
    const current = grouped.get(item.attendance.userId) || emptySummary(item.attendance.userId, month);
    current.totalLemburJam += item.durationMinutes / 60;
    grouped.set(item.attendance.userId, current);
  }

  return userId ? grouped.get(userId) || emptySummary(userId, month) : Array.from(grouped.values());
}

async function lockMonthAndNotifyPayroll({ month, lockedBy }) {
  const summary = await attendanceSummary({ month });
  const payload = {
    month,
    lockedBy,
    lockedAt: new Date().toISOString(),
    summary,
  };

  if (!env.PAYROLL_WEBHOOK_URL) {
    return {
      delivered: false,
      reason: "PAYROLL_WEBHOOK_URL belum dikonfigurasi",
      payload,
    };
  }

  const response = await fetch(env.PAYROLL_WEBHOOK_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Payroll-Signature": signPayload(payload),
    },
    body: JSON.stringify(payload),
  });

  return {
    delivered: response.ok,
    status: response.status,
    payload,
  };
}

function signPayload(payload) {
  if (!env.PAYROLL_WEBHOOK_SECRET) return "";
  return crypto
    .createHmac("sha256", env.PAYROLL_WEBHOOK_SECRET)
    .update(JSON.stringify(payload))
    .digest("hex");
}

function emptySummary(userId, month) {
  return {
    userId,
    month,
    totalHadir: 0,
    totalTerlambat: 0,
    totalIzin: 0,
    totalCuti: 0,
    totalLemburJam: 0,
    totalKetidakhadiranTidakSah: 0,
  };
}

module.exports = {
  attendanceSummary,
  lockMonthAndNotifyPayroll,
};
