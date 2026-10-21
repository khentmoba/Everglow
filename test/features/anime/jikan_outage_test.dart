import 'package:everglow/features/anime/data/services/jikan_service.dart';
import 'package:everglow/shared/utils/catalog_proxy_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'queued catalog reads skip a known outage and retry after cooldown',
    () async {
      var now = DateTime(2026, 10, 22);
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('upstream failed', 502)
            : http.Response('{"data":[]}', 200);
      });
      final service = JikanService(
        proxy: CatalogProxyClient(client: client),
        now: () => now,
      );
      await Future.wait([service.fetchTopAnime(), service.fetchTopAnime()]);
      expect(calls, 1);
      await service.fetchTopAiring();
      expect(calls, 1);
      now = now.add(const Duration(seconds: 31));
      await service.fetchTopAnime();
      expect(calls, 2);
      client.close();
    },
  );
}
