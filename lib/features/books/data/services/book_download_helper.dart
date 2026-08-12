// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Trigger a browser download for a public-domain file URL.
/// Works only on web (the app's only target). On other platforms
/// this is a no-op; callers should fall back to [url_launcher].
void downloadUrl(String url, {String? filename}) {
  if (!kIsWeb || url.isEmpty) return;
  try {
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..rel = 'noopener';
    if (filename != null && filename.isNotEmpty) {
      anchor.download = filename;
    }
    anchor.click();
  } catch (e) {
    // Fall back to a plain window open if the anchor trick fails.
    html.window.open(url, '_blank');
  }
}
