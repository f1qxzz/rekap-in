const prisma = require("../../lib/prisma");
const { writeAuditLog } = require("../../middleware/audit");
const { createNotification } = require("../notifications/notification.service");
const { badRequest, forbidden, notFound } = require("../../utils/errors");
const { businessDaysInclusive } = require("../../utils/date");
const { broadcast: broadcastSSE } = require("../../lib/sse");

async function listMine(userId) {
  return prisma.leaveRequest.findMany({
    where: { userId },
    orderBy: { createdAt: "desc" },
  });
}

async function createLeaveRequest(user, payload) {
  const dateFrom = new Date(payload.dateFrom);
  const dateTo = new Date(payload.dateTo);
  if (dateTo < dateFrom) throw badRequest("Tanggal selesai tidak boleh sebelum tanggal mulai");

  const days = businessDaysInclusive(dateFrom, dateTo);
  if (payload.type === "CUTI_TAHUNAN") {
    const balance = await getOrCreateBalance(user.id, dateFrom.getFullYear());
    if (balance.remaining < days) {
      throw badRequest("Saldo cuti tidak cukup");
    }
  }

  const request = await prisma.leaveRequest.create({
    data: {
      userId: user.id,
      type: payload.type,
      dateFrom,
      dateTo,
      reason: payload.reason,
      documentUrl: payload.documentUrl || null,
      replacementUserId: payload.replacementUserId || null,
      status: "MENUNGGU_MANAJER",
    },
  });

  if (user.directManagerId) {
    await createNotification({
      userId: user.directManagerId,
      type: "LEAVE_REQUEST",
      title: "Pengajuan izin/cuti baru",
      body: `${user.name} mengajukan ${payload.type.toLowerCase()} ${days} hari.`,
      metadata: { leaveRequestId: request.id },
    });
  }

  broadcastSSE("leave:created", {
    userId: user.id,
    userName: user.name,
    leaveId: request.id,
    type: payload.type,
    days,
  }, { role: "MANAJER" });
  broadcastSSE("leave:created", {
    userId: user.id,
    userName: user.name,
    leaveId: request.id,
    type: payload.type,
    days,
  }, { role: "HR" });

  return request;
}

async function managerApproval(actor, id, payload) {
  const request = await prisma.leaveRequest.findUnique({
    where: { id },
    include: { user: true },
  });
  if (!request) throw notFound("Pengajuan tidak ditemukan");
  if (request.status !== "MENUNGGU_MANAJER") throw badRequest("Status pengajuan tidak menunggu manajer");

  const isDirectManager = request.user.directManagerId === actor.id;
  const isHr = ["HR", "SUPER_ADMIN"].includes(actor.role);
  if (!isDirectManager && !isHr) throw forbidden("Hanya manajer langsung atau HR yang bisa approval level 1");

  if (payload.action === "REJECT") {
    if (!payload.comment) throw badRequest("Komentar wajib jika menolak");
    return rejectRequest(actor, request, payload.comment, "MANAGER_REJECT");
  }

  const days = businessDaysInclusive(request.dateFrom, request.dateTo);
  const approveFinal = days <= 3 || isHr;
  const nextStatus = approveFinal ? "DISETUJUI" : "MENUNGGU_HR";
  const updated = await prisma.leaveRequest.update({
    where: { id },
    data: {
      status: nextStatus,
      managerApprovedAt: new Date(),
      managerComment: payload.comment || null,
      ...(approveFinal && isHr
        ? {
            hrApprovedAt: new Date(),
            hrComment: payload.comment || null,
          }
        : {}),
    },
  });

  if (nextStatus === "DISETUJUI") {
    await finalizeApprovedLeave(updated);
  } else {
    await notifyHr(updated);
    await createNotification({
      userId: request.userId,
      type: "LEAVE_ESCALATED",
      title: "Pengajuan diproses HR",
      body: "Pengajuan izin/cuti kamu lebih dari 3 hari dan sedang menunggu persetujuan HR.",
      metadata: { leaveRequestId: request.id },
    });
  }

  broadcastSSE("leave:updated", {
    userId: request.userId,
    leaveId: request.id,
    status: nextStatus,
    approvedBy: actor.name,
  });
  broadcastSSE("leave:updated", {
    userId: request.userId,
    leaveId: request.id,
    status: nextStatus,
  }, { role: "HR" });

  await writeAuditLog({
    adminUserId: actor.id,
    action: "LEAVE_MANAGER_APPROVE",
    targetTable: "leave_requests",
    targetId: id,
    beforeData: request,
    afterData: updated,
    reason: payload.comment,
  });

  return updated;
}

async function hrApproval(actor, id, payload) {
  if (!["HR", "SUPER_ADMIN"].includes(actor.role)) throw forbidden("Hanya HR yang bisa approval final");

  const request = await prisma.leaveRequest.findUnique({
    where: { id },
    include: { user: true },
  });
  if (!request) throw notFound("Pengajuan tidak ditemukan");
  if (request.status !== "MENUNGGU_HR") throw badRequest("Status pengajuan tidak menunggu HR");

  if (payload.action === "REJECT") {
    if (!payload.comment) throw badRequest("Komentar wajib jika menolak");
    return rejectRequest(actor, request, payload.comment, "HR_REJECT");
  }

  const updated = await prisma.leaveRequest.update({
    where: { id },
    data: {
      status: "DISETUJUI",
      hrApprovedAt: new Date(),
      hrComment: payload.comment || null,
    },
  });

  await finalizeApprovedLeave(updated);
  await writeAuditLog({
    adminUserId: actor.id,
    action: "LEAVE_HR_APPROVE",
    targetTable: "leave_requests",
    targetId: id,
    beforeData: request,
    afterData: updated,
    reason: payload.comment,
  });

  broadcastSSE("leave:updated", {
    userId: request.userId,
    leaveId: request.id,
    status: "DISETUJUI",
    approvedBy: actor.name,
  });

  return updated;
}

