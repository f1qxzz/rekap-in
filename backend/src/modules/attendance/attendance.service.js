const prisma = require("../../lib/prisma");
const { writeAuditLog } = require("../../middleware/audit");
const { notifyManagersAndAdmins, createNotification } = require("../notifications/notification.service");
const { badRequest, forbidden, notFound } = require("../../utils/errors");
const { haversineDistanceMeters } = require("../../utils/haversine");
const { encryptText } = require("../../utils/crypto");
const {
  assertGpsPolicy,
  calculateOvertimeMinutes,
  determineAttendanceStatus,
} = require("../../utils/attendancePolicy");
const { dayjs, endOfMonth, startOfMonth } = require("../../utils/date");
const { persistAttendancePhoto } = require("./storage.service");
const { broadcast: broadcastSSE } = require("../../lib/sse");

async function getTodayStatus(userId) {
  const today = dayjs();
  const start = today.startOf("day").toDate();
  const end = today.endOf("day").toDate();
  const weekStart = today.startOf("day").subtract((today.day() + 6) % 7, "day");
  const weekEnd = weekStart.add(6, "day").endOf("day");
  const records = await prisma.attendance.findMany({
    where: {
      userId,
      timestamp: { gte: start, lte: end },
    },
    orderBy: { timestamp: "asc" },
  });

  const checkIn = records.find((item) => item.type === "MASUK");
  const checkOut = records.find((item) => item.type === "PULANG");
  const weekly = await getWeeklyDashboard(userId, {
    start: weekStart.toDate(),
    end: weekEnd.toDate(),
  });

  return {
    status: !checkIn ? "BELUM_ABSEN" : checkOut ? "SUDAH_PULANG" : "SUDAH_MASUK",
    checkInAt: checkIn?.timestamp || null,
    checkOutAt: checkOut?.timestamp || null,
    checkIn,
    checkOut,
    weeklySummary: weekly.summary,
    weekEntries: weekly.entries,
  };
}

async function getWeeklyDashboard(userId, { start, end }) {
  const [attendances, leaves] = await Promise.all([
    prisma.attendance.findMany({
      where: {
        userId,
        timestamp: { gte: start, lte: end },
      },
      orderBy: { timestamp: "asc" },
    }),
    prisma.leaveRequest.findMany({
      where: {
        userId,
        status: "DISETUJUI",
        dateFrom: { lte: end },
        dateTo: { gte: start },
      },
      orderBy: { dateFrom: "asc" },
    }),
  ]);

  const byDate = new Map();
  const startDay = dayjs(start).startOf("day");

  for (let index = 0; index < 7; index += 1) {
    const current = startDay.add(index, "day");
    byDate.set(dateKey(current.toDate()), { date: current.format("YYYY-MM-DD") });
  }

  for (const leave of leaves) {
    const leaveStatus = leave.type.includes("CUTI") ? "CUTI" : "IZIN";
    const from = dayjs(leave.dateFrom).startOf("day");
    const to = dayjs(leave.dateTo).startOf("day");
    for (let cursor = from; cursor.isBefore(to) || cursor.isSame(to); cursor = cursor.add(1, "day")) {
      if (cursor.isBefore(startDay) || cursor.isAfter(dayjs(end))) continue;
      const key = cursor.format("YYYY-MM-DD");
      const entry = byDate.get(key);
      if (!entry) continue;
      entry.status = leaveStatus;
      entry.leaveId = leave.id;
    }
  }

  for (const item of attendances) {
    const key = dateKey(item.timestamp);
    const entry = byDate.get(key);
    if (!entry) continue;

    if (item.type === "MASUK") {
      entry.status = item.status;
      entry.checkInAt = item.timestamp;
    }

    if (item.type === "PULANG") {
      entry.checkOutAt = item.timestamp;
      if (!entry.status) entry.status = "HADIR";
    }
  }

  const summary = Array.from(byDate.values()).reduce(
    (acc, entry) => {
      if (entry.status === "HADIR") acc.hadir += 1;
      if (entry.status === "TERLAMBAT") acc.terlambat += 1;
      if (entry.status === "IZIN") acc.izin += 1;
      if (entry.status === "CUTI") acc.cuti += 1;
      return acc;
    },
    { hadir: 0, terlambat: 0, izin: 0, cuti: 0 },
  );

  return {
    summary,
    entries: Array.from(byDate.values()),
  };
}

async function getHistory(userId, { month, status }) {
  const selectedMonth = month || dayjs().format("YYYY-MM");
  const where = {
    userId,
    timestamp: {
      gte: startOfMonth(selectedMonth),
      lte: endOfMonth(selectedMonth),
    },
  };

  if (status) where.status = status;

  return prisma.attendance.findMany({
    where,
    orderBy: { timestamp: "desc" },
  });
}

