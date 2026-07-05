import 'package:flutter/foundation.dart';

/// Minimal logger for production-safe debug output.
///
/// Maps to [debugPrint] under the hood so output respects Flutter's throttling
/// and is stripped from release builds.  Use the static shorthands in place
/// of raw `debugPrint` / `print` calls throughout feature code.
class Logger {
  Logger._();

  /// Debug-level (no-op in release mode).
  static void d(String message) => debugPrint(message);

  /// Info-level.
  static void i(String message) => debugPrint(message);

  /// Warning-level.
  static void w(String message) => debugPrint(message);

  /// Error-level with optional exception.
  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('$message${error != null ? '\n$error' : ''}');
  }
}
