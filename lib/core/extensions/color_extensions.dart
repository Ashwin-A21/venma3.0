import 'package:flutter/material.dart';

/// Extension methods for Color to provide modern opacity handling
extension ColorExtensions on Color {
  /// Modern replacement for deprecated withOpacity
  /// Uses withValues for better precision
  /// Accepts opacity from 0.0 to 1.0
  Color withOpacityValue(double opacity) {
    assert(opacity >= 0.0 && opacity <= 1.0);
    return withValues(alpha: opacity);
  }
}
