const express = require("express");
const { requireAuth } = require("../../middleware/auth");
const controller = require("./storage.controller");

const router = express.Router();

router.use(requireAuth);
router.post("/documents", controller.uploadDocument);
router.get("/photos/signed-url", controller.getSignedPhoto);
router.get("/photos/*", controller.getLocalPhoto);

module.exports = router;
