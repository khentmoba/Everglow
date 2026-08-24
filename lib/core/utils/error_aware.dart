import 'package:flutter/foundation.dart';

/// Mixin that adds error state tracking to services.
///
/// Usage:
/// ```dart
/// class MyService with ErrorAware {
///   Future<T> fetchData() async {
///     return trackError(() => http.get(...), context: 'Fetch data');
///   }
/// }
/// ```
mixin ErrorAware {
  String? _lastError;
  DateTime? _lastErrorTime;

  /// Last error message, if any.
  String? get lastError => _lastError;

  /// When the last error occurred.
  DateTime? get lastErrorTime => _lastErrorTime;

  /// Whether there's a recent error (within the last 30 seconds).
  bool get hasRecentError =>
      _lastError != null &&
      _lastErrorTime != null &&
      DateTime.now().difference(_lastErrorTime!).inSeconds < 30;

  /// Clear the error state.
  void clearError() {
    _lastError = null;
    _lastErrorTime = null;
  }

  /// Wraps an async operation with error tracking.
  ///
  /// Sets [lastError] on failure, clears it on success.
  /// Returns [fallback] if the operation fails.
  Future<T> trackError<T>(
    Future<T> Function() operation, {
    required T fallback,
    String? context,
  }) async {
    try {
      final result = await operation();
      clearError();
      return result;
    } catch (e) {
      _lastError = context != null ? '$context: $e' : e.toString();
      _lastErrorTime = DateTime.now();
      debugPrint('[ErrorAware] $_lastError');
      return fallback;
    }
  }
}
