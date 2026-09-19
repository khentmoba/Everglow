/// Single source of truth for TMDB image CDN base URLs.
///
/// Previously these string literals were duplicated across
/// `TMDBBase`, `MediaItem`, dashboard cards, shelf widgets and the
/// watch-party widgets. Import this instead of hardcoding a new copy.
class TmdbImages {
  TmdbImages._();

  static const String _cdn = 'https://image.tmdb.org/t/p';

  static const String poster = '$_cdn/w500';
  static const String card = '$_cdn/w342';
  static const String still = '$_cdn/w300';
  static const String stillLarge = '$_cdn/w400';
  static const String backdrop = '$_cdn/w780';
  static const String backdropLarge = '$_cdn/w1280';
  static const String profile = '$_cdn/w185';

  /// Strings that mean "no image" when stored in Firestore. TMDB returns
  /// `poster_path: null` for artwork-less titles; if that null ever gets
  /// stringified on save ("null", "undefined", ...), the shelf would
  /// otherwise build a bogus `.../w500null` URL that 404s forever instead
  /// of healing. Matching is case-insensitive on the trimmed value.
  static const _nullLike = {'null', 'undefined', 'false', 'none', 'nan'};

  /// True when [path] can actually produce a fetchable image URL: not
  /// blank, not a stringified null, and free of whitespace (TMDB paths
  /// never contain spaces — a value like "Yellow Jacket" is a title
  /// that leaked into the poster field, not a path).
  static bool isUsablePath(String? path) {
    if (path == null) return false;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return false;
    if (_nullLike.contains(trimmed.toLowerCase())) return false;
    if (trimmed.contains(RegExp(r'\s'))) return false;
    return true;
  }

  static String _resolve(String? path, String base) {
    if (!isUsablePath(path)) return '';
    final trimmed = path!.trim();
    if (trimmed.startsWith('http')) return trimmed;
    // TMDB paths always start with '/'. If the slash was ever stripped
    // on save ("abc.jpg"), restoring it beats a guaranteed 404.
    final relative = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$base$relative';
  }

  static String posterFor(String? path) => _resolve(path, poster);

  static String backdropFor(String? path, {bool large = false}) =>
      _resolve(path, large ? backdropLarge : backdrop);

  static String stillFor(String? path, {bool large = false}) =>
      _resolve(path, large ? stillLarge : still);
}
