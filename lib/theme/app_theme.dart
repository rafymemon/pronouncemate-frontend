import 'package:flutter/material.dart';

class AppColors {
  // ── Core Palette (from Figma) ────────────────────────────────
  static const Color background = Color(0xFFCFEBEE); // light cyan bg
  static const Color backgroundAlt = Color(0xFFB8DEE3); // slightly deeper cyan
  static const Color screenBackground = Color(0xFFF8FAFC);
  static const Color sessionBackground = Color(0xFFD6E9EB);
  static const Color surface = Color(0xFFFFFFFF); // white cards
  static const Color surfaceVariant = Color(0xFFEBF7F9); // very light cyan fill
  static const Color softBorder = Color(0xFFE2E8F0);

  // Olive / yellow-green — buttons & accents (from Figma)
  static const Color primary = Color(0xFF8A9A2C); // olive green button
  static const Color primaryDark = Color(0xFF6B7820); // darker olive hover
  static const Color primaryLight = Color(0xFFB5C44A); // lighter olive
  static const Color brandOlive = Color(0xFF6B7C2A);
  static const Color brandBlue = Color(0xFF1A3A6B);

  // Supporting tones
  static const Color accent = Color(0xFF4AABBA); // teal accent
  static const Color accentLight = Color(0xFF7ECAD5);

  // Text
  static const Color textPrimary = Color(0xFF1A2A2A); // near black
  static const Color textSecondary = Color(0xFF4A6568); // muted teal-gray
  static const Color textHint = Color(0xFF8AABAE); // soft hint
  static const Color textSlate = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textFaint = Color(0xFFCBD5E1);

  // Status
  static const Color success = Color(0xFF2E7D52);
  static const Color successLight = Color(0xFFE8F5EE);
  static const Color error = Color(0xFFB23A3A);
  static const Color errorLight = Color(0xFFFDEAEA);
  static const Color warning = Color(0xFFD4820A);
  static const Color warningLight = Color(0xFFFFF3E0);

  // Misc
  static const Color divider = Color(0xFFB8D8DC);
  static const Color cardShadow = Color(0x228AABAE);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'sans-serif',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        background: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // AppBar — transparent over the cyan bg
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // Primary buttons — olive pill shape (matches Figma)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // pill shape
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Inputs — white with light cyan border
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textHint),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 4,
        shadowColor: AppColors.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
    );
  }
}
