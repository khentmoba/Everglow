import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get onConnectivityChanged => _controller.stream;

  bool get isOnline => web.window.navigator.onLine;

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    web.window.addEventListener(
      'online',
      (web.Event _) {
        _controller.add(true);
      }.toJS,
    );

    web.window.addEventListener(
      'offline',
      (web.Event _) {
        _controller.add(false);
      }.toJS,
    );
  }

  Future<bool> checkConnectivity() async {
    try {
      final response = await web.window
          .fetch('/favicon.ico'.toJS, web.RequestInit(method: 'HEAD'))
          .toDart;
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
