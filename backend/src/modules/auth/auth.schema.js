const { z } = require("zod");

const passwordSchema = z
  .string()
  .min(8)
  .regex(/[A-Z]/, "Password wajib punya minimal 1 huruf besar")
  .regex(/[0-9]/, "Password wajib punya minimal 1 angka");

const registerSchema = z.object({
  body: z.object({
    name: z.string().min(2),
    email: z.string().email(),
    nip: z.string().min(3),
    departmentId: z.string().uuid().optional(),
    phone: z.string().min(8).optional(),
    password: passwordSchema,
  }),
});

const loginSchema = z.object({
  body: z.object({
    email: z.string().min(1),
    password: z.string().min(1),
    deviceId: z.string().optional(),
    fcmToken: z.string().optional(),
  }),
});

const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(20),
  }),
});

const verifyEmailSchema = z.object({
  body: z.object({
    token: z.string().min(20),
  }),
});

const resendVerificationSchema = z.object({
  body: z.object({
    email: z.string().email(),
  }),
});

const passwordResetRequestSchema = z.object({
  body: z.object({
    email: z.string().email(),
  }),
});

const passwordResetConfirmSchema = z.object({
  body: z.object({
    token: z.string().min(20),
    newPassword: passwordSchema,
  }),
});

const onboardingSchema = z.object({
  body: z.object({
    photoUrl: z.string().min(1).optional(),
    notificationTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  }),
});

const updateProfileSchema = z.object({
  body: z.object({
    name: z.string().min(1).optional(),
    phone: z.string().optional(),
    photoUrl: z.string().optional(),
  }).refine(
    (data) => data.name !== undefined || data.phone !== undefined || data.photoUrl !== undefined,
    { message: "Minimal satu field harus diisi" }
  ),
});

const changePasswordSchema = z.object({
  body: z.object({
    oldPassword: z.string().min(1),
    newPassword: passwordSchema,
  }),
});

module.exports = {
  changePasswordSchema,
  loginSchema,
  onboardingSchema,
  passwordResetConfirmSchema,
  passwordResetRequestSchema,
  refreshSchema,
  registerSchema,
  resendVerificationSchema,
  updateProfileSchema,
  verifyEmailSchema,
};
