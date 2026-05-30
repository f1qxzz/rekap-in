const { AppError } = require("../utils/errors");

function errorHandler(err, req, res, next) {
  if (res.headersSent) {
    return next(err);
  }

  const statusCode = err instanceof AppError ? err.statusCode : 500;

  if (statusCode === 500) {
    console.error(`[ERROR] ${req.method} ${req.originalUrl}:`, err.message);
  }

  const payload = {
    error: {
      code: err.code || "INTERNAL_ERROR",
      message: statusCode === 500 ? "Terjadi kesalahan server" : err.message,
    },
  };

  if (err.details) {
    payload.error.details = err.details;
  }

  return res.status(statusCode).json(payload);
}

module.exports = errorHandler;

