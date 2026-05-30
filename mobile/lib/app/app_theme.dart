import 'package:flutter/material.dart';

class AppTheme {
  static const brandName = 'Rekap In';

  static const _orchid = Color(0xFFA855F7);
  static const _orchidDeep = Color(0xFF7E22CE);
  static const _orchidSoft = Color(0xFFE9D5FF);
  static const _magenta = Color(0xFFC026D3);
  static const _mauve = Color(0xFFB56AD4);
  static const _plum = Color(0xFF6B3A75);
  static const _graphite = Color(0xFF272130);
  static const _darkCanvas = Color(0xFF131018);
  static const _darkCanvasSoft = Color(0xFF18121F);
  static const _darkSurface = Color(0xE61F1829);
  static const _darkSurfaceSolid = Color(0xFF221A2C);
  static const _darkGlassSurface = Color(0xB3261C32);
  static const _darkLine = Color(0x4DD9B4FF);
  static const _darkLineLight = Color(0x26D9B4FF);
  static const _darkInk = Color(0xFFF6EEFF);
  static const _darkMuted = Color(0xFFC8B8D5);
  static const _darkMutedLight = Color(0xFF9B8CAA);

  static const _green = Color(0xFF22C55E);
  static const _greenSurface = Color(0x1F22C55E);

  static const canvasSoft = Color(0xFFFFF9FE);
  static const canvas = canvasSoft;
  static const canvasGradientStart = Color(0xFFFFFBFF);
  static const canvasGradientEnd = Color(0xFFF8F0FF);

  static const glassWhite = Color(0xAAFFFFFF);
  static const glassBorder = Color(0x44A855F7);
  static const glassBorderStrong = Color(0x66A855F7);
  static const glassSurface = Color(0xBFFFFFFF);

  static const primary = _orchid;
  static const primaryDark = _orchidDeep;
  static const primaryLight = _orchidSoft;
  static const primarySurface = Color(0x1FA855F7);
  static const buttonSurface = Color(0x18A855F7);
  static const buttonBorder = Color(0x55A855F7);

  static const ink = _graphite;
  static const inkSolid = _graphite;
  static const inkLight = Color(0xFFFFFFFF);
  static const muted = Color(0xFF5F5368);
  static const mutedLight = Color(0xFF7C7085);
  static const surface = Color(0xCCFFFFFF);
  static const line = Color(0x26A855F7);
  static const lineLight = Color(0x1AA855F7);

  static const success = _green;
  static const successSurface = _greenSurface;
  static const warning = _mauve;
  static const warningSurface = Color(0x1FB56AD4);
  static const danger = _magenta;
  static const dangerSurface = Color(0x1FC026D3);
  static const info = _plum;
  static const infoSurface = Color(0x1F6B3A75);

  static const fieldSpacing = 16.0;
  static const radiusS = 12.0;
  static const radiusM = 18.0;
  static const radiusL = 24.0;

