import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  // Light Theme Colors
  static const Color _lightBackground = Color(0xFFF5F5F7);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightTextPrimary = Color(0xFF1A1A2E);
  static const Color _lightTextSecondary = Color(0xFF6B7280);
  
  // Dark Theme Colors - Premium dark aesthetic
  static const Color _darkBackground = Color(0xFF0A0A0F);
  static const Color _darkSurface = Color(0xFF16161F);
  static const Color _darkCard = Color(0xFF1E1E2D);
  static const Color _darkTextPrimary = Color(0xFFFFFFFF);
  static const Color _darkTextSecondary = Color(0xFF9CA3AF);
  
  // Accent colors
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentPink = Color(0xFFEC4899);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBackground,
      primaryColor: AppColors.primary,
      cardColor: _lightSurface,
      dividerColor: Colors.grey[200],
      hintColor: _lightTextSecondary,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: _lightSurface,
        background: _lightBackground,
        onBackground: _lightTextPrimary,
        onSurface: _lightTextPrimary,
        tertiary: accentPurple,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: _lightTextPrimary, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.outfit(color: _lightTextPrimary, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.outfit(color: _lightTextPrimary, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.outfit(color: _lightTextPrimary, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.outfit(color: _lightTextPrimary, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.outfit(color: _lightTextPrimary, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.outfit(color: _lightTextPrimary),
        bodyMedium: GoogleFonts.outfit(color: _lightTextSecondary),
        bodySmall: GoogleFonts.outfit(color: _lightTextSecondary),
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: _lightTextPrimary,
        iconTheme: const IconThemeData(color: AppColors.primary),
        titleTextStyle: GoogleFonts.outfit(
          color: _lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.outfit(color: _lightTextSecondary),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _lightSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightTextPrimary,
        contentTextStyle: GoogleFonts.outfit(color: _lightSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary.withOpacity(0.3);
          return Colors.grey.withOpacity(0.3);
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBackground,
      primaryColor: AppColors.primary,
      cardColor: _darkCard,
      dividerColor: Colors.grey[800],
      hintColor: _darkTextSecondary,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: accentCyan,
        surface: _darkSurface,
        background: _darkBackground,
        onBackground: _darkTextPrimary,
        onSurface: _darkTextPrimary,
        tertiary: accentPurple,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: _darkTextPrimary, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.outfit(color: _darkTextPrimary, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.outfit(color: _darkTextPrimary, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.outfit(color: _darkTextPrimary, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.outfit(color: _darkTextPrimary, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.outfit(color: _darkTextPrimary, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.outfit(color: _darkTextPrimary),
        bodyMedium: GoogleFonts.outfit(color: _darkTextSecondary),
        bodySmall: GoogleFonts.outfit(color: _darkTextSecondary),
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: _darkTextPrimary,
        iconTheme: const IconThemeData(color: AppColors.primary),
        titleTextStyle: GoogleFonts.outfit(
          color: _darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.outfit(color: _darkTextSecondary),
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkCard,
        contentTextStyle: GoogleFonts.outfit(color: _darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary.withOpacity(0.3);
          return Colors.grey.withOpacity(0.3);
        }),
      ),
    );
  }
}
