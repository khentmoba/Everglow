import 'package:flutter/foundation.dart';

class Logger {
  Logger._();

  static void _log(String message) {
    if (kReleaseMode) return;
    debugPrint(message);
  }

  static void d(String message) => _log(message);

  static void i(String message) => _log(message);

  static void w(String message, {Object? error, StackTrace? stackTrace}) {
    _log('$message${error != null ? '\n$error' : ''}');
  }

  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('$message${error != null ? '\n$error' : ''}');
  }
}
