const asyncHandler = require("../../utils/asyncHandler");
const authService = require("./auth.service");

const register = asyncHandler(async (req, res) => {
  const result = await authService.register(req.validated.body);
  res.status(201).json(result);
});

const verifyEmail = asyncHandler(async (req, res) => {
  const token = req.validated?.body?.token || req.query.token;
  const result = await authService.verifyEmail(token);
  res.json(result);
});

const resendVerification = asyncHandler(async (req, res) => {
  const result = await authService.resendVerification(req.validated.body.email);
  res.json(result);
});

const login = asyncHandler(async (req, res) => {
  const result = await authService.login({
    ...req.validated.body,
    userAgent: req.headers["user-agent"],
    ipAddress: req.ip,
  });
  res.json(result);
});

const refresh = asyncHandler(async (req, res) => {
  const result = await authService.refreshToken(req.validated.body.refreshToken);
  res.json(result);
});

const logout = asyncHandler(async (req, res) => {
  const result = await authService.logout(req.body.refreshToken);
  res.json(result);
});

const me = asyncHandler(async (req, res) => {
  res.json({ user: req.user });
});

const updateProfile = asyncHandler(async (req, res) => {
  const result = await authService.updateProfile(req.user.id, req.validated.body);
  res.json({ user: result });
});

const changePassword = asyncHandler(async (req, res) => {
  const result = await authService.changePassword(req.user.id, req.validated.body);
  res.json(result);
});

const requestPasswordReset = asyncHandler(async (req, res) => {
  const result = await authService.requestPasswordReset(req.validated.body.email);
  res.json(result);
});

const confirmPasswordReset = asyncHandler(async (req, res) => {
  const result = await authService.confirmPasswordReset(req.validated.body);
  res.json(result);
});

const onboarding = asyncHandler(async (req, res) => {
  const result = await authService.updateOnboarding(req.user.id, req.validated.body);
  res.json(result);
});

module.exports = {
  changePassword,
  confirmPasswordReset,
  login,
  logout,
  me,
  onboarding,
  refresh,
  register,
  requestPasswordReset,
  resendVerification,
  updateProfile,
  verifyEmail,
};
