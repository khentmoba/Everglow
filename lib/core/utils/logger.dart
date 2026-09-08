import 'package:flutter/foundation.dart';

/// Minimal logger for production-safe debug output.
///
/// Debug/info/warning go through [debugPrint] in development and are a
/// no-op in release web builds so runtime details are not exposed to the
/// browser. Errors always print (even in release): Firestore failure
/// lines are the only trace distinguishing timeout vs permission-denied
/// vs offline in a production bug report. Use the static shorthands in
/// place of raw `print` calls.
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

  /// Error-level with optional exception. Always emitted, including in
  /// release builds, so production diagnostics survive.
  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('$message${error != null ? '\n$error' : ''}');
  }
}
