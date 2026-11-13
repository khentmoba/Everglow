import 'package:web/web.dart' as web;

import '../utils/logger.dart';
import 'tv_mode.dart';

/// Browser-specific TV detection via userAgent, input capabilities, and URL parameters.
class TvDetector {
  TvDetector._();

  static bool? detectUrlOverride() {
    try {
      final href = web.window.location.href.toLowerCase();
      if (href.contains('tv=1') ||
          href.contains('tv=true') ||
          href.contains('mode=tv')) {
        return true;
      }
      if (href.contains('tv=0') || href.contains('tv=false')) {
        return false;
      }
    } catch (e, st) {
      Logger.e('TV URL override check fallback', error: e, stackTrace: st);
    }
    return null;
  }

  static bool detectTvBrowser() {
    try {
      if (detectUrlOverride() == true) return true;
      final userAgent = web.window.navigator.userAgent.toLowerCase();
      final maxTouchPoints = web.window.navigator.maxTouchPoints;
      final isLandscape = web.window.innerWidth >= web.window.innerHeight;
      return TvMode.isTvUserAgent(
        userAgent,
        maxTouchPoints: maxTouchPoints,
        isLandscape: isLandscape,
      );
    } catch (e, st) {
      Logger.e('TV browser detection fallback', error: e, stackTrace: st);
    }
    return false;
  }
}
