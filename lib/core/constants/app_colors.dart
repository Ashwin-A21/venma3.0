import 'package:flutter/material.dart';

class AppColors {
  // Light Theme Colors
  static const Color background = Color(0xFFF5F5F5); // Light gray
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color primary = Color(0xFF6C63FF); // Vibrant Purple (kept)
  static const Color secondary = Color(0xFFFF6584); // Vibrant Pink/Red (kept)
  static const Color accentBlue = Color(0xFF29B6F6); // Cyan/Blue
  static const Color accentOrange = Color(0xFFFF8A65); // Orange
  static const Color textPrimary = Color(0xFF1A1A1A); // Dark text
  static const Color textSecondary = Color(0xFF757575); // Medium gray text
  
  static const Color friendPillBg = Color(0xFFE8E8E8); // Light pill background
  static const Color myMessageBg = Color(0xFF6C63FF); // Gradient start usually
  static const Color friendMessageBg = Color(0xFFE0E0E0); // Light gray message bubble
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF8F94FB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1A000000), Color(0x0D000000)], // Dark glass for light theme
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
