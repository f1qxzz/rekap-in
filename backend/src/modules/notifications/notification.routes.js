const express = require("express");
const { requireAuth } = require("../../middleware/auth");
const controller = require("./notification.controller");

const router = express.Router();

router.use(requireAuth);
router.get("/", controller.listMine);
router.patch("/:id/read", controller.markRead);
router.patch("/read-all", controller.markAllRead);

module.exports = router;
