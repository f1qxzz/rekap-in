const asyncHandler = require("../../utils/asyncHandler");
const service = require("./attendance.service");
const prisma = require("../../lib/prisma");
const fs = require("node:fs/promises");
const path = require("node:path");
const env = require("../../config/env");

const todayStatus = asyncHandler(async (req, res) => {
  const result = await service.getTodayStatus(req.user.id);
  res.json(result);
});

const history = asyncHandler(async (req, res) => {
  const result = await service.getHistory(req.user.id, req.validated.query);
  res.json({ data: result });
});

const listOffices = asyncHandler(async (req, res) => {
  const offices = await prisma.officeLocation.findMany({
    where: { isActive: true },
    orderBy: { name: "asc" },
  });
  res.json({ data: offices });
});

const clock = asyncHandler(async (req, res) => {
  const result = await service.createAttendance(req.user, req.validated.body, {
    ipAddress: req.ip,
  });
  res.status(result.duplicate ? 200 : 201).json(result);
});

const syncOffline = asyncHandler(async (req, res) => {
  const result = await service.syncOfflineQueue(req.user, req.validated.body.entries, {
    ipAddress: req.ip,
  });
  res.json(result);
});

const attendancePhoto = asyncHandler(async (req, res) => {
  const attendance = await prisma.attendance.findUnique({
    where: { id: req.params.id },
    select: { photoData: true, photoUrl: true },
  });
  if (!attendance) {
    return res.status(404).json({ error: { message: "Foto tidak ditemukan" } });
  }

  if (attendance.photoData) {
    const buffer = Buffer.from(attendance.photoData, "base64");
    res.setHeader("Content-Type", "image/jpeg");
    res.setHeader("Cache-Control", "private, max-age=3600");
    return res.send(buffer);
  }

  if (attendance.photoUrl && attendance.photoUrl.startsWith("local://")) {
    const key = attendance.photoUrl.replace("local://", "");
    const filePath = path.resolve(env.LOCAL_STORAGE_DIR, key);
    try {
      const bytes = await fs.readFile(filePath);
      const base64 = bytes.toString("base64");
      await prisma.attendance.update({
        where: { id: req.params.id },
        data: { photoData: base64 },
      });
      res.setHeader("Content-Type", "image/jpeg");
      res.setHeader("Cache-Control", "private, max-age=3600");
      return res.send(bytes);
    } catch (_) {
      return res.status(404).json({ error: { message: "Foto tidak ditemukan" } });
    }
  }

  return res.status(404).json({ error: { message: "Foto tidak tersedia" } });
});

module.exports = {
  attendancePhoto,
  clock,
  history,
  listOffices,
  syncOffline,
  todayStatus,
};

