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

  /// Generic media words that leak into stored titles ("Yellow Jacket
  /// Television" for TMDB's "Yellowjackets") and must not block a match.
  static const _genericSuffixes = {
    'television',
    'televison', // Common misspelling (e.g. "Yellow Jacket Televison")
    'tv',
    'movie',
    'movies',
    'film',
    'films',
    'series',
    'show',
    'shows',
    'season',
    'seasons',
    'episode',
    'episodes',
    'anime',
    'animation',
    'animated',
    'ova',
    'ona',
    'special',
    'specials',
  };

  /// Strips generic media suffixes ("television", "televison", "movie", "tv", etc.)
  /// and leading articles from [title]. Returns the cleaned title.
  static String stripGenerics(String title) {
    final norm = normalize(title);
    final stripped = _stripGenerics(norm);
    if (stripped.isEmpty) return title.trim();
    return stripped;
  }

  /// Generates ranked search queries for TMDB when searching for artwork / healing.
  ///
  /// For "Yellow Jacket Televison":
  /// 1. "Yellow Jacket Televison" (raw)
  /// 2. "Yellow Jacket" (generic suffixes stripped)
  /// 3. "yellowjackets" (compound plural)
  /// 4. "yellowjacket" (compound singular)
  /// 5. "yellow jackets" (spaced plural)
  static List<String> searchCandidates(String rawTitle) {
    final trimmed = rawTitle.trim();
    if (trimmed.isEmpty) return const [];

    final candidates = <String>[trimmed];
    final norm = normalize(trimmed);
    final stripped = _stripGenerics(norm);

    if (stripped.isNotEmpty && stripped != norm) {
      candidates.add(stripped);
    }

    final base = stripped.isNotEmpty ? stripped : norm;
    final words = base.split(' ').where((w) => w.isNotEmpty).toList();

    if (words.length > 1) {
      final compound = words.join('');
      candidates.add(compound);
      if (!compound.endsWith('s')) {
        candidates.add('${compound}s');
      } else if (compound.length > 4 && compound.endsWith('s')) {
        candidates.add(compound.substring(0, compound.length - 1));
      }
      final spaced = words.join(' ');
      if (!spaced.endsWith('s')) {
        candidates.add('${spaced}s');
      }
    } else if (words.length == 1) {
      final word = words.first;
      if (!word.endsWith('s')) {
        candidates.add('${word}s');
      } else if (word.length > 4 && word.endsWith('s')) {
        candidates.add(word.substring(0, word.length - 1));
      }
    }

    final seen = <String>{};
    final result = <String>[];
    for (final c in candidates) {
      final key = c.toLowerCase().trim();
      if (key.isNotEmpty && seen.add(key)) {
        result.add(c);
      }
    }
    return result;
  }

  static String _stripGenerics(String normalized) {
    var words = normalized
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    while (words.isNotEmpty && _genericSuffixes.contains(words.last)) {
      words.removeLast();
    }
    // Leading articles ("The Office" vs "Office") match via contains
    // already, but stripping keeps the spaceless comparison tight.
    while (words.length > 1 &&
        (words.first == 'the' ||
            words.first == 'a' ||
            words.first == 'an')) {
      words.removeAt(0);
    }
    return words.join(' ');
  }

  static bool _containsGuarded(String haystack, String needle) {
    // Bare contains() lets "It" match "Split" ("split".contains("it")).
    // Require the shorter side to be at least 4 chars so short titles
    // only match exactly or via word overlap, never via substring luck.
    if (needle.length < 4) return false;
    return haystack.contains(needle);
  }

  static bool titlesMatch(String storedTitle, String tmdbTitle) {
    final a = normalize(storedTitle);
    final b = normalize(tmdbTitle);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    if (_containsGuarded(a, b) || _containsGuarded(b, a)) return true;
    // Strip "Television"/"Movie" suffixes, then retry: "yellow jacket
    // television" -> "yellow jacket" vs TMDB's "yellowjackets".
    final sa = _stripGenerics(a);
    final sb = _stripGenerics(b);
    if (sa.isNotEmpty && sb.isNotEmpty && (sa != a || sb != b)) {
      if (sa == sb) return true;
      if (_containsGuarded(sa, sb) || _containsGuarded(sb, sa)) return true;
    }
    // Spaceless for compound words ("yellow jacket" vs "yellowjackets",
    // "spider man" vs "spiderman"). Min length 5 guards short titles.
    for (final pair in [
      (sa.isNotEmpty ? sa : a, sb.isNotEmpty ? sb : b),
      (a, b),
    ]) {
      final na = pair.$1.replaceAll(' ', '');
      final nb = pair.$2.replaceAll(' ', '');
      if (na.length >= 5 && nb.length >= 5) {
        if (na == nb || na.contains(nb) || nb.contains(na)) return true;
      }
    }
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

  /// Loose fallback for poster healing when [titlesMatch] fails but TMDB's
  /// top result is clearly the same title ("Yellow Jacket Television" vs
  /// "Yellowjackets"). True when the spaceless normalized titles share a
  /// common substring of at least 6 chars. Short titles never loosely
  /// match, so "It" can't steal "Split"'s poster via luck.
  static bool titlesLooselyMatch(String a, String b) {
    final na = normalize(a).replaceAll(' ', '');
    final nb = normalize(b).replaceAll(' ', '');
    if (na.length < 6 || nb.length < 6) return false;
    // Longest-common-substring DP; titles are short (<60 chars) so O(n*m)
    // is trivial. Tracks the max diagonal run of matching chars.
    var maxLen = 0;
    final dp = List<int>.filled(nb.length + 1, 0);
    for (var i = 1; i <= na.length; i++) {
      var prev = 0;
      for (var j = 1; j <= nb.length; j++) {
        final temp = dp[j];
        if (na.codeUnitAt(i - 1) == nb.codeUnitAt(j - 1)) {
          dp[j] = prev + 1;
          if (dp[j] > maxLen) maxLen = dp[j];
          // Early exit once the threshold is hit.
          if (maxLen >= 6) return true;
        } else {
          dp[j] = 0;
        }
        prev = temp;
      }
    }
    return false;
  }
}
