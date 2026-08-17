import 'dart:async';

/// Mobile-friendly connectivity monitor.
///
/// Android/iOS don't expose `navigator.onLine`; the app relies on
/// Flutter's lifecycle and per-request error handling instead.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final _controller = StreamController<bool>.broadcast();

  /// Stream of connectivity changes. `true` = online, `false` = offline.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Current connectivity status.
  bool get isOnline => true;

  bool _initialized = false;

  /// Initialize the connectivity listener. Call once at app startup.
  void init() {
    if (_initialized) return;
    _initialized = true;
  }

  /// One-shot connectivity check.
  Future<bool> checkConnectivity() async => true;

  void dispose() {
    _controller.close();
  }
}
