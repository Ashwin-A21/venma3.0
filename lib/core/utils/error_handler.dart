import 'package:flutter/material.dart';

class ErrorHandler {
  static void handle(dynamic error, StackTrace? stack) {
    debugPrint('Error: $error');
    debugPrint('Stack: $stack');
    // Add crash reporting here (Sentry, Firebase Crashlytics, etc.)
  }
  
  static Future<T?> tryCatch<T>(
    Future<T> Function() operation, {
    T? fallback,
  }) async {
    try {
      return await operation();
    } catch (e, stack) {
      handle(e, stack);
      return fallback;
    }
  }
}
