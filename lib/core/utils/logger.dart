import 'package:flutter/foundation.dart';

/// Minimal logger for production-safe debug output.
///
/// Routes diagnostics through [debugPrint] in development and becomes a no-op
/// in release web builds so runtime details are not exposed to the browser.
/// Use the static shorthands in place of raw `print` calls.
class Logger {
  Logger._();

  static void _log(String message) {
    if (kReleaseMode) return;
    debugPrint(message);
  }

  /// Debug-level (no-op in release mode).
  static void d(String message) => _log(message);

  /// Info-level.
  static void i(String message) => _log(message);

  /// Warning-level.
  static void w(String message) => _log(message);

  /// Error-level with optional exception.
  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    _log('$message${error != null ? '\n$error' : ''}');
  }
}
