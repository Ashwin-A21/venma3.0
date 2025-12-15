import 'package:flutter/foundation.dart';

class Logger {
  static void info(String message) => debugPrint('ℹ️ $message');
  static void warning(String message) => debugPrint('⚠️ $message');
  static void error(String message, [dynamic error, StackTrace? stack]) {
    debugPrint('❌ $message');
    if (error != null) debugPrint('Error: $error');
    if (stack != null) debugPrint('Stack: $stack');
  }
  static void success(String message) => debugPrint('✅ $message');
}
