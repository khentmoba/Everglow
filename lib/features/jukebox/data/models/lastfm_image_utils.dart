import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

const Set<String> _lastfmPlaceholderHashes = {
  '2a96cbd8b46e442fc41c2b86b821562f',
  'c6f59c1e5e7240a4c0d427abd71f3dbb',
};

bool isLastfmPlaceholderImage(String url) {
  return _lastfmPlaceholderHashes.any(url.contains);
}

String? cleanLastfmImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (isLastfmPlaceholderImage(url)) return null;
  return _maybeProxyForWeb(url);
}

const String _lastfmImageProxyBase =
    'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyLastfmImage';

@visibleForTesting
bool? debugLastfmImageIsWeb;

bool get _isWeb => debugLastfmImageIsWeb ?? kIsWeb;

bool isLastfmImageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  return host == 'lastfm-img.freetls.fastly.net' ||
      host == 'lastfm.freetls.fastly.net';
}

String proxyLastfmImageUrl(String url) {
  if (!isLastfmImageUrl(url)) return url;
  return '$_lastfmImageProxyBase?url=${Uri.encodeComponent(url)}';
}

String? _maybeProxyForWeb(String? url) {
  if (url == null || !_isWeb) return url;
  return proxyLastfmImageUrl(url);
}

const List<String> _preferredImageSizes = [
  'extralarge',
  'mega',
  'large',
  'medium',
  'small',
];

String? pickLastfmImageUrl(List<dynamic>? images) {
  if (images == null || images.isEmpty) return null;
  final entries = images.whereType<Map>().toList();
  for (final size in _preferredImageSizes) {
    for (final img in entries) {
      if (img['size'] == size) {
        final cleaned = cleanLastfmImageUrl(img['#text'] as String?);
        if (cleaned != null) return cleaned;
      }
    }
  }
  for (var i = entries.length - 1; i >= 0; i--) {
    final cleaned = cleanLastfmImageUrl(entries[i]['#text'] as String?);
    if (cleaned != null) return cleaned;
  }
  return null;
}
