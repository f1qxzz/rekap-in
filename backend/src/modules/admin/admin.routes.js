const express = require("express");
const validate = require("../../middleware/validate");
const { requireAuth, requireRole } = require("../../middleware/auth");
const controller = require("./admin.controller");
const {
  approveUserSchema,
  createDepartmentSchema,
  createHolidaySchema,
  createLeaveBalanceSchema,
  createOfficeSchema,
  createShiftSchema,
  createUserSchema,
  importUsersSchema,
  listLeaveBalancesSchema,
  reviewAnomalySchema,
  updateDepartmentSchema,
  updateHolidaySchema,
  updateLeaveBalanceSchema,
  updateOfficeSchema,
  updateRoleSchema,
  updateShiftSchema,
  updateUserSchema,
  uuidParam,
} = require("./admin.schema");

const router = express.Router();

router.use(requireAuth, requireRole("HR", "SUPER_ADMIN"));

router.get("/summary", controller.summary);
router.get("/users", controller.listUsers);
router.post("/users", validate(createUserSchema), controller.createUser);
router.post("/users/import", validate(importUsersSchema), controller.importUsers);
router.patch("/users/:id", validate(updateUserSchema), controller.updateUser);
router.patch("/users/:id/approve", validate(approveUserSchema), controller.approveUser);
router.patch("/users/:id/role", validate(updateRoleSchema), controller.updateRole);

router.get("/departments", controller.listDepartments);
router.post("/departments", validate(createDepartmentSchema), controller.createDepartment);
router.patch("/departments/:id", validate(updateDepartmentSchema), controller.updateDepartment);
router.delete("/departments/:id", validate(uuidParam), controller.deleteDepartment);

router.get("/shifts", controller.listShifts);
router.post("/shifts", validate(createShiftSchema), controller.createShift);
router.patch("/shifts/:id", validate(updateShiftSchema), controller.updateShift);
router.delete("/shifts/:id", validate(uuidParam), controller.deleteShift);

router.get("/offices", controller.listOffices);
router.post("/offices", validate(createOfficeSchema), controller.createOffice);
router.patch("/offices/:id", validate(updateOfficeSchema), controller.updateOffice);
router.delete("/offices/:id", validate(uuidParam), controller.deleteOffice);

router.get("/leave-balances", validate(listLeaveBalancesSchema), controller.listLeaveBalances);
router.post("/leave-balances", validate(createLeaveBalanceSchema), controller.createLeaveBalance);
router.patch("/leave-balances/:id", validate(updateLeaveBalanceSchema), controller.updateLeaveBalance);
router.delete("/leave-balances/:id", validate(uuidParam), controller.deleteLeaveBalance);

router.get("/anomalies", controller.listAnomalies);
router.patch("/anomalies/:id/review", validate(reviewAnomalySchema), controller.reviewAnomaly);

router.get("/audit-logs", controller.listAuditLogs);
router.get("/holidays", controller.listHolidays);
router.post("/holidays", validate(createHolidaySchema), controller.createHoliday);
router.patch("/holidays/:id", validate(updateHolidaySchema), controller.updateHoliday);
router.delete("/holidays/:id", validate(uuidParam), controller.deleteHoliday);

module.exports = router;
