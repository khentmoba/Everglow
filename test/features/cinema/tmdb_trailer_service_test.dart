import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_trailer_service.dart';

class _Service extends TMDBTrailerService {
  _Service(this.handler);
  final Future<http.Response> Function(Uri) handler;
  @override
  Future<http.Response> tmdbGet(Uri url) => handler(url);
}

void main() {
  test(
    'concurrent callers share trailer request, including no trailer',
    () async {
      var calls = 0;
      final response = Completer<http.Response>();
      final service = _Service((_) {
        calls++;
        return response.future;
      });
      final first = service.fetchTrailerKey(1, 'movie');
      final second = service.fetchTrailerKey(1, 'movie');
      response.complete(http.Response('{"results":[]}', 200));
      expect(await first, isNull);
      expect(await second, isNull);
      expect(await service.fetchTrailerKey(1, 'movie'), isNull);
      expect(calls, 1);
    },
  );

  test('trailer cache evicts old titles after 80 entries', () async {
    var calls = 0;
    final service = _Service((_) async {
      calls++;
      return http.Response('{"results":[]}', 200);
    });
    for (var id = 0; id < 81; id++) {
      await service.fetchTrailerKey(id, 'movie');
    }
    await service.fetchTrailerKey(80, 'movie');
    expect(calls, 81);
    await service.fetchTrailerKey(0, 'movie');
    expect(calls, 82);
  });

  test('transient trailer failures can be retried', () async {
    var calls = 0;
    final service = _Service((_) async {
      calls++;
      return calls == 1
          ? http.Response('', 502)
          : http.Response(
              '{"results":[{"site":"YouTube","type":"Trailer","official":true,"key":"demo"}]}',
              200,
            );
    });
    expect(await service.fetchTrailerKey(1, 'movie'), isNull);
    expect(await service.fetchTrailerKey(1, 'movie'), 'demo');
    expect(calls, 2);
  });
}
