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
/// otherwise returns the URL unchanged.
String? cleanLastfmImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  return isLastfmPlaceholderImage(url) ? null : url;
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
