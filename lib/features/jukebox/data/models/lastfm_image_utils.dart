import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// Last.fm serves a handful of default "no artwork" images instead of real
/// covers. These are the known placeholder hashes (verified: a light square
/// with a white star, and a gray disc). Rendering them makes a leaderboard
/// full of identical broken-looking thumbnails, so callers should treat
/// them as "no image".
const Set<String> _lastfmPlaceholderHashes = {
  '2a96cbd8b46e442fc41c2b86b821562f',
  'c6f59c1e5e7240a4c0d427abd71f3dbb',
};

bool isLastfmPlaceholderImage(String url) {
  return _lastfmPlaceholderHashes.any(url.contains);
}

/// Returns `null` when [url] is empty or a known Last.fm placeholder,
/// otherwise returns the URL unchanged (on web, Last.fm CDN artwork is
/// rewritten to [proxyLastfmImageUrl] so the browser's CORS check passes).
String? cleanLastfmImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (isLastfmPlaceholderImage(url)) return null;
  return _maybeProxyForWeb(url);
}

/// Re-serves Last.fm artwork with CORS headers (see `proxyLastfmImage`).
/// Direct `Image.network` loads of the Last.fm CDN fail on Flutter Web
/// because it sends no `Access-Control-Allow-Origin` header.
const String _lastfmImageProxyBase =
    'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyLastfmImage';

/// Test-only override for [kIsWeb] so the web rewrite is pinnable on the VM.
@visibleForTesting
bool? debugLastfmImageIsWeb;

bool get _isWeb => debugLastfmImageIsWeb ?? kIsWeb;

/// True when [url] is Last.fm CDN artwork (the only host family that
/// needs the CORS proxy; iTunes and Spotify art already send CORS headers).
bool isLastfmImageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  return host == 'lastfm-img.freetls.fastly.net' ||
      host == 'lastfm.freetls.fastly.net';
}

/// Rewrites Last.fm CDN artwork to the same-origin CORS proxy.
/// Idempotent: non-Last.fm and already-proxied URLs pass through unchanged.
String proxyLastfmImageUrl(String url) {
  if (!isLastfmImageUrl(url)) return url;
  return '$_lastfmImageProxyBase?url=${Uri.encodeComponent(url)}';
}

String? _maybeProxyForWeb(String? url) {
  if (url == null || !_isWeb) return url;
  return proxyLastfmImageUrl(url);
}

/// Preferred Last.fm image sizes, best first.
///
/// `extralarge` (~300px) stays crisp in 50px leaderboard thumbs at high DPR
/// without over-fetching; larger `mega` covers are rarer, smaller sizes are
/// last resorts.
const List<String> _preferredImageSizes = [
  'extralarge',
  'mega',
  'large',
  'medium',
  'small',
];

/// Picks the best usable artwork URL from a Last.fm `image` array.
///
/// Skips empty strings and known placeholder images, so a blank `extralarge`
/// slot never shadows a usable smaller cover. Falls back to the last usable
/// entry (Last.fm orders images smallest-first) when no preferred size hits.
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
