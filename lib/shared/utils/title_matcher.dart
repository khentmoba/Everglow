/// Fuzzy title matching shared by TMDB/anime poster verification.
///
/// Extracted from `TMDBBase.titlesMatch` so every caller uses one
/// implementation instead of copy-pasting the normalizer.
class TitleMatcher {
  TitleMatcher._();

  static String normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool titlesMatch(String storedTitle, String tmdbTitle) {
    final a = normalize(storedTitle);
    final b = normalize(tmdbTitle);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b || a.contains(b) || b.contains(a)) return true;
    final wordsA = a.split(' ');
    final wordsB = b.split(' ');
    final overlap = wordsA
        .where((w) => w.length > 2 && wordsB.contains(w))
        .length;
    final minLen = wordsA.length < wordsB.length
        ? wordsA.length
        : wordsB.length;
    return overlap >= (minLen * 0.5).ceil();
  }
}
