const prisma = require("../lib/prisma");
const { createNotification } = require("../modules/notifications/notification.service");
const { dayjs } = require("../utils/date");

let started = false;

function startScheduler() {
  if (started || process.env.NODE_ENV === "test") return;
  started = true;

  runScheduledTasks().catch((error) => console.error("Initial scheduler run failed", error));
  setInterval(() => {
    runScheduledTasks().catch((error) => console.error("Scheduler run failed", error));
  }, 60 * 1000);
}

async function runScheduledTasks() {
  const results = await Promise.allSettled([
    sendCheckInReminders(),
    escalateLeaveRequests(),
    escalateOvertimeRequests(),
    cleanupExpiredTokens(),
  ]);
  for (const result of results) {
    if (result.status === "rejected") {
      console.error("Scheduled task failed:", result.reason);
    }
  }
}

async function sendCheckInReminders() {
  const now = dayjs();
  const users = await prisma.user.findMany({
    where: {
      isActive: true,
      isApproved: true,
      shift: { isNot: null },
    },
    include: { shift: true },
  });

  const todayStart = now.startOf("day").toDate();
  const todayEnd = now.endOf("day").toDate();

  const todayCheckIns = await prisma.attendance.findMany({
    where: {
      type: "MASUK",
      timestamp: { gte: todayStart, lte: todayEnd },
    },
    select: { userId: true },
  });
  const checkedInUserIds = new Set(todayCheckIns.map((r) => r.userId));

  for (const user of users) {
    const [hour, minute] = user.shift.startTime.split(":").map(Number);
    const shiftStart = now.hour(hour).minute(minute).second(0).millisecond(0);
    const reminderAt = shiftStart.subtract(30, "minute");
    const lateAlertAt = shiftStart.add(15, "minute");

    if (Math.abs(now.diff(reminderAt, "minute")) === 0) {
      await createNotification({
        userId: user.id,
        type: "CHECK_IN_REMINDER",
        title: "Pengingat absen masuk",
        body: `Shift ${user.shift.name} mulai pukul ${user.shift.startTime}.`,
      });
    }

    if (Math.abs(now.diff(lateAlertAt, "minute")) === 0 && !checkedInUserIds.has(user.id)) {
      await createNotification({
        userId: user.id,
        type: "MISSING_CHECK_IN",
        title: "Belum absen masuk",
        body: "Kamu belum absen masuk 15 menit setelah shift dimulai.",
      });
      if (user.directManagerId) {
        await createNotification({
          userId: user.directManagerId,
          type: "EMPLOYEE_MISSING_CHECK_IN",
          title: "Karyawan belum absen",
          body: `${user.name} belum absen masuk hari ini.`,
          metadata: { userId: user.id },
        });
      }
    }
  }
}

async function escalateLeaveRequests() {
  const managerDeadline = dayjs().subtract(2, "day").toDate();
  const hrDeadline = dayjs().subtract(3, "day").toDate();

  const managerRows = await prisma.leaveRequest.findMany({
    where: {
      status: "MENUNGGU_MANAJER",
      createdAt: { lte: managerDeadline },
    },
  });

  for (const request of managerRows) {
    await prisma.leaveRequest.update({
      where: { id: request.id },
      data: { status: "ESKALASI" },
    });
    await notifyHrEscalation(request.id, "Pengajuan izin/cuti melewati batas approval manajer.");
  }

  const hrRows = await prisma.leaveRequest.findMany({
    where: {
      status: "MENUNGGU_HR",
      managerApprovedAt: { lte: hrDeadline },
    },
  });

  for (const request of hrRows) {
    await prisma.leaveRequest.update({
      where: { id: request.id },
      data: { status: "ESKALASI" },
    });
    await notifyHrEscalation(request.id, "Pengajuan izin/cuti melewati batas approval HR.");
  }
}

async function escalateOvertimeRequests() {
  const deadline = dayjs().subtract(24, "hour").toDate();
  const rows = await prisma.overtimeRecord.findMany({
    where: {
      status: "MENUNGGU",
      createdAt: { lte: deadline },
    },
    include: { attendance: { include: { user: true } } },
  });

  for (const row of rows) {
    await prisma.overtimeRecord.update({
      where: { id: row.id },
      data: {
        status: "ESKALASI",
        escalatedAt: new Date(),
      },
    });
    if (row.attendance.user.directManagerId) {
      await createNotification({
        userId: row.attendance.user.directManagerId,
        type: "OVERTIME_ESCALATED",
        title: "Lembur butuh eskalasi",
        body: `Pengajuan lembur ${row.attendance.user.name} belum diproses 24 jam.`,
        metadata: { overtimeRecordId: row.id },
      });
    }
  }
}

async function notifyHrEscalation(leaveRequestId, body) {
  const hrs = await prisma.user.findMany({
    where: { role: { in: ["HR", "SUPER_ADMIN"] }, isActive: true },
    select: { id: true },
  });
  await Promise.all(
    hrs.map((hr) =>
      createNotification({
        userId: hr.id,
        type: "LEAVE_ESCALATED",
        title: "Pengajuan dieskalasi",
        body,
        metadata: { leaveRequestId },
      }),
    ),
  );
}

async function cleanupExpiredTokens() {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

  const [refreshResult, resetResult] = await Promise.all([
    prisma.refreshToken.deleteMany({
      where: {
        OR: [
          { expiresAt: { lt: new Date() } },
          { revokedAt: { lt: thirtyDaysAgo } },
        ],
      },
    }),
    prisma.passwordResetToken.deleteMany({
      where: {
        OR: [
          { expiresAt: { lt: new Date() } },
          { usedAt: { lt: thirtyDaysAgo } },
        ],
      },
    }),
  ]);

  const totalDeleted = refreshResult.count + resetResult.count;
  if (totalDeleted > 0) {
    console.log(`[cleanup] Removed ${refreshResult.count} refresh tokens, ${resetResult.count} password reset tokens`);
  }
}

module.exports = {
  runScheduledTasks,
  startScheduler,
};

