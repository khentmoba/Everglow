import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Browser side of the silent auto-update, used by [AppUpdateService].
///
/// Every member guards its own failures so tabs booted from an older
/// deploy keep working.
@JS('__everglowAnyVideoPlaying')
external JSBoolean _anyVideoPlayingJS();

class AppUpdateBrowser {
  AppUpdateBrowser._();

  static final AppUpdateBrowser instance = AppUpdateBrowser._();

  /// False on platforms without a page to update (native stub, VM tests).
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

  /// True while a native `<video>` is mid-playback, so the auto-reload
  /// never interrupts movie night.
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

  /// Watches for tab-hide, tab-show, and back-online. Returns a cancel
  /// function for [ChangeNotifier.dispose]-time cleanup.
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
