import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // Semantic
  static const Color positive = Color(0xFF22C55E);
  static const Color negative = Color(0xFFEF4444);
  static const Color warning  = Color(0xFFF59E0B);

  // Vibrant category palette (for icon chip backgrounds)
  static const List<Color> categoryColors = [
    Color(0xFFFF6B35), // Groceries
    Color(0xFFE53935), // Restaurants
    Color(0xFF6D4C41), // Coffee & Drinks
    Color(0xFF1E88E5), // Transport
    Color(0xFF8E24AA), // Entertainment
    Color(0xFFE91E63), // Shopping
    Color(0xFF00897B), // Travel
    Color(0xFF43A047), // Health & Fitness
    Color(0xFFF9A825), // Utilities & Bills
    Color(0xFF3949AB), // Subscriptions
    Color(0xFF0097A7), // Education
    Color(0xFFF06292), // Personal Care
    Color(0xFF546E7A), // Rent & Housing
    Color(0xFF2E7D32), // Investments
    Color(0xFF757575), // Other
  ];

  // ── Dark ──────────────────────────────────────────────
  static ThemeData get dark {
    const bg     = Color(0xFF0A0A0A);
    const card   = Color(0xFF161616);
    const border = Color(0xFF272727);
    const onPrimary  = Color(0xFF000000);
    const primary    = Color(0xFFFFFFFF);
    const secondary  = Color(0xFF888888);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return _build(
      brightness: Brightness.dark,
      cs: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        surface: bg,
        error: Color(0xFFEF4444),
        onSurface: primary,
        onSurfaceVariant: secondary,
        outline: border,
      ),
      scaffoldBg: bg,
      cardBg: card,
      textPrimary: primary,
      textSecondary: secondary,
    );
  }

  // ── Light ─────────────────────────────────────────────
  static ThemeData get light {
    const bg     = Color(0xFFF2F2F2);
    const card   = Color(0xFFFFFFFF);
    const border = Color(0xFFE5E5E5);
    const primary   = Color(0xFF000000);
    const secondary = Color(0xFF888888);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: card,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return _build(
      brightness: Brightness.light,
      cs: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        surface: bg,
        error: Color(0xFFEF4444),
        onSurface: primary,
        onSurfaceVariant: secondary,
        outline: border,
      ),
      scaffoldBg: bg,
      cardBg: card,
      textPrimary: primary,
      textSecondary: secondary,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme cs,
    required Color scaffoldBg,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isDark = brightness == Brightness.dark;
    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor: scaffoldBg,

      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary, size: 22),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),

      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outline, width: isDark ? 0.5 : 1),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: DividerThemeData(
        color: cs.outline,
        thickness: 0.5,
        space: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w600, letterSpacing: 0),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: cs.outline, width: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w500, letterSpacing: 0),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withAlpha(8)
            : Colors.black.withAlpha(5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textPrimary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),

      textTheme: base.textTheme.copyWith(
        displayLarge: TextStyle(
            color: textPrimary,
            fontSize: 52,
            fontWeight: FontWeight.w900,
            letterSpacing: -2),
        displayMedium: TextStyle(
            color: textPrimary,
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5),
        displaySmall: TextStyle(
            color: textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -1),
        headlineLarge: TextStyle(
            color: textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5),
        headlineMedium: TextStyle(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3),
        titleLarge: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700),
        titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600),
        titleSmall: TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w400),
        bodySmall: TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w400),
        labelLarge: TextStyle(
            color: textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0),
        labelMedium: TextStyle(
            color: textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5),
      ),
    );
  }
}