  static const primaryGradient = LinearGradient(
    colors: [_orchid, Color(0xFFC084FC), _magenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const infoGradient = LinearGradient(
    colors: [_plum, Color(0xFFB78AC8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const warningGradient = LinearGradient(
    colors: [_mauve, Color(0xFFEBD5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const dangerGradient = LinearGradient(
    colors: [_magenta, Color(0xFFF5D0FE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFFFFFBFF), Color(0xFFF4E7FF), Color(0xFFFFEEF9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const plumGradient = LinearGradient(
    colors: [_orchidDeep, _plum],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const orchidGlowGradient = LinearGradient(
    colors: [Color(0x00A855F7), Color(0x26C026D3)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const canvasGradient = LinearGradient(
    colors: [canvasGradientStart, canvasGradientEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const successGradient = LinearGradient(
    colors: [_green, Color(0xFFBBF7D0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color canvasFor(BuildContext context) =>
      isDark(context) ? _darkCanvas : canvas;

  static Color canvasSoftFor(BuildContext context) =>
      isDark(context) ? _darkCanvasSoft : canvasSoft;

  static Color surfaceFor(BuildContext context) =>
      isDark(context) ? _darkSurface : surface;

  static Color surfaceSolidFor(BuildContext context) =>
      isDark(context) ? _darkSurfaceSolid : const Color(0xFFFFFBFF);

  static Color glassSurfaceFor(BuildContext context) =>
      isDark(context) ? _darkGlassSurface : glassSurface;

  static Color glassBorderFor(BuildContext context) =>
      isDark(context) ? _darkLine : glassBorder;

  static Color inkFor(BuildContext context) => isDark(context) ? _darkInk : ink;

  static Color mutedFor(BuildContext context) =>
      isDark(context) ? _darkMuted : muted;

  static Color mutedLightFor(BuildContext context) =>
      isDark(context) ? _darkMutedLight : mutedLight;

  static Color lineFor(BuildContext context) =>
      isDark(context) ? _darkLine : line;

  static Color lineLightFor(BuildContext context) =>
      isDark(context) ? _darkLineLight : lineLight;

  static Color primarySurfaceFor(BuildContext context) =>
      isDark(context) ? const Color(0x33A855F7) : primarySurface;

  static Color buttonSurfaceFor(BuildContext context) =>
      isDark(context) ? const Color(0x30A855F7) : buttonSurface;

  static Color buttonBorderFor(BuildContext context) =>
      isDark(context) ? const Color(0x80C084FC) : buttonBorder;

  static Color successSurfaceFor(BuildContext context) =>
      isDark(context) ? const Color(0x3322C55E) : successSurface;

  static Color warningSurfaceFor(BuildContext context) =>
      isDark(context) ? const Color(0x33B56AD4) : warningSurface;

  static Color dangerSurfaceFor(BuildContext context) =>
      isDark(context) ? const Color(0x33C026D3) : dangerSurface;

  static Color infoSurfaceFor(BuildContext context) =>
      isDark(context) ? const Color(0x336B3A75) : infoSurface;

  static LinearGradient canvasGradientFor(BuildContext context) =>
      isDark(context)
          ? const LinearGradient(
              colors: [_darkCanvas, _darkCanvasSoft],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
          : canvasGradient;

  static LinearGradient heroGradientFor(BuildContext context) => isDark(context)
      ? const LinearGradient(
          colors: [
            Color(0xFF21162C),
            Color(0xFF17111F),
            Color(0xFF2A1730),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : heroGradient;

  static BoxShadow glassShadowFor(BuildContext context) => BoxShadow(
        color: isDark(context)
            ? Colors.black.withValues(alpha: 0.30)
            : _orchid.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 8),
      );

  static BoxDecoration premiumCardDecorationFor(
    BuildContext context, {
    Color accent = primary,
    double radius = 22,
  }) =>
      BoxDecoration(
        color: surfaceFor(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
        boxShadow: isDark(context)
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : premiumShadow(accent),
      );

  static BoxDecoration get glassDecoration => BoxDecoration(
        color: glassSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder, width: 1),
      );

  static BoxDecoration glassDecorationCustom({
    double radius = 20,
    Color border = glassBorder,
    Color background = glassSurface,
  }) =>
      BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
      );

  static BoxShadow get glassShadow => BoxShadow(
        color: _orchid.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 8),
      );

  static List<BoxShadow> premiumShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.12),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static BoxDecoration premiumCardDecoration({
    Color accent = primary,
    double radius = 22,
  }) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        boxShadow: premiumShadow(accent),
      );

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: primary,
      onPrimary: ink,
      secondary: danger,
      onSecondary: ink,
      tertiary: warning,
      onTertiary: ink,
      surface: surface,
      onSurface: ink,
      error: danger,
      onError: ink,
      outline: line,
      surfaceContainerHighest: Color(0xFFF4ECFA),
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        iconTheme: const IconThemeData(color: ink, size: 22),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: const Color(0xEFFFFFFF),
        indicatorColor: primarySurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: primary.withValues(alpha: 0.08),
        elevation: 8,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primaryDark : muted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryDark : muted,
            size: selected ? 24 : 22,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xBFFFFFFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: danger.withValues(alpha: 0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: muted,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        hintStyle: const TextStyle(
          color: mutedLight,
          fontWeight: FontWeight.w400,
        ),
        prefixIconColor: muted,
        suffixIconColor: muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: buttonSurface,
          foregroundColor: primaryDark,
          side: const BorderSide(color: buttonBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0,
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: Colors.white.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: line),
          foregroundColor: ink,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDark,
          backgroundColor: Colors.transparent,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryDark,
        circularTrackColor: primarySurface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFFFFBFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: glassBorder),
        ),
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFFFFBFF),
        contentTextStyle: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: glassBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFFFFFBFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: glassBorderStrong,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryDark;
          return mutedLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primarySurface;
          return line;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primarySurface,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: ink,
            displayColor: ink,
          )
          .copyWith(
            headlineLarge: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              fontSize: 28,
              color: ink,
            ),
            headlineMedium: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              fontSize: 24,
              color: ink,
            ),
            headlineSmall: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              fontSize: 20,
              color: ink,
            ),
            titleLarge: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              fontSize: 18,
              color: ink,
            ),
            titleMedium: const TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              fontSize: 16,
              color: ink,
            ),
            titleSmall: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: ink,
            ),
            bodyLarge: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 16,
              height: 1.5,
              color: ink,
            ),
            bodyMedium: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.45,
              color: ink,
            ),
            bodySmall: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.4,
              color: muted,
            ),
            labelLarge: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0,
              color: ink,
            ),
            labelMedium: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              letterSpacing: 0,
              color: muted,
            ),
            labelSmall: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
              letterSpacing: 0,
              color: muted,
            ),
          ),
    );
  }

