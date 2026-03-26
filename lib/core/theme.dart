import 'package:flutter/material.dart';

ThemeData buildRaceTimerTheme() {
  const background = Color(0xFF07111A);
  const surface = Color(0xFF0E1A24);
  const surfaceAlt = Color(0xFF162635);
  const primary = Color(0xFF4FA3FF);
  const secondary = Color(0xFF53D1C8);
  const outline = Color(0xFF2B465B);

  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: Colors.white,
    secondary: secondary,
    onSecondary: Colors.white,
    error: Color(0xFFFF6B6B),
    onError: Colors.black,
    surface: surface,
    onSurface: Color(0xFFF1F7FC),
    onSurfaceVariant: Color(0xFFB7C8D7),
    outline: outline,
    outlineVariant: Color(0xFF203344),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFEAF4FB),
    onInverseSurface: Color(0xFF10202F),
    inversePrimary: Color(0xFF0069C7),
    surfaceTint: primary,
    primaryContainer: surfaceAlt,
    onPrimaryContainer: Color(0xFFF1F7FC),
    secondaryContainer: Color(0xFF10303A),
    onSecondaryContainer: Color(0xFFDBFFFB),
    tertiaryContainer: Color(0xFF173043),
    onTertiaryContainer: Color(0xFFE7F5FF),
    errorContainer: Color(0xFF40171D),
    onErrorContainer: Color(0xFFFFD9DE),
  );

  final textTheme = Typography.material2021().white.copyWith(
    displaySmall: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
    headlineLarge: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
    headlineMedium: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
    headlineSmall: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
    titleLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
    titleMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    bodyLarge: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
    bodyMedium: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
    labelLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: background,
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
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
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: textTheme.labelLarge,
        side: BorderSide(color: colorScheme.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: textTheme.titleMedium,
        foregroundColor: colorScheme.onSurface,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.headlineMedium,
      centerTitle: false,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      textStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: colorScheme.primary),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
  );
}
