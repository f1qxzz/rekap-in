const argon2 = require("argon2");
const prisma = require("../../lib/prisma");
const env = require("../../config/env");
const { badRequest, forbidden, unauthorized } = require("../../utils/errors");
const { randomToken, sha256 } = require("../../utils/crypto");
const { sendEmail } = require("../notifications/delivery.service");
const { createRefreshToken, signAccessToken } = require("./token.service");

const LOCKOUT_ATTEMPTS = 5;
const LOCKOUT_MINUTES = 15;

async function register(payload) {
  const existing = await prisma.user.findFirst({
    where: {
      OR: [{ email: payload.email }, { nip: payload.nip }],
    },
  });

  if (existing) {
    throw badRequest("Email atau NIP sudah terdaftar");
  }

  const verificationToken = randomToken(40);
  const user = await prisma.user.create({
    data: {
      name: payload.name,
      email: payload.email.toLowerCase(),
      nip: payload.nip,
      phone: payload.phone || null,
      departmentId: payload.departmentId || null,
      passwordHash: await argon2.hash(payload.password),
      role: "KARYAWAN",
      emailVerifyTokenHash: sha256(verificationToken),
      emailVerifyExpiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    },
    select: {
      id: true,
      name: true,
      email: true,
      nip: true,
      role: true,
      isApproved: true,
      emailVerified: true,
    },
  });

  const verificationLink = `${env.API_BASE_URL}/auth/verify-email?token=${verificationToken}`;
  await sendEmail({
    to: user.email,
    subject: "Verifikasi akun Absensi",
    text: `Klik link ini dalam 24 jam untuk aktivasi akun: ${verificationLink}`,
  }).catch((error) => {
    console.error("Verification email failed", error.message);
  });

  return {
    user,
    verification: {
      expiresInHours: 24,
      devLink: verificationLink,
      token: env.isProduction ? undefined : verificationToken,
    },
  };
}

async function verifyEmail(token) {
  const tokenHash = sha256(token);
  const user = await prisma.user.findFirst({
    where: {
      emailVerifyTokenHash: tokenHash,
      emailVerifyExpiresAt: { gt: new Date() },
    },
  });

  if (!user) {
    throw badRequest("Link verifikasi tidak valid atau sudah expired");
  }

  return prisma.user.update({
    where: { id: user.id },
    data: {
      emailVerified: true,
      emailVerifyTokenHash: null,
      emailVerifyExpiresAt: null,
    },
    select: {
      id: true,
      email: true,
      emailVerified: true,
    },
  });
}

async function resendVerification(email) {
  const user = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });
  if (!user) throw badRequest("Email tidak ditemukan");
  if (user.emailVerified) throw badRequest("Email sudah terverifikasi");

  const token = randomToken(40);
  const verificationLink = `${env.API_BASE_URL}/auth/verify-email?token=${token}`;
  await prisma.user.update({
    where: { id: user.id },
    data: {
      emailVerifyTokenHash: sha256(token),
      emailVerifyExpiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    },
  });

  await sendEmail({
    to: user.email,
    subject: "Verifikasi ulang akun Absensi",
    text: `Klik link ini dalam 24 jam untuk aktivasi akun: ${verificationLink}`,
  }).catch((error) => {
    console.error("Verification email failed", error.message);
  });

  return {
    expiresInHours: 24,
    devLink: verificationLink,
    token: env.isProduction ? undefined : token,
  };
}

async function login({ email, password, deviceId, fcmToken, userAgent, ipAddress }) {
  const identifier = email.trim().toLowerCase();
  const user = await prisma.user.findFirst({
    where: {
      OR: [
        { email: identifier },
        { nip: identifier },
      ],
    },
    include: { shift: true, department: true },
  });

  if (!user) throw unauthorized("Email atau password salah");
  if (!user.isActive) throw forbidden("Akun tidak aktif");
  if (user.lockoutUntil && user.lockoutUntil > new Date()) {
    throw forbidden("Akun terkunci 15 menit karena terlalu banyak percobaan login");
  }

  const passwordOk = await argon2.verify(user.passwordHash, password);

  if (!passwordOk) {
    await prisma.$executeRaw`
      UPDATE "users"
      SET "failedLoginAttempts" = "failedLoginAttempts" + 1,
          "lockoutUntil" = CASE
            WHEN "failedLoginAttempts" + 1 >= ${LOCKOUT_ATTEMPTS}
            THEN ${new Date(Date.now() + LOCKOUT_MINUTES * 60 * 1000)}
            ELSE NULL
          END
      WHERE id = ${user.id}
    `;

    throw unauthorized("Email atau password salah");
  }

  if (!user.emailVerified) throw forbidden("Email belum diverifikasi");
  if (!user.isApproved) throw forbidden("Akun belum di-approve admin");

  await prisma.user.update({
    where: { id: user.id },
    data: {
      failedLoginAttempts: 0,
      lockoutUntil: null,
      fcmToken: fcmToken || user.fcmToken,
    },
  });

  const refresh = createRefreshToken();
  await prisma.refreshToken.create({
    data: {
      userId: user.id,
      tokenHash: refresh.tokenHash,
      userAgent: userAgent || null,
      ipAddress: ipAddress || null,
      expiresAt: new Date(Date.now() + env.REFRESH_TOKEN_DAYS * 24 * 60 * 60 * 1000),
    },
  });

  return {
    accessToken: signAccessToken(user),
    refreshToken: refresh.token,
    tokenType: "Bearer",
    expiresIn: env.ACCESS_TOKEN_TTL,
    user: sanitizeUser(user),
    deviceId,
  };
}

