import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

/// Monitors network connectivity status for web platform.
///
/// Provides a stream of connectivity changes and a one-shot check.
/// Uses the browser's `navigator.onLine` API.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final _controller = StreamController<bool>.broadcast();

  /// Stream of connectivity changes. `true` = online, `false` = offline.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Current connectivity status.
  bool get isOnline => web.window.navigator.onLine;

  bool _initialized = false;

  /// Initialize the connectivity listener. Call once at app startup.
  void init() {
    if (_initialized) return;
    _initialized = true;

    web.window.addEventListener('online', (web.Event _) {
      _controller.add(true);
    }.toJS);

    web.window.addEventListener('offline', (web.Event _) {
      _controller.add(false);
    }.toJS);
  }

  /// One-shot connectivity check by attempting to fetch a tiny resource.
  /// More reliable than `navigator.onLine` which can report false positives.
  Future<bool> checkConnectivity() async {
    try {
      final response = await web.window.fetch(
        '/favicon.ico'.toJS,
        web.RequestInit(method: 'HEAD'),
      ).toDart;
      return response.status == 200;
    } catch (e) {
      debugPrint('[ConnectivityService] Check failed: $e');
      return false;
    }
  }

  void dispose() {
    _controller.close();
  }
}
