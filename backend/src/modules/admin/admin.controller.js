const asyncHandler = require("../../utils/asyncHandler");
const service = require("./admin.service");

const listUsers = asyncHandler(async (req, res) => {
  const result = await service.listUsers(req.query);
  res.json(result);
});

const summary = asyncHandler(async (req, res) => {
  res.json({ data: await service.summary() });
});

const createUser = asyncHandler(async (req, res) => {
  res.status(201).json(await service.createUser(req.user, req.validated.body));
});

const updateUser = asyncHandler(async (req, res) => {
  res.json(await service.updateUser(req.user, req.validated.params.id, req.validated.body));
});

const approveUser = asyncHandler(async (req, res) => {
  res.json(await service.approveUser(req.user, req.validated.params.id, req.validated.body));
});

const updateRole = asyncHandler(async (req, res) => {
  res.json(await service.updateRole(req.user, req.validated.params.id, req.validated.body));
});

const importUsers = asyncHandler(async (req, res) => {
  res.json(await service.importUsers(req.user, req.validated.body.users));
});

const listShifts = asyncHandler(async (req, res) => {
  res.json({ data: await service.listShifts() });
});

const createShift = asyncHandler(async (req, res) => {
  res.status(201).json(await service.createShift(req.user, req.validated.body));
});

const updateShift = asyncHandler(async (req, res) => {
  res.json(await service.updateShift(req.user, req.validated.params.id, req.validated.body));
});

const deleteShift = asyncHandler(async (req, res) => {
  res.json(await service.deleteShift(req.user, req.validated.params.id));
});

const listOffices = asyncHandler(async (req, res) => {
  res.json({ data: await service.listOffices() });
});

const createOffice = asyncHandler(async (req, res) => {
  res.status(201).json(await service.createOffice(req.user, req.validated.body));
});

const updateOffice = asyncHandler(async (req, res) => {
  res.json(await service.updateOffice(req.user, req.validated.params.id, req.validated.body));
});

const deleteOffice = asyncHandler(async (req, res) => {
  res.json(await service.deleteOffice(req.user, req.validated.params.id));
});

const listLeaveBalances = asyncHandler(async (req, res) => {
  res.json({ data: await service.listLeaveBalances(req.validated.query) });
});

const createLeaveBalance = asyncHandler(async (req, res) => {
  res.status(201).json(await service.createLeaveBalance(req.user, req.validated.body));
});

const updateLeaveBalance = asyncHandler(async (req, res) => {
  res.json(await service.updateLeaveBalance(req.user, req.validated.params.id, req.validated.body));
});

const deleteLeaveBalance = asyncHandler(async (req, res) => {
  res.json(await service.deleteLeaveBalance(req.user, req.validated.params.id));
});

const listAnomalies = asyncHandler(async (req, res) => {
  res.json({ data: await service.listAnomalies() });
});

const reviewAnomaly = asyncHandler(async (req, res) => {
  res.json(await service.reviewAnomaly(req.user, req.validated.params.id, req.validated.body));
});

const listAuditLogs = asyncHandler(async (req, res) => {
  const result = await service.listAuditLogs(req.query);
  res.json(result);
});

const listDepartments = asyncHandler(async (req, res) => {
  res.json({ data: await service.listDepartments() });
});

const createDepartment = asyncHandler(async (req, res) => {
  res.status(201).json(await service.createDepartment(req.user, req.validated.body));
});

const updateDepartment = asyncHandler(async (req, res) => {
  res.json(await service.updateDepartment(req.user, req.validated.params.id, req.validated.body));
});

const deleteDepartment = asyncHandler(async (req, res) => {
  res.json(await service.deleteDepartment(req.user, req.validated.params.id));
});

const createHoliday = asyncHandler(async (req, res) => {
  res.status(201).json(await service.createHoliday(req.user, req.validated.body));
});

const listHolidays = asyncHandler(async (req, res) => {
  res.json({ data: await service.listHolidays() });
});

const updateHoliday = asyncHandler(async (req, res) => {
  res.json(await service.updateHoliday(req.user, req.validated.params.id, req.validated.body));
});

const deleteHoliday = asyncHandler(async (req, res) => {
  res.json(await service.deleteHoliday(req.user, req.validated.params.id));
});

module.exports = {
  approveUser,
  createDepartment,
  createHoliday,
  createLeaveBalance,
  createOffice,
  createShift,
  createUser,
  deleteDepartment,
  deleteHoliday,
  deleteLeaveBalance,
  deleteOffice,
  deleteShift,
  importUsers,
  listAnomalies,
  listAuditLogs,
  listDepartments,
  listHolidays,
  listLeaveBalances,
  listOffices,
  listShifts,
  listUsers,
  reviewAnomaly,
  summary,
  updateDepartment,
  updateHoliday,
  updateLeaveBalance,
  updateOffice,
  updateRole,
  updateShift,
  updateUser,
};
