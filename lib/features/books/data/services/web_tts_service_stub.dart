import 'package:flutter/foundation.dart';

/// Non-web fallback for WebTtsService so VM widget tests never touch
/// `package:web`. Every method is a safe no-op.
class WebTtsService {
  WebTtsService._();
  static final WebTtsService instance = WebTtsService._();

  double _rate = 1.0;

  bool get isSupported => false;
  bool get isSpeaking => false;
  bool get isPaused => false;
  double get rate => _rate;

  void speak(String text, {double rate = 1.0, VoidCallback? onComplete}) {
    onComplete?.call();
  }

  void setRate(double rate) {
    _rate = rate;
  }

  void pause() {}
  void resume() {}
  void stop() {}
}
