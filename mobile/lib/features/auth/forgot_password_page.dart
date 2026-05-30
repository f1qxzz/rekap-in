import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/glass_widgets.dart';
import 'auth_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _requestKey = GlobalKey<FormState>();
  final _confirmKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  bool _requesting = false;
  bool _saving = false;
  bool _showPassword = false;
  String? _notice;
  AuthNoticeTone _noticeTone = AuthNoticeTone.info;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (_requesting || !_requestKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _requesting = true;
      _notice = null;
    });

    try {
      final result = await widget.apiClient.requestPasswordReset(_email.text);
      final reset = result['reset'];
      if (reset is Map && reset['token'] is String) {
        _token.text = reset['token'] as String;
      }
      if (!mounted) return;
      setState(() {
        _noticeTone = AuthNoticeTone.info;
        _notice = result['message'] as String? ??
            'Jika akun terdaftar, instruksi reset password akan dikirim.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _noticeTone = AuthNoticeTone.error;
        _notice = ApiClient.errorMessage(
          error,
          fallback: 'Gagal meminta reset password. Periksa server atau email.',
        );
      });
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _confirmReset() async {
    if (_saving || !_confirmKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _notice = null;
    });

    try {
      await widget.apiClient.confirmPasswordReset(
        token: _token.text,
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      setState(() {
        _noticeTone = AuthNoticeTone.success;
        _notice = 'Password berhasil direset. Silakan login ulang.';
        _newPassword.clear();
        _confirmPassword.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _noticeTone = AuthNoticeTone.error;
        _notice = ApiClient.errorMessage(
          error,
          fallback: 'Reset password gagal. Token mungkin sudah kadaluarsa.',
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateNewPassword(String? value) {
    final text = value ?? '';
    if (text.length < 8) return 'Minimal 8 karakter';
    if (!RegExp(r'[A-Z]').hasMatch(text)) {
      return 'Password wajib punya huruf besar';
    }
    if (!RegExp(r'[0-9]').hasMatch(text)) {
      return 'Password wajib punya angka';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final busy = _requesting || _saving;
    return AuthFrame(
      title: 'Reset Password',
      subtitle: 'Minta token reset lalu buat password baru untuk akun kamu.',
      leading: Align(
        alignment: Alignment.centerLeft,
        child: IconButton.filledTonal(
          tooltip: 'Kembali',
          onPressed: busy ? null : () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded),
        ),
      ),
      footer: AuthSwitchLink(
        text: 'Sudah ingat password?',
        actionText: 'Login',
        onPressed: busy ? null : () => Navigator.of(context).maybePop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _requestKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassInputField(
                  controller: _email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  labelText: 'Email Akun',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Email wajib diisi';
                    if (!text.contains('@')) return 'Format email belum valid';
                    return null;
                  },
                  onFieldSubmitted: (_) => _requestReset(),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: busy ? null : _requestReset,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.buttonSurfaceFor(context),
                    foregroundColor: AppTheme.primaryDark,
                    side: BorderSide(color: AppTheme.buttonBorderFor(context)),
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: _requesting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.send_rounded, size: 20),
                  label: Text(_requesting ? 'Mengirim...' : 'Kirim Token'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Form(
            key: _confirmKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassInputField(
                  controller: _token,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  labelText: 'Token Reset',
                  prefixIcon: Icon(Icons.key_rounded, size: 20),
                  validator: (value) => (value?.trim().length ?? 0) < 20
                      ? 'Token reset belum valid'
                      : null,
                ),
                const SizedBox(height: 14),
                AuthPasswordField(
                  controller: _newPassword,
                  focusNode: _newPasswordFocus,
                  enabled: !busy,
                  visible: _showPassword,
                  label: 'Password Baru',
                  textInputAction: TextInputAction.next,
                  onToggleVisible: () =>
                      setState(() => _showPassword = !_showPassword),
                  validator: _validateNewPassword,
                ),
                const SizedBox(height: 14),
                AuthPasswordField(
                  controller: _confirmPassword,
                  focusNode: _confirmPasswordFocus,
                  enabled: !busy,
                  visible: _showPassword,
                  label: 'Konfirmasi Password',
                  textInputAction: TextInputAction.done,
                  onToggleVisible: () =>
                      setState(() => _showPassword = !_showPassword),
                  validator: (value) => value != _newPassword.text
                      ? 'Konfirmasi password tidak sama'
                      : null,
                  onFieldSubmitted: (_) => _confirmReset(),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: busy ? null : _confirmReset,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.lock_reset_rounded, size: 20),
                  label: Text(_saving ? 'Menyimpan...' : 'Reset Password'),
                ),
              ],
            ),
          ),
          if (_notice != null) ...[
            const SizedBox(height: 16),
            AuthNotice(text: _notice!, tone: _noticeTone),
          ],
        ],
      ),
    );
  }
}
