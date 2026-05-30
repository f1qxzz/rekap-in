const asyncHandler = require("../../utils/asyncHandler");
const service = require("./report.service");

const analytics = asyncHandler(async (req, res) => {
  res.json(await service.analytics({ month: req.query.month }));
});

const exportReport = asyncHandler(async (req, res) => {
  const format = req.query.format || "csv";
  const month = req.query.month;
  const rows = await service.monthlyAttendanceRows(req.query);

  if (format === "xlsx") {
    const buffer = await service.toWorkbook(rows);
    res.setHeader("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    res.setHeader("Content-Disposition", `attachment; filename=absensi-${month}.xlsx`);
    return res.send(Buffer.from(buffer));
  }

  if (format === "pdf") {
    const buffer = await service.toPdf(rows, month);
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", `attachment; filename=absensi-${month}.pdf`);
    return res.send(buffer);
  }

  res.setHeader("Content-Type", "text/csv; charset=utf-8");
  res.setHeader("Content-Disposition", `attachment; filename=absensi-${month}.csv`);
  return res.send(service.toCsv(rows));
});

module.exports = {
  analytics,
  exportReport,
};

