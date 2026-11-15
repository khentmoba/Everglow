import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('__everglowAnyVideoPlaying')
external JSBoolean _anyVideoPlayingJS();

class AppUpdateBrowser {
  AppUpdateBrowser._();

  static final AppUpdateBrowser instance = AppUpdateBrowser._();

  bool get supported => true;

  bool get isHidden {
    try {
      return web.document.visibilityState == 'hidden';
    } catch (_) {
      return false;
    }
  }

  bool get isOffline {
    try {
      return !web.window.navigator.onLine;
    } catch (_) {
      return false;
    }
  }

  bool get isVideoPlaying {
    try {
      return _anyVideoPlayingJS().toDart;
    } catch (_) {
      return false;
    }
  }

  void reload() {
    try {
      web.window.location.reload();
    } catch (_) {
      // The page is going away anyway.
    }
  }

  void Function() listen({
    required void Function() onHidden,
    required void Function() onVisible,
    required void Function() onOnline,
  }) {
    final visibility = ((web.Event _) {
      if (isHidden) {
        onHidden();
      } else {
        onVisible();
      }
    }).toJS;
    final online = ((web.Event _) {
      onOnline();
    }).toJS;
    try {
      web.document.addEventListener(
        'visibilitychange',
        visibility as web.EventListener,
      );
      web.window.addEventListener('online', online as web.EventListener);
    } catch (_) {
      // Listeners are best-effort; the poll timer still catches up.
    }
    return () {
      try {
        web.document.removeEventListener(
          'visibilitychange',
          visibility as web.EventListener,
        );
        web.window.removeEventListener('online', online as web.EventListener);
      } catch (_) {
        // The page may already be tearing down.
      }
    };
  }
}
