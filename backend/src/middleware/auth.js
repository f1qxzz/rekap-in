const jwt = require("jsonwebtoken");
const env = require("../config/env");
const prisma = require("../lib/prisma");
const { forbidden, unauthorized } = require("../utils/errors");

const ROLE_HIERARCHY = {
  SUPER_ADMIN: 4,
  HR: 3,
  MANAJER: 2,
  KARYAWAN: 1,
};

function getBearerToken(req) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) return null;
  return header.slice("Bearer ".length);
}

function verifyAccessToken(token) {
  if (env.JWT_PUBLIC_KEY) {
    return jwt.verify(token, env.JWT_PUBLIC_KEY, {
      algorithms: ["RS256"],
    });
  }

  if (env.isProduction) {
    throw new Error("JWT_PUBLIC_KEY wajib di-set di production");
  }

  return jwt.verify(token, env.DEV_JWT_SECRET, {
    algorithms: ["HS256"],
  });
}

async function requireAuth(req, res, next) {
  try {
    const token = getBearerToken(req);
    if (!token) throw unauthorized();

    const payload = verifyAccessToken(token);
    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      include: { shift: true, department: true },
    });

    if (!user || !user.isActive) throw unauthorized("Akun tidak aktif atau sesi tidak valid");

    req.user = user;
    req.auth = payload;
    return next();
  } catch (error) {
    return next(error.statusCode ? error : unauthorized("Token tidak valid atau sudah expired"));
  }
}

function requireRole(...roles) {
  return function roleGuard(req, res, next) {
    if (!req.user) return next(unauthorized());
    if (!roles.includes(req.user.role)) {
      return next(forbidden("Role tidak punya akses ke endpoint ini"));
    }
    return next();
  };
}

function requireHigherRole(minRole) {
  return function hierarchyGuard(req, res, next) {
    if (!req.user) return next(unauthorized());
    const userLevel = ROLE_HIERARCHY[req.user.role] || 0;
    const requiredLevel = ROLE_HIERARCHY[minRole] || 0;
    if (userLevel < requiredLevel) {
      return next(forbidden("Tidak punya hak akses yang cukup"));
    }
    return next();
  };
}

function canModifyTarget(adminRole, targetRole) {
  if (adminRole === "SUPER_ADMIN") return true;
  const adminLevel = ROLE_HIERARCHY[adminRole] || 0;
  const targetLevel = ROLE_HIERARCHY[targetRole] || 0;
  return adminLevel > targetLevel;
}

function canAssignRole(adminRole, newRole) {
  if (adminRole === "SUPER_ADMIN") return true;
  const adminLevel = ROLE_HIERARCHY[adminRole] || 0;
  const newLevel = ROLE_HIERARCHY[newRole] || 0;
  return adminLevel > newLevel;
}

module.exports = {
  ROLE_HIERARCHY,
  requireAuth,
  requireRole,
  requireHigherRole,
  canModifyTarget,
  canAssignRole,
  verifyAccessToken,
};
