import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

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
    web.window.open(url, '_blank');
  }
}
