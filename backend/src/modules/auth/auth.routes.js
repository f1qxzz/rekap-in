const express = require("express");
const validate = require("../../middleware/validate");
const { requireAuth } = require("../../middleware/auth");
const controller = require("./auth.controller");
const {
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
} = require("./auth.schema");

const router = express.Router();

router.post("/register", validate(registerSchema), controller.register);
router.post("/verify-email", validate(verifyEmailSchema), controller.verifyEmail);
router.get("/verify-email", controller.verifyEmail);
router.post("/resend-verification", validate(resendVerificationSchema), controller.resendVerification);
router.post("/password-reset/request", validate(passwordResetRequestSchema), controller.requestPasswordReset);
router.post("/password-reset/confirm", validate(passwordResetConfirmSchema), controller.confirmPasswordReset);
router.post("/login", validate(loginSchema), controller.login);
router.post("/refresh", validate(refreshSchema), controller.refresh);
router.post("/logout", controller.logout);
router.get("/me", requireAuth, controller.me);
router.patch("/me", requireAuth, validate(updateProfileSchema), controller.updateProfile);
router.post("/change-password", requireAuth, validate(changePasswordSchema), controller.changePassword);
router.patch("/onboarding", requireAuth, validate(onboardingSchema), controller.onboarding);

module.exports = router;
