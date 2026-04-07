import 'package:flutter/material.dart';

ThemeData buildRoxburyRacesLightTheme() {
  return _buildRoxburyRacesTheme(
    const _RoxburyThemePalette(
      brightness: Brightness.light,
      background: Color(0xFFF5EFE2),
      surface: Color(0xFFFFFBF4),
      surfaceAlt: Color(0xFFE7EFF6),
      primary: Color(0xFF0F5D8C),
      onPrimary: Colors.white,
      secondary: Color(0xFF1F7A71),
      onSecondary: Colors.white,
      tertiary: Color(0xFFE0A23C),
      onTertiary: Color(0xFF3B2500),
      error: Color(0xFFB53A3A),
      onError: Colors.white,
      onSurface: Color(0xFF13212C),
      onSurfaceVariant: Color(0xFF49606F),
      outline: Color(0xFF91A3B4),
      outlineVariant: Color(0xFFC8D2DB),
      shadow: Color(0x330E2230),
      inverseSurface: Color(0xFF183243),
      onInverseSurface: Color(0xFFF7FBFE),
      inversePrimary: Color(0xFF8CCBFF),
      primaryContainer: Color(0xFFD9EBF8),
      onPrimaryContainer: Color(0xFF113651),
      secondaryContainer: Color(0xFFD7EEE8),
      onSecondaryContainer: Color(0xFF123A35),
      tertiaryContainer: Color(0xFFF8E7BF),
      onTertiaryContainer: Color(0xFF4A3106),
      errorContainer: Color(0xFFF9DEDE),
      onErrorContainer: Color(0xFF551818),
      heading: Color(0xFF113651),
    ),
  );
}

ThemeData buildRoxburyRacesDarkTheme() {
  return _buildRoxburyRacesTheme(
    const _RoxburyThemePalette(
      brightness: Brightness.dark,
      background: Color(0xFF181C14),
      surface: Color(0xFF3C3D37),
      surfaceAlt: Color(0xFF30322C),
      primary: Color(0xFFECDFCC),
      onPrimary: Color(0xFF181C14),
      secondary: Color(0xFF697565),
      onSecondary: Color(0xFFECDFCC),
      tertiary: Color(0xFF697565),
      onTertiary: Color(0xFFECDFCC),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      onSurface: Color(0xFFECDFCC),
      onSurfaceVariant: Color(0xFFD2C4B1),
      outline: Color(0xFF697565),
      outlineVariant: Color(0xFF4B5247),
      shadow: Color(0x99000000),
      inverseSurface: Color(0xFFECDFCC),
      onInverseSurface: Color(0xFF181C14),
      inversePrimary: Color(0xFF3C3D37),
      primaryContainer: Color(0xFF697565),
      onPrimaryContainer: Color(0xFFECDFCC),
      secondaryContainer: Color(0xFF3C3D37),
      onSecondaryContainer: Color(0xFFECDFCC),
      tertiaryContainer: Color(0xFF4B5247),
      onTertiaryContainer: Color(0xFFECDFCC),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      heading: Color(0xFFECDFCC),
    ),
  );
}

ThemeData _buildRoxburyRacesTheme(_RoxburyThemePalette palette) {
  final colorScheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.secondary,
    onSecondary: palette.onSecondary,
    error: palette.error,
    onError: palette.onError,
    surface: palette.surface,
    onSurface: palette.onSurface,
    onSurfaceVariant: palette.onSurfaceVariant,
    outline: palette.outline,
    outlineVariant: palette.outlineVariant,
    shadow: palette.shadow,
    scrim: Colors.black,
    inverseSurface: palette.inverseSurface,
    onInverseSurface: palette.onInverseSurface,
    inversePrimary: palette.inversePrimary,
    surfaceTint: palette.primary,
    primaryContainer: palette.primaryContainer,
    onPrimaryContainer: palette.onPrimaryContainer,
    secondaryContainer: palette.secondaryContainer,
    onSecondaryContainer: palette.onSecondaryContainer,
    tertiary: palette.tertiary,
    onTertiary: palette.onTertiary,
    tertiaryContainer: palette.tertiaryContainer,
    onTertiaryContainer: palette.onTertiaryContainer,
    errorContainer: palette.errorContainer,
    onErrorContainer: palette.onErrorContainer,
  );

  final baseTextTheme = switch (palette.brightness) {
    Brightness.light => Typography.material2021().black,
    Brightness.dark => Typography.material2021().white,
  };

  final textTheme = baseTextTheme.copyWith(
    displaySmall: TextStyle(
      fontSize: 50,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      color: palette.heading,
    ),
    headlineLarge: TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: palette.heading,
    ),
    headlineMedium: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: palette.heading,
    ),
    headlineSmall: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      color: palette.heading,
    ),
    titleLarge: TextStyle(
      fontSize: 27,
      fontWeight: FontWeight.w700,
      color: palette.heading,
    ),
    titleMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: palette.heading,
    ),
    bodyLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: colorScheme.onSurface,
    ),
    bodyMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.35,
      color: colorScheme.onSurface,
    ),
    labelLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(26),
    borderSide: BorderSide(color: colorScheme.outline),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: palette.background,
    cardTheme: CardThemeData(
      elevation: 0,
      color: palette.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1.4),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceAlt,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide(color: colorScheme.primary, width: 2.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      labelStyle: textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      hintStyle: textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      helperStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        ),
        textStyle: WidgetStatePropertyAll(
          textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimaryContainer;
          }
          return colorScheme.onSurface;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surface;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1.4,
          );
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(74),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: textTheme.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(70),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: textTheme.labelLarge,
        side: BorderSide(color: colorScheme.outline, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: textTheme.labelLarge,
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: textTheme.titleMedium,
        foregroundColor: colorScheme.onSurface,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: colorScheme.onSurface,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 92,
      titleSpacing: 20,
      titleTextStyle: textTheme.headlineMedium,
      centerTitle: false,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      textStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
    ),
    listTileTheme: ListTileThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
      iconColor: colorScheme.primary,
      textColor: colorScheme.onSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _RoxburyThemePalette {
  const _RoxburyThemePalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.tertiary,
    required this.onTertiary,
    required this.error,
    required this.onError,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.shadow,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.heading,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color tertiary;
  final Color onTertiary;
  final Color error;
  final Color onError;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color shadow;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inversePrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color heading;
}
