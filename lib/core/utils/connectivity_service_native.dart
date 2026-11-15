import 'dart:async';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get onConnectivityChanged => _controller.stream;

  bool get isOnline => true;

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
  }

  Future<bool> checkConnectivity() async => true;

  void dispose() {
    _controller.close();
  }
}