async function createAttendance(user, payload, reqMeta = {}) {
  const gpsDecision = assertGpsPolicy({
    accuracy: payload.accuracy,
    isMockLocation: payload.isMockLocationDetected,
    platform: payload.platform,
  });

  if (!gpsDecision.allowed) {
    await writeAuditLog({
      adminUserId: null,
      action: "ATTENDANCE_BLOCKED_GPS",
      targetTable: "attendances",
      beforeData: null,
      afterData: {
        userId: user.id,
        code: gpsDecision.code,
        latitude: payload.latitude,
        longitude: payload.longitude,
        accuracy: payload.accuracy,
      },
      reason: gpsDecision.message,
    });
    throw forbidden(gpsDecision.message);
  }

  if (!payload.faceDetected) {
    throw badRequest("Wajah tidak terdeteksi. Ambil ulang foto selfie.");
  }

  const timestampDecision = validateTimestamp(payload.timestamp);
  if (!timestampDecision.allowed) {
    await writeAuditLog({
      adminUserId: null,
      action: "ATTENDANCE_BLOCKED_TIME_DRIFT",
      targetTable: "attendances",
      afterData: {
        userId: user.id,
        timestamp: payload.timestamp,
        serverTimestamp: new Date().toISOString(),
      },
      reason: timestampDecision.message,
    });
    throw badRequest(timestampDecision.message);
  }

  const officeDecision = await resolveNearestOffice(user.id, payload);
  if (!officeDecision.withinRadius) {
    await notifyManagersAndAdmins({
      type: "ATTENDANCE_OUTSIDE_RADIUS",
      title: "Absensi di luar radius",
      body: `${user.name} mencoba absen ${Math.round(officeDecision.distanceM)}m dari lokasi kantor.`,
      metadata: {
        userId: user.id,
        distanceM: officeDecision.distanceM,
        officeId: officeDecision.office?.id,
      },
    });
    await writeAuditLog({
      adminUserId: null,
      action: "ATTENDANCE_BLOCKED_RADIUS",
      targetTable: "attendances",
      afterData: {
        userId: user.id,
        distanceM: officeDecision.distanceM,
        radiusMeters: officeDecision.office?.radiusMeters,
      },
      reason: "Lokasi di luar radius kantor",
    });
    throw forbidden("Lokasi berada di luar radius kantor");
  }

  const photo = await persistAttendancePhoto({
    photoBase64: payload.photoBase64,
    photoUrl: payload.photoUrl,
    photoHash: payload.photoHash,
    userId: user.id,
    sessionId: payload.sessionId,
  });

  const anomaly = buildAnomaly(payload);
  const baseStatus =
    payload.type === "MASUK"
      ? determineAttendanceStatus({ shift: user.shift, timestamp: payload.timestamp })
      : "HADIR";

  let attendance;
  try {
    attendance = await prisma.attendance.create({
      data: {
        userId: user.id,
        type: payload.type,
        timestamp: new Date(payload.timestamp),
        lat: payload.latitude,
        lng: payload.longitude,
        accuracy: payload.accuracy,
        provider: payload.provider || null,
        gpsTimestamp: payload.gpsTimestamp ? new Date(payload.gpsTimestamp) : null,
        photoUrl: photo.photoUrl,
        photoData: photo.photoData,
        photoHash: (photo.photoHash || payload.photoHash || '').toLowerCase(),
        faceScore: payload.faceMatchScore ?? null,
        faceDetected: payload.faceDetected,
        distanceM: officeDecision.distanceM,
        withinRadius: true,
        shiftId: user.shiftId,
        deviceIdEncrypted: encryptText(payload.deviceId),
        ipAddressEncrypted: encryptText(reqMeta.ipAddress),
        isMockGps: !!payload.isMockLocationDetected,
        status: anomaly.flag ? "REVIEW" : baseStatus,
        anomalyFlag: anomaly.flag,
        anomalyReason: anomaly.reason,
        notes: payload.notes || null,
        syncedAt: new Date(),
      },
    });
  } catch (error) {
    if (error.code === "P2002") {
      const existing = await prisma.attendance.findFirst({
        where: {
          userId: user.id,
          type: payload.type,
          timestamp: new Date(payload.timestamp),
        },
      });
      return {
        attendance: existing,
        duplicate: true,
        reviewRequired: true,
      };
    }
    throw error;
  }

  await createOvertimeIfNeeded({ user, attendance });
  await createNotification({
    userId: user.id,
    type: "ATTENDANCE_SUCCESS",
    title: "Absensi berhasil",
    body: `${payload.type.toLowerCase()} tercatat pukul ${dayjs(attendance.timestamp).format("HH:mm")}.`,
    metadata: { attendanceId: attendance.id },
  });

  broadcastSSE("attendance:created", {
    userId: user.id,
    userName: user.name,
    type: payload.type,
    status: attendance.status,
    timestamp: attendance.timestamp,
  });

  if (anomaly.flag) {
    await notifyManagersAndAdmins({
      type: "ATTENDANCE_ANOMALY",
      title: "Anomali absensi",
      body: `${user.name} butuh review: ${anomaly.reason}`,
      metadata: { attendanceId: attendance.id, userId: user.id },
    });
    broadcastSSE("attendance:anomaly", {
      userId: user.id,
      userName: user.name,
      attendanceId: attendance.id,
      reason: anomaly.reason,
    }, { role: "MANAJER" });
    broadcastSSE("attendance:anomaly", {
      userId: user.id,
      userName: user.name,
      attendanceId: attendance.id,
      reason: anomaly.reason,
    }, { role: "HR" });
  }

  return {
    attendance,
    duplicate: false,
    reviewRequired: anomaly.flag,
  };
}

