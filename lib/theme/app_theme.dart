import 'package:flutter/material.dart';

/// Foodieit design system.
///
/// Warm orange primary, light background, rounded cards, subtle shadows.
/// All colours are tuned for accessible contrast on small Android screens
/// and Flutter Web.
class FoodieitTheme {
  FoodieitTheme._();

  // ── Brand palette ──────────────────────────────────────────────
  static const Color primary = Color(0xFFFC8019);       // Swiggy-style warm orange
  static const Color primaryDark = Color(0xFFE66A00);
  static const Color primaryLight = Color(0xFFFFE6D1);
  static const Color accent = Color(0xFFFFB74D);
  static const Color surface = Colors.white;
  static const Color background = Color(0xFFFFF8F2);     // warm off-white
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);    // near-black, readable
  static const Color textSecondary = Color(0xFF6B6B80);
  static const Color textHint = Color(0xFF9E9EAE);
  static const Color divider = Color(0xFFE8E8EC);
  static const Color success = Color(0xFF2E7D32);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFF57C00);
  static const Color warningBg = Color(0xFFFFF3E0);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerBg = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF1565C0);
  static const Color infoBg = Color(0xFFE3F2FD);

  // ── Status colours ─────────────────────────────────────────────
  static Color statusBg(String label) => switch (label) {
    'Delivered' => successBg,
    'Cancelled' => dangerBg,
    'Draft'     => Color(0xFFF5F5F5),
    'Placed'    => infoBg,
    'Updated'   => infoBg,
    _           => warningBg,
  };

  static Color statusFg(String label) => switch (label) {
    'Delivered' => success,
    'Cancelled' => danger,
    'Draft'     => textSecondary,
    'Placed'    => info,
    'Updated'   => info,
    _           => warning,
  };

  // ── Radii & elevations ─────────────────────────────────────────
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x20000000), blurRadius: 20, offset: Offset(0, 6)),
  ];

  // ── ThemeData ──────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: surface,
      error: danger,
    ),
    scaffoldBackgroundColor: background,
    canvasColor: surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: textHint),
      labelStyle: const TextStyle(color: textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF5F5F5),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXs),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primaryLight,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primary, size: 24);
        }
        return const IconThemeData(color: textHint, size: 22);
      }),
    ),
    dividerTheme: const DividerThemeData(
      color: divider,
      thickness: 1,
      space: 1,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
      bodySmall: TextStyle(fontSize: 12, color: textSecondary),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      labelSmall: TextStyle(fontSize: 11, color: textSecondary),
    ),
  );
}
