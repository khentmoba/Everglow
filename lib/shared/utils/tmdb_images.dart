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

  static String posterFor(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$poster$path';
  }

  static String backdropFor(String? path, {bool large = false}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${large ? backdropLarge : backdrop}$path';
  }

  static String stillFor(String? path, {bool large = false}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${large ? stillLarge : still}$path';
  }
}
