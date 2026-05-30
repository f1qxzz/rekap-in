const express = require("express");
const authRoutes = require("./modules/auth/auth.routes");
const attendanceRoutes = require("./modules/attendance/attendance.routes");
const storageRoutes = require("./modules/attendance/storage.routes");
const leaveRoutes = require("./modules/leave/leave.routes");
const adminRoutes = require("./modules/admin/admin.routes");
const payrollRoutes = require("./modules/payroll/payroll.routes");
const reportRoutes = require("./modules/reports/report.routes");
const notificationRoutes = require("./modules/notifications/notification.routes");

const router = express.Router();

router.use("/auth", authRoutes);
router.use("/attendance", attendanceRoutes);
router.use("/storage", storageRoutes);
router.use("/leave-requests", leaveRoutes);
router.use("/admin", adminRoutes);
router.use("/", payrollRoutes);
router.use("/reports", reportRoutes);
router.use("/notifications", notificationRoutes);

module.exports = router;
