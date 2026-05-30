import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/storage/token_store.dart';
import '../../core/widgets/glass_widgets.dart';
import 'auth_widgets.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    required this.apiClient,
    required this.tokenStore,
    required this.offlineQueue,
    this.onThemeChanged,
    super.key,
  });

  final ApiClient apiClient;
  final TokenStore tokenStore;
  final OfflineQueue offlineQueue;
  final ValueChanged<ThemeMode>? onThemeChanged;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nip = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _nameFocus = FocusNode();
  final _nipFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _name.dispose();
    _nip.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _nameFocus.dispose();
    _nipFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_loading || !mounted) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      await widget.apiClient.register(
        name: _name.text.trim(),
        nip: _nip.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      setState(() {
        _success =
            'Pendaftaran berhasil dikirim. Verifikasi email lalu tunggu approval admin.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ApiClient.errorMessage(
          error,
          fallback:
              'Pendaftaran gagal. Email atau NIP mungkin sudah terdaftar.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          apiClient: widget.apiClient,
          tokenStore: widget.tokenStore,
          offlineQueue: widget.offlineQueue,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      leading: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.glassSurfaceFor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: IconButton(
            tooltip: 'Kembali',
            onPressed: _loading ? null : _openLogin,
            icon: Icon(Icons.arrow_back_rounded),
          ),
        ),
      ),
      title: 'Buat Akun Baru',
      subtitle: 'Gunakan data karyawan yang sama dengan data HR.',
      footer: AuthSwitchLink(
        text: 'Sudah punya akun?',
        actionText: 'Masuk',
        onPressed: _loading ? null : _openLogin,
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassInputField(
              controller: _name,
              focusNode: _nameFocus,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              labelText: 'Nama lengkap',
              prefixIcon: Icon(Icons.person_outline_rounded),
              autofillHints: const [AutofillHints.name],
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 2) return 'Nama minimal 2 karakter';
                return null;
              },
              onFieldSubmitted: (_) => _nipFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            GlassInputField(
              controller: _nip,
              focusNode: _nipFocus,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              labelText: 'NIP',
              prefixIcon: Icon(Icons.badge_outlined),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 3) return 'NIP minimal 3 karakter';
                return null;
              },
              onFieldSubmitted: (_) => _emailFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            GlassInputField(
              controller: _email,
              focusNode: _emailFocus,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              labelText: 'Email kerja',
              prefixIcon: Icon(Icons.mail_outline_rounded),
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Email wajib diisi';
                if (!text.contains('@')) return 'Format email belum benar';
                return null;
              },
              onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            GlassInputField(
              controller: _phone,
              focusNode: _phoneFocus,
              enabled: !_loading,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              labelText: 'Nomor HP (opsional)',
              prefixIcon: Icon(Icons.phone_outlined),
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isNotEmpty && text.length < 8) {
                  return 'Nomor HP minimal 8 digit';
                }
                return null;
              },
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            AuthPasswordField(
              controller: _password,
              focusNode: _passwordFocus,
              enabled: !_loading,
              visible: _showPassword,
              label: 'Password',
              textInputAction: TextInputAction.next,
              onToggleVisible: () =>
                  setState(() => _showPassword = !_showPassword),
              validator: (value) {
                final text = value ?? '';
                if (text.length < 8) return 'Password minimal 8 karakter';
                if (!RegExp(r'[A-Z]').hasMatch(text)) {
                  return 'Password wajib punya huruf besar';
                }
                if (!RegExp(r'[0-9]').hasMatch(text)) {
                  return 'Password wajib punya angka';
                }
                return null;
              },
              onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            AuthPasswordField(
              controller: _confirmPassword,
              focusNode: _confirmPasswordFocus,
              enabled: !_loading,
              visible: _showConfirmPassword,
              label: 'Ulangi password',
              textInputAction: TextInputAction.done,
              onToggleVisible: () => setState(
                () => _showConfirmPassword = !_showConfirmPassword,
              ),
              validator: (value) {
                if ((value ?? '') != _password.text) {
                  return 'Konfirmasi password tidak sama';
                }
                return null;
              },
              onFieldSubmitted: (_) => _register(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AuthNotice(text: _error!, tone: AuthNoticeTone.error),
            ],
            if (_success != null) ...[
              const SizedBox(height: 16),
              AuthNotice(text: _success!, tone: AuthNoticeTone.success),
            ],
            const SizedBox(height: 24),
            Semantics(
              label: 'Tombol daftar akun baru',
              button: true,
              child: FilledButton.icon(
                onPressed: _loading ? null : _register,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.buttonSurfaceFor(context),
                  foregroundColor: AppTheme.primaryDark,
                  side: BorderSide(color: AppTheme.buttonBorderFor(context)),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryDark,
                        ),
                      )
                    : Icon(Icons.person_add_rounded),
                label: Text(_loading ? 'Mengirim...' : 'Daftar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
