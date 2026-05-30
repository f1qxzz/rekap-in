const express = require("express");
const validate = require("../../middleware/validate");
const { requireAuth } = require("../../middleware/auth");
const attendanceRateLimit = require("../../middleware/attendanceRateLimit");
const controller = require("./attendance.controller");
const { clockSchema, historySchema, offlineSyncSchema } = require("./attendance.schema");

const router = express.Router();

router.use(requireAuth);

router.get("/today", controller.todayStatus);
router.get("/history", validate(historySchema), controller.history);
router.get("/offices", controller.listOffices);
router.post("/clock", attendanceRateLimit, validate(clockSchema), controller.clock);
router.post("/offline-sync", attendanceRateLimit, validate(offlineSyncSchema), controller.syncOffline);

module.exports = router;

