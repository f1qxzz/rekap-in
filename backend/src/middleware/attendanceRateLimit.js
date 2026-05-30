const env = require("../config/env");
const { AppError } = require("../utils/errors");

const buckets = new Map();

function attendanceRateLimit(req, res, next) {
  const userId = req.user?.id || req.ip;
  const now = Date.now();
  const windowMs = 60 * 1000;
  const current = buckets.get(userId) || { count: 0, resetAt: now + windowMs };

  if (current.resetAt <= now) {
    current.count = 0;
    current.resetAt = now + windowMs;
  }

  current.count += 1;
  buckets.set(userId, current);

  res.setHeader("X-RateLimit-Limit", env.ATTENDANCE_RATE_LIMIT_PER_MINUTE);
  res.setHeader("X-RateLimit-Remaining", Math.max(0, env.ATTENDANCE_RATE_LIMIT_PER_MINUTE - current.count));

  if (current.count > env.ATTENDANCE_RATE_LIMIT_PER_MINUTE) {
    return next(new AppError("Terlalu banyak request absensi. Coba lagi sebentar.", 429, "RATE_LIMITED"));
  }

  return next();
}

module.exports = attendanceRateLimit;

