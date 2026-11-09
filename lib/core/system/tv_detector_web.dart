import 'package:web/web.dart' as web;

import '../utils/logger.dart';

/// Browser-specific TV detection via userAgent and URL parameters.
class TvDetector {
  TvDetector._();

  static bool detectTvBrowser() {
    try {
      final userAgent = web.window.navigator.userAgent.toLowerCase();
      const tvKeywords = [
        'tv',
        'smarttv',
        'googletv',
        'android tv',
        'tizen',
        'webos',
        'web0s',
        'viera',
        'bravia',
        'hbbtv',
        'netcast',
        'apple tv',
        'appletv',
        'roku',
        'crkey',
        'aft', // Amazon Fire TV (AFTM, AFTT, etc.)
        'pov_tv',
      ];
      for (final kw in tvKeywords) {
        if (userAgent.contains(kw)) return true;
      }
      final href = web.window.location.href.toLowerCase();
      if (href.contains('tv=1') ||
          href.contains('tv=true') ||
          href.contains('mode=tv')) {
        return true;
      }
    } catch (e, st) {
      Logger.e('TV browser detection fallback', error: e, stackTrace: st);
    }
    return false;
  }
}
