import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

/// Installs a browser `beforeunload` hook so tab close can run cleanup.
class BeforeUnloadHelper {
  web.EventListener? _listener;

  void install(VoidCallback onUnload) {
    uninstall();
    final listener = ((web.Event _) => onUnload()).toJS;
    web.window.addEventListener('beforeunload', listener);
    _listener = listener;
  }

  void uninstall() {
    final listener = _listener;
    if (listener == null) return;
    try {
      web.window.removeEventListener('beforeunload', listener);
    } catch (_) {
      // The page may already be tearing down.
    }
    _listener = null;
  }
}
