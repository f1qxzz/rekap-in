const jwt = require("jsonwebtoken");
const env = require("../../config/env");
const { randomToken, sha256 } = require("../../utils/crypto");

function buildAccessPayload(user) {
  return {
    userId: user.id,
    role: user.role,
    shift: user.shiftId || null,
    departemen: user.departmentId || null,
  };
}

function signAccessToken(user) {
  const payload = buildAccessPayload(user);

  if (env.JWT_PRIVATE_KEY) {
    return jwt.sign(payload, env.JWT_PRIVATE_KEY, {
      algorithm: "RS256",
      expiresIn: env.ACCESS_TOKEN_TTL,
    });
  }

  if (env.isProduction) {
    throw new Error("JWT_PRIVATE_KEY wajib di-set di production");
  }

  return jwt.sign(payload, env.DEV_JWT_SECRET, {
    algorithm: "HS256",
    expiresIn: env.ACCESS_TOKEN_TTL,
  });
}

function createRefreshToken() {
  const token = randomToken(48);
  return {
    token,
    tokenHash: sha256(token),
  };
}

module.exports = {
  createRefreshToken,
  signAccessToken,
};

