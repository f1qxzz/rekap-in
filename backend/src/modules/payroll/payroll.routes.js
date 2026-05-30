const express = require("express");
const { requireAuth, requireRole } = require("../../middleware/auth");
const controller = require("./payroll.controller");

const router = express.Router();

router.use(requireAuth);
router.get("/attendance/summary", requireRole("HR", "SUPER_ADMIN", "MANAJER"), controller.summary);
router.post("/payroll/lock-month", requireRole("HR", "SUPER_ADMIN"), controller.lockMonth);

module.exports = router;

