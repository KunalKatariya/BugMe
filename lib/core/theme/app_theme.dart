import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Semantic ──────────────────────────────────────────────────────
  static const Color positive = Color(0xFF10B981); // emerald green
  static const Color negative = Color(0xFFF43F5E); // rose red
  static const Color warning  = Color(0xFFF59E0B); // amber

  // ── Category palette (vibrant, 15 unique hues) ────────────────────
  static const List<Color> categoryColors = [
    Color(0xFFFF6B35), // Groceries
    Color(0xFFE53935), // Restaurants
    Color(0xFF8D6E63), // Coffee & Drinks
    Color(0xFF42A5F5), // Transport
    Color(0xFFAB47BC), // Entertainment
    Color(0xFFEC407A), // Shopping
    Color(0xFF26A69A), // Travel
    Color(0xFF66BB6A), // Health & Fitness
    Color(0xFFFFA726), // Utilities & Bills
    Color(0xFF5C6BC0), // Subscriptions
    Color(0xFF26C6DA), // Education
    Color(0xFFEF9A9A), // Personal Care
    Color(0xFF78909C), // Rent & Housing
    Color(0xFF43A047), // Investments
    Color(0xFF9E9E9E), // Other
  ];

  // ── Dark ──────────────────────────────────────────────────────────
  static ThemeData get dark {
    // Pure matte black — no blue/purple tint.
    const bg      = Color(0xFF0A0A0A);
    const card    = Color(0xFF141414);
    const border  = Color(0xFF242424);
    const primary    = Colors.white;   // text + interactive
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
        onPrimary: Colors.black,
        secondary: Colors.white70,
        onSecondary: Colors.black,
        surface: bg,
        error: Color(0xFFF43F5E),
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

  // ── Light ─────────────────────────────────────────────────────────
  static ThemeData get light {
    const bg      = Color(0xFFF5F5F5);
    const card    = Color(0xFFFFFFFF);
    const border  = Color(0xFFE8E8E8);
    const primary    = Color(0xFF0A0A0A); // near-black text
    const secondary  = Color(0xFF6B7280); // neutral gray

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
        secondary: Colors.black54,
        onSecondary: Colors.white,
        surface: bg,
        error: Color(0xFFF43F5E),
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
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.outline, width: isDark ? 0.5 : 1),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: DividerThemeData(
        color: cs.outline,
        thickness: 0.5,
        space: 0,
      ),

      // ── Buttons ────────────────────────────────────────────────────
      // Black bg + white text (light) | White bg + black text (dark).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimary,          // white in dark, black in light
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, letterSpacing: 0, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: textPrimary.withAlpha(100), width: 1.5),
          backgroundColor: textPrimary.withAlpha(isDark ? 15 : 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w600, letterSpacing: 0, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        ),
      ),

      // ── Inputs ─────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withAlpha(6)
            : Colors.black.withAlpha(4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: textPrimary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
        floatingLabelStyle: TextStyle(color: textPrimary, fontSize: 13),
      ),

      // ── Typography ─────────────────────────────────────────────────
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: TextStyle(
            color: textPrimary, fontSize: 52,
            fontWeight: FontWeight.w900, letterSpacing: -2.5),
        displayMedium: TextStyle(
            color: textPrimary, fontSize: 40,
            fontWeight: FontWeight.w800, letterSpacing: -2),
        displaySmall: TextStyle(
            color: textPrimary, fontSize: 32,
            fontWeight: FontWeight.w800, letterSpacing: -1.5),
        headlineLarge: TextStyle(
            color: textPrimary, fontSize: 26,
            fontWeight: FontWeight.w800, letterSpacing: -0.8),
        headlineMedium: TextStyle(
            color: textPrimary, fontSize: 22,
            fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: TextStyle(
            color: textPrimary, fontSize: 18,
            fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleMedium: TextStyle(
            color: textPrimary, fontSize: 16,
            fontWeight: FontWeight.w600),
        titleSmall: TextStyle(
            color: textPrimary, fontSize: 14,
            fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(
            color: textPrimary, fontSize: 16,
            fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium: TextStyle(
            color: textPrimary, fontSize: 14,
            fontWeight: FontWeight.w400, height: 1.5),
        bodySmall: TextStyle(
            color: textSecondary, fontSize: 12,
            fontWeight: FontWeight.w400, height: 1.5),
        labelLarge: TextStyle(
            color: textSecondary, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 1.1),
        labelMedium: TextStyle(
            color: textSecondary, fontSize: 10,
            fontWeight: FontWeight.w600, letterSpacing: 0.6),
        labelSmall: TextStyle(
            color: textSecondary, fontSize: 9,
            fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    );
  }
}