async function listPending(actor) {
  const where = ["HR", "SUPER_ADMIN"].includes(actor.role)
    ? { status: { in: ["MENUNGGU_MANAJER", "MENUNGGU_HR", "ESKALASI"] } }
    : { status: "MENUNGGU_MANAJER", user: { directManagerId: actor.id } };

  return prisma.leaveRequest.findMany({
    where,
    include: { user: true },
    orderBy: { createdAt: "asc" },
  });
}

async function rejectRequest(actor, request, comment, action) {
  const updated = await prisma.leaveRequest.update({
    where: { id: request.id },
    data: {
      status: "DITOLAK",
      rejectionReason: comment,
    },
  });

  await createNotification({
    userId: request.userId,
    type: "LEAVE_REJECTED",
    title: "Pengajuan ditolak",
    body: comment,
    metadata: { leaveRequestId: request.id },
  });

  await writeAuditLog({
    adminUserId: actor.id,
    action,
    targetTable: "leave_requests",
    targetId: request.id,
    beforeData: request,
    afterData: updated,
    reason: comment,
  });

  broadcastSSE("leave:updated", {
    userId: request.userId,
    leaveId: request.id,
    status: "DITOLAK",
    rejectedBy: actor.name,
    reason: comment,
  });

  return updated;
}

async function finalizeApprovedLeave(request) {
  const days = businessDaysInclusive(request.dateFrom, request.dateTo);

  if (request.type === "CUTI_TAHUNAN") {
    const balance = await getOrCreateBalance(request.userId, request.dateFrom.getFullYear());
    await prisma.leaveBalance.update({
      where: { id: balance.id },
      data: {
        used: { increment: days },
        remaining: { decrement: days },
      },
    });
  }

  await createAttendancePlaceholders(request);
  await createNotification({
    userId: request.userId,
    type: "LEAVE_APPROVED",
    title: "Pengajuan disetujui",
    body: "Kalender absensi sudah diperbarui.",
    metadata: { leaveRequestId: request.id },
  });
}

async function createAttendancePlaceholders(request) {
  let cursor = new Date(request.dateFrom);
  const end = new Date(request.dateTo);

  while (cursor <= end) {
    await prisma.attendance.upsert({
      where: {
        userId_type_timestamp: {
          userId: request.userId,
          type: "MASUK",
          timestamp: cursor,
        },
      },
      update: {
        status: request.type === "CUTI_TAHUNAN" ? "CUTI" : "IZIN",
        notes: "Terisi otomatis dari izin/cuti yang disetujui",
      },
      create: {
        userId: request.userId,
        type: "MASUK",
        timestamp: cursor,
        lat: 0,
        lng: 0,
        accuracy: 0,
        photoUrl: "system://approved-leave",
        photoHash: "0".repeat(64),
        faceDetected: false,
        distanceM: 0,
        withinRadius: true,
        isMockGps: false,
        status: request.type === "CUTI_TAHUNAN" ? "CUTI" : "IZIN",
        notes: "Terisi otomatis dari izin/cuti yang disetujui",
        syncedAt: new Date(),
      },
    });

    cursor = new Date(cursor.getTime() + 24 * 60 * 60 * 1000);
  }
}

async function notifyHr(request) {
  const hrs = await prisma.user.findMany({
    where: { role: { in: ["HR", "SUPER_ADMIN"] }, isActive: true },
    select: { id: true },
  });

  await Promise.all(
    hrs.map((hr) =>
      createNotification({
        userId: hr.id,
        type: "LEAVE_HR_REVIEW",
        title: "Pengajuan butuh approval HR",
        body: "Cuti lebih dari 3 hari menunggu approval final.",
        metadata: { leaveRequestId: request.id },
      }),
    ),
  );
}

async function getOrCreateBalance(userId, year) {
  const balance = await prisma.leaveBalance.findUnique({
    where: { userId_year: { userId, year } },
  });
  if (balance) return balance;

  return prisma.leaveBalance.create({
    data: {
      userId,
      year,
      annualQuota: 12,
      used: 0,
      remaining: 12,
    },
  });
}

async function getBalance(userId) {
  const year = new Date().getFullYear();
  const balance = await getOrCreateBalance(userId, year);

  const approvedRequests = await prisma.leaveRequest.findMany({
    where: {
      userId,
      status: "DISETUJUI",
      dateFrom: { gte: new Date(year, 0, 1) },
      dateTo: { lte: new Date(year, 11, 31) },
    },
    select: {
      type: true,
      dateFrom: true,
      dateTo: true,
    },
  });

  const used = approvedRequests.reduce(
    (totals, request) => {
      const days = businessDaysInclusive(request.dateFrom, request.dateTo);
      if (request.type === "CUTI_TAHUNAN") totals.cuti += days;
      if (request.type === "SAKIT") totals.sakit += days;
      if (["IZIN_MENDESAK", "DINAS_LUAR"].includes(request.type)) {
        totals.izin += days;
      }
      return totals;
    },
    { cuti: 0, sakit: 0, izin: 0 },
  );

  return {
    year,
    cuti: {
      used: used.cuti,
      total: balance.annualQuota,
      remaining: Math.max(balance.annualQuota - used.cuti, 0),
    },
    sakit: { used: used.sakit, total: -1 },
    izin: { used: used.izin, total: -1 },
  };
}

module.exports = {
  createLeaveRequest,
  getBalance,
  hrApproval,
  listMine,
  listPending,
  managerApproval,
};
