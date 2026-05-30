const asyncHandler = require("../../utils/asyncHandler");
const service = require("./notification.service");

const listMine = asyncHandler(async (req, res) => {
  res.json({ data: await service.listMine(req.user.id) });
});

const markRead = asyncHandler(async (req, res) => {
  res.json(await service.markRead(req.user.id, req.params.id));
});

const markAllRead = asyncHandler(async (req, res) => {
  res.json(await service.markAllRead(req.user.id));
});

module.exports = {
  listMine,
  markAllRead,
  markRead,
};
