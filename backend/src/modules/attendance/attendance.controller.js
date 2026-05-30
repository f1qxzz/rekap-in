const asyncHandler = require("../../utils/asyncHandler");
const service = require("./attendance.service");
const prisma = require("../../lib/prisma");

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

module.exports = {
  clock,
  history,
  listOffices,
  syncOffline,
  todayStatus,
};

