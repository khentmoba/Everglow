import 'connectivity_service.dart';
import 'logger.dart';

/// Mixin that adds connectivity-aware HTTP request helpers.
///
/// Usage:
/// ```dart
/// class MyService with ConnectivityAware {
///   Future<T> fetchData() => withConnectivity(() => http.get(...));
/// }
/// ```
mixin ConnectivityAware {
  /// Wraps an async operation with connectivity pre-check.
  ///
  /// Returns `fallback` if offline, otherwise executes [operation].
  /// Catches and logs network errors gracefully.
  Future<T> withConnectivity<T>(
    Future<T> Function() operation, {
    required T fallback,
    String? context,
  }) async {
    if (!ConnectivityService.instance.isOnline) {
      Logger.w('${context ?? 'Request'} skipped: device is offline');
      return fallback;
    }
    try {
      return await operation();
    } catch (e) {
      Logger.e('${context ?? 'Request'} failed', error: e);
      return fallback;
    }
  }
}
