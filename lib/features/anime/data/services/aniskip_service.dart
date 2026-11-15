import 'dart:convert';

import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/catalog_proxy_client.dart';

class AniSkipTime {
  final double start;

  final double end;

  const AniSkipTime({required this.start, required this.end});

  String get endLabel {
    final total = end.round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }
}

class AniSkipTimes {
  final AniSkipTime? opening;
  final AniSkipTime? ending;

  const AniSkipTimes({this.opening, this.ending});

  bool get isEmpty => opening == null && ending == null;
}

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

bool skipVisibleAt(AniSkipTime time, double position) =>
    position >= time.start && position <= time.end;

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
