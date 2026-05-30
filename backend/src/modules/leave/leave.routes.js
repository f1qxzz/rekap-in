const express = require("express");
const validate = require("../../middleware/validate");
const { requireAuth, requireRole } = require("../../middleware/auth");
const controller = require("./leave.controller");
const { approvalSchema, createLeaveSchema } = require("./leave.schema");

const router = express.Router();

router.use(requireAuth);

router.get("/mine", controller.mine);
router.get("/balance", controller.balance);
router.post("/", validate(createLeaveSchema), controller.create);
router.get("/pending", requireRole("MANAJER", "HR", "SUPER_ADMIN"), controller.pending);
router.post("/:id/manager-approval", requireRole("MANAJER", "HR", "SUPER_ADMIN"), validate(approvalSchema), controller.managerApproval);
router.post("/:id/hr-approval", requireRole("HR", "SUPER_ADMIN"), validate(approvalSchema), controller.hrApproval);

module.exports = router;

