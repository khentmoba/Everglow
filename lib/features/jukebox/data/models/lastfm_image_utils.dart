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
