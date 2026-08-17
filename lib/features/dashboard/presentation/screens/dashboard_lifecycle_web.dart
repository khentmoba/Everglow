import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

/// Registers browser page-lifecycle hooks used to flip presence offline.
class DashboardLifecycle {
  final List<web.EventListener> _listeners = [];

  void install(VoidCallback onPageHidden) {
    uninstall();
    for (final eventName in ['pagehide', 'beforeunload']) {
      final listener = ((web.Event _) => onPageHidden()).toJS;
      web.window.addEventListener(eventName, listener);
      _listeners.add(listener);
    }
  }

  void uninstall() {
    for (final listener in _listeners) {
      try {
        web.window.removeEventListener('pagehide', listener);
        web.window.removeEventListener('beforeunload', listener);
      } catch (_) {
        // Page teardown may already be underway.
      }
    }
    _listeners.clear();
  }
}
