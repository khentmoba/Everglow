import 'dart:convert';

import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/catalog_proxy_client.dart';

/// One skippable stretch (opening or ending) inside an episode.
class AniSkipTime {
  /// Seconds from the episode start where the stretch begins.
  final double start;

  /// Seconds where it ends — the jump destination.
  final double end;

  const AniSkipTime({required this.start, required this.end});

  /// End as `m:ss` for button labels ("2:29").
  String get endLabel {
    final total = end.round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }
}

/// Opening/ending skip times for one episode. Either side may be missing
/// when the community hasn't marked it yet.
class AniSkipTimes {
  final AniSkipTime? opening;
  final AniSkipTime? ending;

  const AniSkipTimes({this.opening, this.ending});

  bool get isEmpty => opening == null && ending == null;
}

/// Parses an AniSkip v1 `skip-times` payload. Top-level (not a method) so
/// unit tests cover it without touching the network.
///
/// Expected shape:
/// `{"found":true,"results":[{"interval":{"start_time":..,"end_time":..},
/// "skip_type":"op"|"ed", ...}]}`. Anything unexpected yields nulls —
/// never throws.
AniSkipTimes parseAniSkipTimes(Map<String, dynamic> json) {
  AniSkipTime? opening;
  AniSkipTime? ending;
  try {
    final results = json['results'];
    if (results is! List) return const AniSkipTimes();
    for (final r in results) {
      if (r is! Map) continue;
      final interval = r['interval'];
      if (interval is! Map) continue;
      final start = (interval['start_time'] as num?)?.toDouble();
      final end = (interval['end_time'] as num?)?.toDouble();
      if (start == null || end == null || end <= start || start < 0) continue;
      final time = AniSkipTime(start: start, end: end);
      final type = (r['skip_type'] ?? '').toString();
      if (type == 'op') {
        opening ??= time;
      } else if (type == 'ed') {
        ending ??= time;
      }
    }
  } catch (_) {
    return const AniSkipTimes();
  }
  return AniSkipTimes(opening: opening, ending: ending);
}

/// Community opening/ending timestamps for anime episodes (AniSkip).
///
/// Keyed by MAL id + episode number — exactly what the anime watch page
/// already has. Routed through `proxyCatalog` like Jikan; responses are
/// cached in memory because skip times never change.
class AniSkipService {
  AniSkipService({CatalogProxyClient? proxy})
    : _proxy = proxy ?? CatalogProxyClient();

  final CatalogProxyClient _proxy;

  static final Map<String, AniSkipTimes> _cache = {};

  Future<AniSkipTimes?> fetchSkipTimes(int malId, int episode) async {
    if (malId <= 0 || episode <= 0) return null;
    final key = '$malId:$episode';
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final response = await _proxy.get(
        'aniskip',
        'v1/skip-times/$malId/$episode?types[]=op&types[]=ed',
      );
      if (response.statusCode == 404) {
        // Normal: nobody has marked this episode yet. Cache the miss so
        // re-opens don't re-ask.
        const empty = AniSkipTimes();
        _cache[key] = empty;
        return empty;
      }
      if (response.statusCode != 200) {
        Logger.e('[AniSkip] $key failed (${response.statusCode})');
        return null;
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;
      final times = parseAniSkipTimes(json);
      _cache[key] = times;
      return times;
    } catch (e) {
      Logger.e('[AniSkip] $key error', error: e);
      return null;
    }
  }
}
