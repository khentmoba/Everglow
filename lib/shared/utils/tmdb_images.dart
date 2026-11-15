import '../../core/network/network_quality_service.dart';
import '../../core/perf/device_capability.dart';

class TmdbImages {
  TmdbImages._();

  static const String _cdn = 'https://image.tmdb.org/t/p';

  static const String poster = '$_cdn/w500';
  static const String card = '$_cdn/w342';
  static const String cardLow = '$_cdn/w185';
  static const String still = '$_cdn/w300';
  static const String stillLarge = '$_cdn/w400';
  static const String backdrop = '$_cdn/w780';
  static const String backdropLarge = '$_cdn/w1280';
  static const String profile = '$_cdn/w185';

  static bool get _useLowDataVariant =>
      NetworkQualityService.instance.isSlowConnection ||
      DeviceCapability.isLowEndDevice;

  static const _nullLike = {'null', 'undefined', 'false', 'none', 'nan'};

  static bool isUsablePath(String? path) {
    if (path == null) return false;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return false;
    if (_nullLike.contains(trimmed.toLowerCase())) return false;
    if (trimmed.contains(RegExp(r'\s'))) return false;
    return true;
  }

  static final RegExp _tmdbUrlPattern =
      RegExp(r'^https?://image\.tmdb\.org/t/p/[^/]+(/.+)$');

  static String _resolve(String? path, String base) {
    if (!isUsablePath(path)) return '';
    final trimmed = path!.trim();
    if (trimmed.startsWith('assets/')) return trimmed;
    final tmdbMatch = _tmdbUrlPattern.firstMatch(trimmed);
    if (tmdbMatch != null) {
      final relative = tmdbMatch.group(1)!;
      return '$base$relative';
    }
    if (trimmed.startsWith('http')) return trimmed;
    final relative = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$base$relative';
  }

  static String posterFor(String? path, {bool forceFullQuality = false}) {
    final base = (forceFullQuality || !_useLowDataVariant) ? poster : card;
    return _resolve(path, base);
  }

  static String cardFor(String? path, {bool forceFullQuality = false}) {
    final base = (forceFullQuality || !_useLowDataVariant) ? card : cardLow;
    return _resolve(path, base);
  }

  static String backdropFor(String? path, {bool large = false}) =>
      _resolve(path, large ? backdropLarge : backdrop);

  static String stillFor(String? path, {bool large = false}) =>
      _resolve(path, large ? stillLarge : still);
}
