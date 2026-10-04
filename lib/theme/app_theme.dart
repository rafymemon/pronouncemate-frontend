import 'package:flutter/material.dart';

class AppColors {
  // ============================================================
  // MAIN APP PALETTE
  // ============================================================

  // Backgrounds
  static const Color background = Color(0xFFCFEBEE);
  static const Color backgroundAlt = Color(0xFFB8DEE3);
  static const Color screenBackground = Color(0xFFCFEBEE);
  static const Color sessionBackground = Color(0xFFD6E9EB);

  // Cards / surfaces
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEBF7F9);
  static const Color softBorder = Color(0xFFB8D8DC);

  // ============================================================
  // PRIMARY — OLIVE GREEN
  // Buttons, selected navigation, links, important actions
  // ============================================================

  static const Color primary = Color(0xFF8A9A2C);
  static const Color primaryDark = Color(0xFF6B7820);
  static const Color primaryLight = Color(0xFFB5C44A);

  static const Color brandOlive = Color(0xFF6B7C2A);

  // Keep this for screens/widgets that already use it
  static const Color brandBlue = Color(0xFF1A3A6B);

  // ============================================================
  // SECONDARY / ACCENT — TEAL
  // Icons, input focus, decorations, secondary UI
  // ============================================================

  static const Color accent = Color(0xFF4AABBA);
  static const Color accentLight = Color(0xFF7ECAD5);

  static const Color skyBlue = accent;

  // ============================================================
  // TEXT
  // ============================================================

  static const Color textPrimary = Color(0xFF1A2A2A);
  static const Color textSecondary = Color(0xFF4A6568);
  static const Color textHint = Color(0xFF8AABAE);

  static const Color textSlate = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textFaint = Color(0xFFCBD5E1);

  // ============================================================
  // STATUS COLORS
  // ============================================================

  static const Color success = Color(0xFF2E7D52);
  static const Color successLight = Color(0xFFE8F5EE);

  static const Color error = Color(0xFFB23A3A);
  static const Color errorLight = Color(0xFFFDEAEA);

  static const Color warning = Color(0xFFD4820A);
  static const Color warningLight = Color(0xFFFFF3E0);

  // ============================================================
  // BORDERS / DIVIDERS / SHADOWS
  // ============================================================

  static const Color divider = Color(0xFFB8D8DC);

  static const Color cardShadow = Color(0x228AABAE);

  // ============================================================
  // COMMON COLORS
  // ============================================================

  static const Color white = Color(0xFFFFFFFF);
  static const Color transparent = Colors.transparent;
}


// =================================================================
// APP THEME
// =================================================================

class AppTheme {
  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,

      primary: AppColors.primary,
      onPrimary: Colors.white,

      secondary: AppColors.accent,
      onSecondary: Colors.white,

      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,

      error: AppColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,

      brightness: Brightness.light,

      fontFamily: 'sans-serif',

      colorScheme: colorScheme,

      // ==========================================================
      // GLOBAL BACKGROUND
      // ==========================================================

      scaffoldBackgroundColor: AppColors.background,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,

        elevation: 0,
        scrolledUnderElevation: 0,

        centerTitle: true,

        surfaceTintColor: Colors.transparent,

        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: 0.3,
        ),

        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),

        actionsIconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),

      // ==========================================================
      // ELEVATED BUTTON
      // ==========================================================

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,

          foregroundColor: Colors.white,

          disabledBackgroundColor:
              AppColors.primaryLight.withValues(alpha: 0.55),

          disabledForegroundColor:
              Colors.white.withValues(alpha: 0.85),

          elevation: 3,

          shadowColor:
              AppColors.primary.withValues(alpha: 0.30),

          minimumSize: const Size(0, 52),

          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 32,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),

          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ==========================================================
      // OUTLINED BUTTON
      // ==========================================================

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,

          side: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),

          minimumSize: const Size(0, 52),

          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 32,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),

          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ==========================================================
      // TEXT BUTTON
      // ==========================================================

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,

          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ==========================================================
      // INPUT FIELDS
      // ==========================================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        fillColor: AppColors.surface,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),

        hintStyle: const TextStyle(
          color: AppColors.textHint,
          fontSize: 15,
        ),

        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
        ),

        prefixIconColor: AppColors.accent,

        suffixIconColor: AppColors.textHint,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.divider,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.accent,
            width: 2,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),

        errorStyle: const TextStyle(
          color: AppColors.error,
          fontSize: 12,
        ),
      ),

      // ==========================================================
      // CARDS
      // ==========================================================

      cardTheme: CardThemeData(
        color: AppColors.surface,

        surfaceTintColor: Colors.transparent,

        elevation: 4,

        shadowColor: AppColors.cardShadow,

        margin: EdgeInsets.zero,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      // ==========================================================
      // BOTTOM NAVIGATION
      // ==========================================================

      bottomNavigationBarTheme:
          const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,

        selectedItemColor: AppColors.primary,

        unselectedItemColor: AppColors.textHint,

        type: BottomNavigationBarType.fixed,

        elevation: 12,

        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),

        unselectedLabelStyle: TextStyle(
          fontSize: 11,
        ),
      ),

      // ==========================================================
      // NAVIGATION BAR — MATERIAL 3
      // ==========================================================

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,

        indicatorColor:
            AppColors.primary.withValues(alpha: 0.15),

        elevation: 8,

        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              );
            }

            return const TextStyle(
              color: AppColors.textHint,
              fontSize: 12,
            );
          },
        ),

        iconTheme: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: AppColors.primary,
              );
            }

            return const IconThemeData(
              color: AppColors.textHint,
            );
          },
        ),
      ),

      // ==========================================================
      // FLOATING ACTION BUTTON
      // ==========================================================

      floatingActionButtonTheme:
          const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 5,
      ),

      // ==========================================================
      // DIVIDERS
      // ==========================================================

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ==========================================================
      // CHECKBOX
      // ==========================================================

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }

            return Colors.transparent;
          },
        ),

        checkColor:
            const WidgetStatePropertyAll(Colors.white),

        side: const BorderSide(
          color: AppColors.textHint,
          width: 1.5,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // ==========================================================
      // RADIO BUTTON
      // ==========================================================

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }

            return AppColors.textHint;
          },
        ),
      ),

      // ==========================================================
      // SWITCH
      // ==========================================================

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }

            return AppColors.textHint;
          },
        ),

        trackColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }

            return AppColors.divider;
          },
        ),
      ),

      // ==========================================================
      // PROGRESS INDICATORS
      // ==========================================================

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceVariant,
        circularTrackColor: AppColors.surfaceVariant,
      ),

      // ==========================================================
      // SNACKBAR
      // ==========================================================

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,

        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ==========================================================
      // DIALOGS
      // ==========================================================

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,

        surfaceTintColor: Colors.transparent,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),

        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),

        contentTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),

      // ==========================================================
      // TEXT SELECTION / CURSOR
      // ==========================================================

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,

        selectionColor:
            AppColors.accent.withValues(alpha: 0.25),

        selectionHandleColor: AppColors.accent,
      ),

      // ==========================================================
      // ICONS
      // ==========================================================

      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
      ),

      // ==========================================================
      // TEXT
      // ==========================================================

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),

        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),

        headlineSmall: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),

        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),

        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),

        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
        ),

        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
        ),

        bodySmall: TextStyle(
          color: AppColors.textSecondary,
        ),

        labelLarge: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}