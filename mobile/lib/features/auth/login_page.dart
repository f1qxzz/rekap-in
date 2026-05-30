import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/biometric_service.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/storage/token_store.dart';
import '../../core/widgets/glass_widgets.dart';
import '../dashboard/dashboard_page.dart';
import '../settings/api_settings_page.dart';
import 'auth_widgets.dart';
import 'forgot_password_page.dart';
import 'onboarding_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.apiClient,
    required this.tokenStore,
    required this.offlineQueue,
    super.key,
  });

  final ApiClient apiClient;
  final TokenStore tokenStore;
  final OfflineQueue offlineQueue;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _showPassword = false;
  bool _biometricAvailable = false;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
    _checkBiometric();
  }

  @override
  void dispose() {
    _animController.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final hasSession = await widget.tokenStore.hasRefreshToken();
    if (mounted && available && hasSession) {
      setState(() => _biometricAvailable = true);
    }
  }

  Future<void> _biometricLogin() async {
    if (_loading || !mounted) return;
    setState(() => _loading = true);
    try {
      final ok = await BiometricService.authenticate(
        reason: 'Verifikasi untuk masuk ke Rekap In',
      );
      if (!ok || !mounted) return;
      _navigateToDashboard();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => DashboardPage(
          apiClient: widget.apiClient,
          tokenStore: widget.tokenStore,
          offlineQueue: widget.offlineQueue,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _openRegister() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => RegisterPage(
          apiClient: widget.apiClient,
          tokenStore: widget.tokenStore,
          offlineQueue: widget.offlineQueue,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.15, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => ForgotPasswordPage(
          apiClient: widget.apiClient,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.15, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _openApiSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApiSettingsPage(
          apiClient: widget.apiClient,
          tokenStore: widget.tokenStore,
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_loading || !mounted) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.apiClient.login(
        _email.text.trim(),
        _password.text,
        fcmToken: await PushNotificationService.token(),
      );
      if (!mounted) return;
      final seenOnboarding = await widget.tokenStore.hasSeenOnboarding();
      if (!mounted) return;
      if (seenOnboarding) {
        _navigateToDashboard();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnboardingPage(
              apiClient: widget.apiClient,
              tokenStore: widget.tokenStore,
              offlineQueue: widget.offlineQueue,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ApiClient.errorMessage(
          error,
          fallback: 'Login gagal. Periksa email, password, atau approval akun.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Selamat Datang',
      subtitle: 'Masuk untuk melanjutkan presensi hari ini.',
      footer: AuthSwitchLink(
        text: 'Belum punya akun?',
        actionText: 'Daftar',
        onPressed: _loading ? null : _openRegister,
      ),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassInputField(
                  controller: _email,
                  focusNode: _emailFocus,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  labelText: 'Email atau NIP',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                  autofillHints: const [AutofillHints.username],
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Email atau NIP wajib diisi';
                    return null;
                  },
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  enabled: !_loading,
                  visible: _showPassword,
                  label: 'Password',
                  textInputAction: TextInputAction.done,
                  onToggleVisible: () =>
                      setState(() => _showPassword = !_showPassword),
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Password wajib diisi';
                    return null;
                  },
                  onFieldSubmitted: (_) => _login(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _loading ? null : _openForgotPassword,
                    icon: Icon(Icons.lock_reset_rounded, size: 18),
                    label: const Text('Lupa Password'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  AuthNotice(text: _error!, tone: AuthNoticeTone.error),
                ],
                const SizedBox(height: 28),
                Semantics(
                  label: 'Tombol masuk ke aplikasi',
                  button: true,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.buttonSurfaceFor(context),
                      foregroundColor: AppTheme.primaryDark,
                      side:
                          BorderSide(color: AppTheme.buttonBorderFor(context)),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryDark,
                            ),
                          )
                        : Icon(Icons.login_rounded, size: 20),
                    label: Text(_loading ? 'Memeriksa...' : 'Masuk'),
                  ),
                ),
                if (_biometricAvailable) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _biometricLogin,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: AppTheme.lineFor(context)),
                      foregroundColor: AppTheme.inkFor(context),
                    ),
                    icon: Icon(Icons.fingerprint_rounded, size: 22),
                    label: const Text('Masuk dengan Biometrik'),
                  ),
                ],
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: _loading ? null : _openApiSettings,
                  icon: Icon(Icons.dns_outlined, size: 18),
                  label: const Text('Atur Server'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
