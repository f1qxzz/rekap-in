const asyncHandler = require("../../utils/asyncHandler");
const service = require("./leave.service");

const mine = asyncHandler(async (req, res) => {
  res.json({ data: await service.listMine(req.user.id) });
});

const balance = asyncHandler(async (req, res) => {
  res.json(await service.getBalance(req.user.id));
});

const create = asyncHandler(async (req, res) => {
  res.status(201).json(await service.createLeaveRequest(req.user, req.validated.body));
});

const pending = asyncHandler(async (req, res) => {
  res.json({ data: await service.listPending(req.user) });
});

const managerApproval = asyncHandler(async (req, res) => {
  res.json(await service.managerApproval(req.user, req.validated.params.id, req.validated.body));
});

const hrApproval = asyncHandler(async (req, res) => {
  res.json(await service.hrApproval(req.user, req.validated.params.id, req.validated.body));
});

module.exports = {
  balance,
  create,
  hrApproval,
  managerApproval,
  mine,
  pending,
};

