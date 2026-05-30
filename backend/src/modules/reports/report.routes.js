const express = require("express");
const { requireAuth, requireRole } = require("../../middleware/auth");
const controller = require("./report.controller");

const router = express.Router();

router.use(requireAuth, requireRole("MANAJER", "HR", "SUPER_ADMIN"));

router.get("/analytics", controller.analytics);
router.get("/export", controller.exportReport);

module.exports = router;

