import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Trigger a browser download for a public-domain file URL.
/// Works only on web (the app's only target). On other platforms
/// this is a no-op; callers should fall back to [url_launcher].
///
/// Uses `package:web` rather than `dart:html` so this file also compiles for
/// the WebAssembly renderer, where `dart:html` is unavailable.
void downloadUrl(String url, {String? filename}) {
  if (!kIsWeb || url.isEmpty) return;
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..target = '_blank'
      ..rel = 'noopener';
    if (filename != null && filename.isNotEmpty) {
      anchor.download = filename;
    }
    anchor.click();
  } catch (e) {
    // Fall back to a plain window open if the anchor trick fails.
    web.window.open(url, '_blank');
  }
}
