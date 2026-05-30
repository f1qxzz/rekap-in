import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/widgets/rekapin_logo.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
    this.leading,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientScaffoldBackground(
        child: SafeArea(
          child: AutofillGroup(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                if (leading != null) leading!,
                const _BrandPanel(),
                const SizedBox(height: 16),
                const _AuthFeatureStrip(),
                const SizedBox(height: 32),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: AppTheme.inkFor(context),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.mutedFor(context),
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 28),
                        child,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: footer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthNotice extends StatelessWidget {
  const AuthNotice({
    required this.text,
    required this.tone,
    super.key,
  });

  final String text;
  final AuthNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final config = switch (tone) {
      AuthNoticeTone.error => (
          AppTheme.danger,
          AppTheme.dangerSurfaceFor(context),
          Icons.error_outline_rounded,
        ),
      AuthNoticeTone.success => (
          AppTheme.success,
          AppTheme.successSurfaceFor(context),
          Icons.check_circle_outline_rounded,
        ),
      AuthNoticeTone.info => (
          AppTheme.info,
          AppTheme.infoSurfaceFor(context),
          Icons.info_outline_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: config.$2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.$1.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: config.$1.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(config.$3, color: config.$1, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tone == AuthNoticeTone.error
                        ? AppTheme.danger
                        : AppTheme.inkFor(context),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPasswordField extends StatelessWidget {
  const AuthPasswordField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.visible,
    required this.onToggleVisible,
    required this.textInputAction,
    required this.label,
    this.onFieldSubmitted,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool visible;
  final VoidCallback onToggleVisible;
  final TextInputAction textInputAction;
  final String label;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: !visible,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.password],
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppTheme.inkFor(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.mutedFor(context),
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          tooltip: visible ? 'Sembunyikan password' : 'Tampilkan password',
          onPressed: enabled ? onToggleVisible : null,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: AppTheme.surfaceFor(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.lineFor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.lineFor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    required this.text,
    required this.actionText,
    required this.onPressed,
    super.key,
  });

  final String text;
  final String actionText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.glassSurfaceFor(context),
        border: Border.all(color: AppTheme.glassBorderFor(context)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mutedFor(context),
                  fontWeight: FontWeight.w500,
                ),
          ),
          TextButton(
            onPressed: onPressed,
            child: Text(
              actionText,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.isDark(context)
                    ? AppTheme.primary
                    : AppTheme.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum AuthNoticeTone { error, success, info }

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.2),
                    AppTheme.primary.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const RekapInLogo(size: 60, showText: false),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTheme.brandName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppTheme.inkFor(context),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Presensi kerja yang tertata.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthFeatureStrip extends StatelessWidget {
  const _AuthFeatureStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.gps_fixed_rounded, 'GPS'),
      (Icons.photo_camera_rounded, 'Selfie'),
      (Icons.sync_rounded, 'Offline'),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceFor(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.lineFor(context).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].$1, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          items[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.mutedFor(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
