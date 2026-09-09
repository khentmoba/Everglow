import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:everglow/features/anime/data/services/aniskip_service.dart';
import 'package:everglow/shared/utils/catalog_proxy_client.dart';

const _payload = '''
{"found":true,"results":[
{"interval":{"start_time":58.642,"end_time":148.642},"skip_type":"op","skip_id":"a","episode_length":1469.0},
{"interval":{"start_time":1349.903,"end_time":1474.0},"skip_type":"ed","skip_id":"b","episode_length":1474.0}
]}''';

void main() {
  group('parseAniSkipTimes', () {
    test('parses opening and ending', () {
      final times =
          parseAniSkipTimes(jsonDecode(_payload) as Map<String, dynamic>);
      expect(times.opening?.start, 58.642);
      expect(times.opening?.end, 148.642);
      expect(times.ending?.start, 1349.903);
      expect(times.ending?.end, 1474.0);
      expect(times.isEmpty, isFalse);
    });

    test('formats end as m:ss', () {
      const t = AniSkipTime(start: 58.0, end: 149.0);
      expect(t.endLabel, '2:29');
    });

    test('missing results yields empty, never throws', () {
      expect(parseAniSkipTimes({}).isEmpty, isTrue);
      expect(parseAniSkipTimes({'results': 'nope'}).isEmpty, isTrue);
      expect(
        parseAniSkipTimes({
          'results': [
            {'interval': {'start_time': 5, 'end_time': 1}, 'skip_type': 'op'},
            {'interval': {'start_time': -3, 'end_time': 90}, 'skip_type': 'ed'},
          ],
        }).isEmpty,
        isTrue,
      );
    });

    test('keeps first result per type', () {
      final times = parseAniSkipTimes({
        'results': [
          {
            'interval': {'start_time': 10, 'end_time': 100},
            'skip_type': 'op',
          },
          {
            'interval': {'start_time': 20, 'end_time': 110},
            'skip_type': 'op',
          },
        ],
      });
      expect(times.opening?.start, 10);
    });
  });

  group('AniSkipService', () {
    test('fetches through proxyCatalog and caches', () async {
      var hits = 0;
      final mock = MockClient((request) async {
        hits++;
        expect(request.url.queryParameters['base'], 'aniskip');
        expect(
          request.url.queryParameters['path'],
          'v1/skip-times/5114/1?types[]=op&types[]=ed',
        );
        return http.Response(_payload, 200);
      });
      final service =
          AniSkipService(proxy: CatalogProxyClient(client: mock));
      final first = await service.fetchSkipTimes(5114, 1);
      expect(first?.opening?.endLabel, '2:29');
      final second = await service.fetchSkipTimes(5114, 1);
      expect(second?.opening?.endLabel, '2:29');
      expect(hits, 1);
    });

    test('404 caches an empty miss', () async {
      var hits = 0;
      final mock = MockClient((_) async {
        hits++;
        return http.Response('{"found":false,"results":[]}', 404);
      });
      final service =
          AniSkipService(proxy: CatalogProxyClient(client: mock));
      expect((await service.fetchSkipTimes(1, 99))?.isEmpty, isTrue);
      expect((await service.fetchSkipTimes(1, 99))?.isEmpty, isTrue);
      expect(hits, 1);
    });

    test('bad ids never hit the network', () async {
      final mock = MockClient((_) async => http.Response('', 500));
      final service =
          AniSkipService(proxy: CatalogProxyClient(client: mock));
      expect(await service.fetchSkipTimes(0, 1), isNull);
      expect(await service.fetchSkipTimes(5114, 0), isNull);
    });
  });
}
