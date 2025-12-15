import 'package:flutter/material.dart';

class AppColors {
  // ============ LIGHT THEME COLORS ============
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF6C63FF);
  static const Color secondary = Color(0xFFFF6584);
  static const Color accentBlue = Color(0xFF29B6F6);
  static const Color accentOrange = Color(0xFFFF8A65);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  
  // Light mode message bubbles
  static const Color myMessageBg = Color(0xFF6C63FF);
  static const Color friendMessageBg = Color(0xFFE8E8EC);
  static const Color friendPillBg = Color(0xFFE8E8E8);
  
  // Light mode input
  static const Color inputBackground = Color(0xFFF1F1F5);
  static const Color inputBorder = Color(0xFFE0E0E0);
  
  // ============ DARK THEME COLORS ============
  static const Color darkBackground = Color(0xFF0A0A0F);
  static const Color darkSurface = Color(0xFF16161F);
  static const Color darkCard = Color(0xFF1E1E2D);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  
  // Dark mode message bubbles
  static const Color darkMyMessageBg = Color(0xFF6C63FF);
  static const Color darkFriendMessageBg = Color(0xFF2D2D3A);
  
  // Dark mode input
  static const Color darkInputBackground = Color(0xFF1E1E2D);
  static const Color darkInputBorder = Color(0xFF3D3D4A);
  
  // ============ GRADIENTS ============
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF8F94FB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkPrimaryGradient = LinearGradient(
    colors: [Color(0xFF7C73FF), Color(0xFF9FA4FB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1A000000), Color(0x0D000000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGlassGradient = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x1AFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // ============ HELPER METHODS ============
  
  /// Get message bubble color based on theme and sender
  static Color getMessageBubbleColor(BuildContext context, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isMe) {
      return isDark ? darkMyMessageBg : myMessageBg;
    } else {
      return isDark ? darkFriendMessageBg : friendMessageBg;
    }
  }
  
  /// Get input field background color based on theme
  static Color getInputBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkInputBackground : inputBackground;
  }
  
  /// Get input field border color based on theme
  static Color getInputBorder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkInputBorder : inputBorder;
  }
  
  /// Get text color for message bubbles
  static Color getMessageTextColor(BuildContext context, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isMe) {
      return Colors.white;
    } else {
      return isDark ? darkTextPrimary : textPrimary;
    }
  }
  
  /// Get time text color for message bubbles
  static Color getMessageTimeColor(BuildContext context, bool isMe) {
    if (isMe) {
      return Colors.white70;
    } else {
      return Theme.of(context).brightness == Brightness.dark 
          ? darkTextSecondary 
          : textSecondary;
    }
  }
}
