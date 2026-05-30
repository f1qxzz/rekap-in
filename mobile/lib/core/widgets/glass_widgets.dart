import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/app_theme.dart';

class AmbientScaffoldBackground extends StatelessWidget {
  const AmbientScaffoldBackground({
    required this.child,
    this.primaryGlow = AppTheme.primary,
    this.secondaryGlow = AppTheme.info,
    super.key,
  });

  final Widget child;
  final Color primaryGlow;
  final Color secondaryGlow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: AppTheme.canvasGradientFor(context),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _GlowBand(color: primaryGlow, height: 180, alpha: 0.11),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _GlowBand(
            color: secondaryGlow,
            height: 160,
            alpha: 0.07,
            invert: true,
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowBand extends StatelessWidget {
  const _GlowBand({
    required this.color,
    required this.height,
    required this.alpha,
    this.invert = false,
  });

  final Color color;
  final double height;
  final double alpha;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: invert
                ? [Colors.transparent, color.withValues(alpha: alpha)]
                : [color.withValues(alpha: alpha), Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    this.padding,
    this.margin,
    this.radius = 20,
    this.blur = 16,
    this.border = AppTheme.glassBorder,
    this.background = AppTheme.glassSurface,
    this.showShadow = false,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double blur;
  final Color border;
  final Color background;
  final bool showShadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return margin != null
        ? Padding(padding: margin!, child: _build(context))
        : _build(context);
  }

  Widget _build(BuildContext context) {
    final effectiveBorder = border == AppTheme.glassBorder
        ? AppTheme.glassBorderFor(context)
        : border;
    final effectiveBackground = background == AppTheme.glassSurface
        ? AppTheme.glassSurfaceFor(context)
        : background;
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveBackground,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: effectiveBorder, width: 1),
            boxShadow: showShadow ? [AppTheme.glassShadowFor(context)] : null,
          ),
          child: child,
        ),
      ),
    );
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }
    return content;
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.radius = 20,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding,
      margin: margin,
      radius: radius,
      onTap: onTap,
      showShadow: true,
      child: child,
    );
  }
}

class GlassCardHeader extends StatelessWidget {
  const GlassCardHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor = AppTheme.primary,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: AppTheme.mutedFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.gradient = AppTheme.primaryGradient,
    this.height = 58,
    this.shadowColor,
    super.key,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Gradient gradient;
  final double height;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: disabled
                  ? AppTheme.lineLightFor(context)
                  : AppTheme.buttonSurfaceFor(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: disabled
                    ? AppTheme.lineFor(context)
                    : AppTheme.buttonBorderFor(context),
              ),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: (shadowColor ?? AppTheme.primary)
                            .withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: height * 0.35),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppTheme.primaryDark, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0,
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

class GlassInputField extends StatelessWidget {
  const GlassInputField({
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.maxLines = 1,
    this.style,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final int maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      maxLines: maxLines,
      style: style ??
          TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.inkFor(context),
          ),
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.danger.withValues(alpha: 0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.danger, width: 1.5),
        ),
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: AppTheme.mutedFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.text,
    required this.color,
    this.compact = false,
    super.key,
  });

  final String text;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 10 : 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class PremiumInsightCard extends StatelessWidget {
  const PremiumInsightCard({
    required this.icon,
    required this.title,
    required this.description,
    this.accentColor = AppTheme.primary,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      radius: 20,
      border: accentColor.withValues(alpha: 0.16),
      background: accentColor.withValues(alpha: 0.045),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.24),
                  accentColor.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: accentColor.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mutedFor(context),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class PremiumStatTile extends StatelessWidget {
  const PremiumStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.caption,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.premiumCardDecorationFor(
        context,
        accent: color,
        radius: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: value.length > 12 ? 14 : 16,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.inkFor(context),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.mutedFor(context),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProcessStepper extends StatelessWidget {
  const ProcessStepper({
    required this.steps,
    required this.activeIndex,
    this.activeColor = AppTheme.primary,
    super.key,
  });

  final List<String> steps;
  final int activeIndex;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 7,
                  decoration: BoxDecoration(
                    color: i <= activeIndex
                        ? activeColor
                        : AppTheme.lineFor(context).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  steps[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: i <= activeIndex
                        ? activeColor
                        : AppTheme.mutedFor(context),
                    fontSize: 10,
                    fontWeight:
                        i <= activeIndex ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (i < steps.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.message,
    this.description,
    this.actionLabel,
    this.onAction,
    this.highlights = const [],
    this.accentColor = AppTheme.primary,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<String> highlights;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.18),
                    accentColor.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accentColor.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, size: 40, color: accentColor),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.inkFor(context),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.mutedFor(context),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
            if (highlights.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceFor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.lineFor(context).withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < highlights.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: accentColor,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              highlights[i],
                              style: TextStyle(
                                color: AppTheme.mutedFor(context),
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({
    this.width,
    this.height = 16,
    this.radius = 8,
    this.margin,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Shimmer.fromColors(
        baseColor: AppTheme.primarySurfaceFor(context),
        highlightColor: AppTheme.surfaceFor(context),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.glassSurfaceFor(context),
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