async function syncOfflineQueue(user, entries, reqMeta = {}) {
  const results = [];

  for (const entry of entries) {
    try {
      const result = await createAttendance(user, entry, reqMeta);
      results.push({
        sessionId: entry.sessionId,
        status: result.duplicate ? "DUPLICATE_REVIEW" : "SYNCED",
        attendanceId: result.attendance.id,
      });
    } catch (error) {
      results.push({
        sessionId: entry.sessionId,
        status: "FAILED",
        code: error.code || "SYNC_FAILED",
        message: error.message,
      });
    }
  }

  return { results };
}

async function resolveNearestOffice(userId, payload) {
  const userWithOffices = await prisma.user.findUnique({
    where: { id: userId },
    include: { officeLocations: true },
  });
  if (!userWithOffices) throw notFound("User tidak ditemukan");

  let offices = userWithOffices.officeLocations.filter((office) => office.isActive);
  if (offices.length === 0) {
    offices = await prisma.officeLocation.findMany({ where: { isActive: true } });
  }
  if (offices.length === 0) throw badRequest("Lokasi kantor belum dikonfigurasi");

  const distances = offices.map((office) => ({
    office,
    distanceM: haversineDistanceMeters(
      { latitude: payload.latitude, longitude: payload.longitude },
      { latitude: office.latitude, longitude: office.longitude },
    ),
  }));

  distances.sort((a, b) => a.distanceM - b.distanceM);
  const nearest = distances[0];

  return {
    office: nearest.office,
    distanceM: nearest.distanceM,
    withinRadius: nearest.distanceM <= nearest.office.radiusMeters,
  };
}

function buildAnomaly(payload) {
  if (payload.deviceIntegrity?.verdict === "FAILED") {
    return {
      flag: true,
      reason: `Device integrity failed: ${payload.deviceIntegrity.reason || "unknown"}`,
    };
  }

  if (payload.deviceIntegrity?.isJailbrokenOrRooted) {
    return {
      flag: true,
      reason: "Device terindikasi root/jailbreak",
    };
  }

  if (payload.faceMatchScore !== undefined && payload.faceMatchScore < 0.85) {
    return {
      flag: true,
      reason: `Face match rendah (${Math.round(payload.faceMatchScore * 100)}%)`,
    };
  }

  return { flag: false, reason: null };
}

function validateTimestamp(timestamp) {
  const clientTime = new Date(timestamp).getTime();
  const now = Date.now();
  const diffMinutes = Math.abs(now - clientTime) / 60000;

  if (Number.isNaN(clientTime)) {
    return { allowed: false, message: "Timestamp absensi tidak valid" };
  }

  if (diffMinutes > 60) {
    return {
      allowed: false,
      message: "Jam perangkat berbeda lebih dari 60 menit dari server",
    };
  }

  return { allowed: true };
}

function dateKey(value) {
  return dayjs(value).format("YYYY-MM-DD");
}

async function createOvertimeIfNeeded({ user, attendance }) {
  if (attendance.type !== "PULANG") return null;
  const durationMinutes = calculateOvertimeMinutes({
    shift: user.shift,
    checkoutAt: attendance.timestamp,
  });

  if (durationMinutes <= 0) return null;

  return prisma.overtimeRecord.create({
    data: {
      attendanceId: attendance.id,
      durationMinutes,
      status: "MENUNGGU",
    },
  });
}

module.exports = {
  createAttendance,
  getHistory,
  getTodayStatus,
  syncOfflineQueue,
};
