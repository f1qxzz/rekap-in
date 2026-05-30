const asyncHandler = require("../../utils/asyncHandler");
const service = require("./payroll.service");

const summary = asyncHandler(async (req, res) => {
  const result = await service.attendanceSummary({
    month: req.query.month,
    userId: req.query.userId,
  });
  res.json(result);
});

const lockMonth = asyncHandler(async (req, res) => {
  const result = await service.lockMonthAndNotifyPayroll({
    month: req.body.month,
    lockedBy: req.user.id,
  });
  res.json(result);
});

module.exports = {
  lockMonth,
  summary,
};