  static ThemeData dark() {
    const darkInk = Color(0xFFF0EAF5);
    const darkMuted = Color(0xFF9D93A8);
    const darkSurface = Color(0xFF1E1A24);
    const darkCanvas = Color(0xFF131018);
    const darkLine = Color(0xFF3D3548);

    const scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: darkInk,
      secondary: danger,
      onSecondary: darkInk,
      tertiary: warning,
      onTertiary: darkInk,
      surface: darkSurface,
      onSurface: darkInk,
      error: danger,
      onError: darkInk,
      outline: darkLine,
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkCanvas,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      scaffoldBackgroundColor: darkCanvas,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: darkInk,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        iconTheme: const IconThemeData(color: darkInk, size: 22),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: const Color(0xE61E1A24),
        indicatorColor: primarySurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primary : darkMuted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primary : darkMuted,
            size: selected ? 24 : 22,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkLine, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x33FFFFFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: danger.withValues(alpha: 0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        labelStyle: const TextStyle(
            color: darkMuted, fontWeight: FontWeight.w500, fontSize: 14),
        hintStyle:
            const TextStyle(color: darkMuted, fontWeight: FontWeight.w400),
        prefixIconColor: darkMuted,
        suffixIconColor: darkMuted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: darkLine),
          foregroundColor: darkInk,
          textStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: 0),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          backgroundColor: Colors.transparent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: Color(0x33A855F7),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: darkLine),
        ),
        titleTextStyle: const TextStyle(
          color: darkInk,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        contentTextStyle: const TextStyle(
          color: darkInk,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkSurface,
        contentTextStyle: const TextStyle(
            color: darkInk, fontWeight: FontWeight.w500, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkLine),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: darkLine,
      ),
      dividerTheme:
          const DividerThemeData(color: darkLine, thickness: 1, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return darkMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0x33A855F7);
          }
          return darkLine;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: const Color(0x33A855F7),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: darkInk,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkLine),
        ),
      ),
      textTheme: base.textTheme
          .apply(bodyColor: darkInk, displayColor: darkInk)
          .copyWith(
            headlineLarge: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                fontSize: 28,
                color: darkInk),
            headlineMedium: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                fontSize: 24,
                color: darkInk),
            headlineSmall: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                fontSize: 20,
                color: darkInk),
            titleLarge: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                fontSize: 18,
                color: darkInk),
            titleMedium: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                fontSize: 16,
                color: darkInk),
            titleSmall: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: darkInk),
            bodyLarge: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 16,
                height: 1.5,
                color: darkInk),
            bodyMedium: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.45,
                color: darkInk),
            bodySmall: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 12,
                height: 1.4,
                color: darkMuted),
            labelLarge: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0,
                color: darkInk),
            labelMedium: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0,
                color: darkMuted),
            labelSmall: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                letterSpacing: 0,
                color: darkMuted),
          ),
    );
  }
}
