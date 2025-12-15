import 'package:flutter/material.dart';

/// Modern App Colors - Clean, Professional Design
class AppColors {
  // ==================== LIGHT THEME ====================
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightDivider = Color(0xFFE5E7EB);
  
  // ==================== DARK THEME ====================
  static const Color darkBackground = Color(0xFF0F0F0F);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkCard = Color(0xFF242424);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkDivider = Color(0xFF2D2D2D);
  
  // ==================== ACCENT COLORS ====================
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color secondary = Color(0xFFEC4899); // Pink
  static const Color success = Color(0xFF10B981); // Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue
  
  // ==================== MESSAGE BUBBLES ====================
  // Sent messages (my messages)
  static const Color sentBubbleLight = Color(0xFF6366F1); // Indigo
  static const Color sentBubbleDark = Color(0xFF6366F1);
  static const Color sentTextLight = Color(0xFFFFFFFF);
  static const Color sentTextDark = Color(0xFFFFFFFF);
  
  // Received messages (friend's messages)
  static const Color receivedBubbleLight = Color(0xFFF3F4F6); // Light gray
  static const Color receivedBubbleDark = Color(0xFF2D2D2D); // Dark gray
  static const Color receivedTextLight = Color(0xFF1A1A1A);
  static const Color receivedTextDark = Color(0xFFFFFFFF);
  
  // ==================== GRADIENTS ====================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // ==================== HELPER METHODS ====================
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }
  
  static Color getSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }
  
  static Color getCard(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : lightCard;
  }
  
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }
  
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }
  
  static Color getDivider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkDivider
        : lightDivider;
  }
  
  static Color getSentBubble(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? sentBubbleDark
        : sentBubbleLight;
  }
  
  static Color getReceivedBubble(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? receivedBubbleDark
        : receivedBubbleLight;
  }
  
  static Color getSentText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? sentTextDark
        : sentTextLight;
  }
  
  static Color getReceivedText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? receivedTextDark
        : receivedTextLight;
  }
}
