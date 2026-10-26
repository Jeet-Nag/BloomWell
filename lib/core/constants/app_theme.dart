import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.sagePrimary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.sageBackground,
        onPrimaryContainer: AppColors.sageDark,
        secondary: AppColors.mutedLavender,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.lavenderLight,
        onSecondaryContainer: Color(0xFF382A52),
        surface: AppColors.warmBackground,
        onSurface: AppColors.textDark,
        surfaceContainerHighest: AppColors.surfaceCardMuted,
        error: AppColors.gentleCoral,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.warmBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.warmBackground,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textDark),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight, width: 0.8),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sagePrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.sageDark,
          side: const BorderSide(color: AppColors.sageLight, width: 1.2),
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.sagePrimary, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: const TextStyle(color: AppColors.textSubtle),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 3,
        indicatorColor: AppColors.sageBackground,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.sageDark,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: AppColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.sageDark, size: 24);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 24);
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.sageLight,
        onPrimary: AppColors.darkBackground,
        primaryContainer: AppColors.darkCard,
        onPrimaryContainer: AppColors.sageLight,
        secondary: AppColors.mutedLavender,
        onSecondary: Colors.white,
        surface: AppColors.darkBackground,
        onSurface: AppColors.darkText,
        surfaceContainerHighest: AppColors.darkCard,
        error: AppColors.gentleCoral,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        iconTheme: IconThemeData(color: AppColors.darkText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sagePrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
