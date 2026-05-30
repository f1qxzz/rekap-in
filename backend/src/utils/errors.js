class AppError extends Error {
  constructor(message, statusCode = 500, code = "APP_ERROR", details = undefined) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}

function notFound(message = "Data tidak ditemukan") {
  return new AppError(message, 404, "NOT_FOUND");
}

function forbidden(message = "Akses ditolak") {
  return new AppError(message, 403, "FORBIDDEN");
}

function badRequest(message, details) {
  return new AppError(message, 400, "BAD_REQUEST", details);
}

function unauthorized(message = "Sesi tidak valid") {
  return new AppError(message, 401, "UNAUTHORIZED");
}

module.exports = {
  AppError,
  badRequest,
  forbidden,
  notFound,
  unauthorized,
};