async function refreshToken(rawToken) {
  const tokenHash = sha256(rawToken);
  const stored = await prisma.refreshToken.findUnique({
    where: { tokenHash },
    include: { user: { include: { shift: true, department: true } } },
  });

  if (!stored || stored.revokedAt || stored.expiresAt <= new Date()) {
    throw unauthorized("Refresh token tidak valid atau sudah expired");
  }

  return {
    accessToken: signAccessToken(stored.user),
    tokenType: "Bearer",
    expiresIn: env.ACCESS_TOKEN_TTL,
  };
}

async function logout(rawToken) {
  if (!rawToken) return { revoked: false };
  await prisma.refreshToken.updateMany({
    where: {
      tokenHash: sha256(rawToken),
      revokedAt: null,
    },
    data: {
      revokedAt: new Date(),
    },
  });
  return { revoked: true };
}

async function updateProfile(userId, payload) {
  const data = {};
  if (payload.name !== undefined) data.name = payload.name;
  if (payload.phone !== undefined) data.phone = payload.phone;
  if (payload.photoUrl !== undefined) data.photoUrl = payload.photoUrl;

  return prisma.user.update({
    where: { id: userId },
    data,
    select: {
      id: true,
      name: true,
      email: true,
      nip: true,
      phone: true,
      role: true,
      photoUrl: true,
      departmentId: true,
      shiftId: true,
    },
  });
}

async function changePassword(userId, payload) {
  const { oldPassword, newPassword } = payload;
  if (!oldPassword || !newPassword) throw badRequest("Password lama dan baru wajib diisi");
  if (newPassword.length < 8) throw badRequest("Password baru minimal 8 karakter");

  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw unauthorized("User tidak ditemukan");

  const valid = await argon2.verify(user.passwordHash, oldPassword);
  if (!valid) throw badRequest("Password lama salah");

  const samePassword = await argon2.verify(user.passwordHash, newPassword);
  if (samePassword) throw badRequest("Password baru tidak boleh sama dengan password lama");

  await prisma.user.update({
    where: { id: userId },
    data: { passwordHash: await argon2.hash(newPassword) },
  });

  return { message: "Password berhasil diganti" };
}

async function requestPasswordReset(email) {
  const user = await prisma.user.findUnique({
    where: { email: email.toLowerCase() },
  });

  const neutralResponse = {
    message: "Jika email terdaftar, instruksi reset password akan dikirim.",
  };

  if (!user || !user.isActive) return neutralResponse;

  await prisma.passwordResetToken.updateMany({
    where: { userId: user.id, usedAt: null },
    data: { usedAt: new Date() },
  });

  const token = randomToken(40);
  const resetLink = `${env.API_BASE_URL}/auth/password-reset/confirm?token=${token}`;
  await prisma.passwordResetToken.create({
    data: {
      userId: user.id,
      tokenHash: sha256(token),
      expiresAt: new Date(Date.now() + 30 * 60 * 1000),
    },
  });

  await sendEmail({
    to: user.email,
    subject: "Reset password Rekap In",
    text: `Gunakan link ini dalam 30 menit untuk reset password: ${resetLink}`,
  }).catch((error) => {
    console.error("Password reset email failed", error.message);
  });

  return {
    ...neutralResponse,
    reset: {
      expiresInMinutes: 30,
      devLink: env.isProduction ? undefined : resetLink,
      token: env.isProduction ? undefined : token,
    },
  };
}

async function confirmPasswordReset({ token, newPassword }) {
  const tokenHash = sha256(token);
  const row = await prisma.passwordResetToken.findUnique({
    where: { tokenHash },
    include: { user: true },
  });

  if (!row || row.usedAt || row.expiresAt <= new Date()) {
    throw badRequest("Token reset password tidak valid atau sudah expired");
  }
  if (!row.user.isActive) throw forbidden("Akun tidak aktif");

  await prisma.$transaction([
    prisma.user.update({
      where: { id: row.userId },
      data: {
        passwordHash: await argon2.hash(newPassword),
        failedLoginAttempts: 0,
        lockoutUntil: null,
      },
    }),
    prisma.passwordResetToken.update({
      where: { id: row.id },
      data: { usedAt: new Date() },
    }),
    prisma.refreshToken.updateMany({
      where: { userId: row.userId, revokedAt: null },
      data: { revokedAt: new Date() },
    }),
  ]);

  return { message: "Password berhasil direset. Silakan login ulang." };
}

async function updateOnboarding(userId, payload) {
  return prisma.user.update({
    where: { id: userId },
    data: {
      photoUrl: payload.photoUrl,
      notificationTime: payload.notificationTime,
    },
    select: {
      id: true,
      photoUrl: true,
      notificationTime: true,
    },
  });
}

function sanitizeUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    nip: user.nip,
    role: user.role,
    departmentId: user.departmentId,
    shiftId: user.shiftId,
    photoUrl: user.photoUrl,
  };
}

module.exports = {
  changePassword,
  confirmPasswordReset,
  login,
  logout,
  refreshToken,
  register,
  requestPasswordReset,
  resendVerification,
  updateOnboarding,
  updateProfile,
  verifyEmail,
};
