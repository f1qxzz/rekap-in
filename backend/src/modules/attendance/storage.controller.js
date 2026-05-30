const asyncHandler = require("../../utils/asyncHandler");
const { persistDocument, readLocalPhoto, signedPhotoUrl } = require("./storage.service");

const getSignedPhoto = asyncHandler(async (req, res) => {
  const url = await signedPhotoUrl(req.query.photoUrl);
  res.json({ url });
});

const getLocalPhoto = asyncHandler(async (req, res) => {
  const key = req.params[0];
  const bytes = await readLocalPhoto(key);
  res.setHeader("Content-Type", "image/jpeg");
  res.setHeader("Cache-Control", "private, max-age=300");
  res.send(bytes);
});

const uploadDocument = asyncHandler(async (req, res) => {
  const result = await persistDocument({
    fileBase64: req.body.fileBase64,
    fileName: req.body.fileName,
    mimeType: req.body.mimeType,
    userId: req.user.id,
  });
  res.status(201).json(result);
});

module.exports = {
  getLocalPhoto,
  getSignedPhoto,
  uploadDocument,
};
