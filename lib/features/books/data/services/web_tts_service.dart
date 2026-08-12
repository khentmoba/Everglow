import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Read-aloud ("Listen") engine backed by the browser's built-in
/// Web Speech API — the legal equivalent of WeLib's audiobook modal.
/// Web-only by design: on non-web targets [isSupported] is false and
/// every method becomes a safe no-op.
class WebTtsService {
  WebTtsService._();
  static final WebTtsService instance = WebTtsService._();

  web.SpeechSynthesisUtterance? _current;
  double _rate = 1.0;
  Timer? _watchdog;
  VoidCallback? _onComplete;

  bool get isSupported => kIsWeb;

  bool get isSpeaking =>
      isSupported && web.window.speechSynthesis.speaking;

  bool get isPaused =>
      isSupported && web.window.speechSynthesis.paused;

  double get rate => _rate;

  /// Speak a chunk of text. On completion (natural end or cancel),
  /// [onComplete] fires so the UI can advance or stop.
  void speak(String text, {double rate = 1.0, VoidCallback? onComplete}) {
    if (!isSupported || text.trim().isEmpty) return;
    final synthesis = web.window.speechSynthesis;
    synthesis.cancel();
    _watchdog?.cancel();
    _onComplete = onComplete;
    _rate = rate;

    final utterance = web.SpeechSynthesisUtterance(text);
    utterance.rate = rate;
    utterance.pitch = 1.0;
    utterance.volume = 1.0;
    _current = utterance;
    synthesis.speak(utterance);

    _watchdog = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!web.window.speechSynthesis.speaking) {
        _watchdog?.cancel();
        _current = null;
        _onComplete?.call();
      }
    });
  }

  void setRate(double rate) {
    _rate = rate;
    if (_current != null) {
      _current!.rate = rate;
    }
  }

  void pause() {
    if (!isSupported || _current == null) return;
    web.window.speechSynthesis.pause();
  }

  void resume() {
    if (!isSupported || _current == null) return;
    web.window.speechSynthesis.resume();
  }

  void stop() {
    _watchdog?.cancel();
    _watchdog = null;
    if (isSupported) {
      web.window.speechSynthesis.cancel();
    }
    _current = null;
  }
}
