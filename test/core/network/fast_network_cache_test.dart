import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:everglow/core/network/fast_network_cache.dart';
import 'package:everglow/core/network/network_quality_service.dart';

void main() {
  setUp(() {
    FastNetworkCache.instance.clear();
    NetworkQualityService.debugReset();
  });

  tearDown(() {
    FastNetworkCache.instance.clear();
    NetworkQualityService.debugReset();
  });

  group('FastNetworkCache', () {
    test('fresh response is returned from cache without calling fetcher again', () async {
      final cache = FastNetworkCache(maxEntries: 10);
      var callCount = 0;

      Future<http.Response> fetcher() async {
        callCount++;
        return http.Response('{"title": "Everglow"}', 200);
      }

      final res1 = await cache.getOrFetchResponse('key1', fetcher);
      expect(res1.body, '{"title": "Everglow"}');
      expect(callCount, 1);

      final res2 = await cache.getOrFetchResponse('key1', fetcher);
      expect(res2.body, '{"title": "Everglow"}');
      expect(callCount, 1); // Not called again!
    });

    test('stale cache returns immediately on slow connection', () async {
      final cache = FastNetworkCache(maxEntries: 10);
      var callCount = 0;

      Future<http.Response> fetcher() async {
        callCount++;
        return http.Response('{"data": $callCount}', 200);
      }

      // Initial fetch with very short TTL
      await cache.getOrFetchResponse(
        'stale_key',
        fetcher,
        ttl: const Duration(milliseconds: 1),
        staleTtl: const Duration(hours: 1),
      );
      expect(callCount, 1);

      // Wait for TTL to expire
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Simulate slow connection
      NetworkQualityService.debugOverrideQuality = NetworkQuality.slow;

      final res = await cache.getOrFetchResponse(
        'stale_key',
        fetcher,
        ttl: const Duration(milliseconds: 1),
      );

      // Immediately received cached data with no wait
      expect(res.body, '{"data": 1}');
    });

    test('falls back to stale cache when network fails or times out', () async {
      final cache = FastNetworkCache(maxEntries: 10);
      var shouldFail = false;

      Future<http.Response> fetcher() async {
        if (shouldFail) {
          throw Exception('Network timeout on 2G');
        }
        return http.Response('{"status": "ok"}', 200);
      }

      // Populate cache
      await cache.getOrFetchResponse(
        'error_key',
        fetcher,
        ttl: const Duration(milliseconds: 1),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      shouldFail = true;

      // Network throws, but stale cache rescues the user!
      final res = await cache.getOrFetchResponse(
        'error_key',
        fetcher,
        ttl: const Duration(milliseconds: 1),
      );
      expect(res.body, '{"status": "ok"}');
    });

    test('getOrFetchString caches HTML/JSON strings and evicts LRU', () async {
      final cache = FastNetworkCache(maxEntries: 2);

      await cache.getOrFetchString('str1', () async => 'content 1');
      await cache.getOrFetchString('str2', () async => 'content 2');
      expect(cache.stringCount, 2);

      // Fetch str3, which evicts str1 (LRU)
      await cache.getOrFetchString('str3', () async => 'content 3');
      expect(cache.stringCount, 2);

      var fetch1Called = false;
      final str1 = await cache.getOrFetchString('str1', () async {
        fetch1Called = true;
        return 'new content 1';
      });
      expect(fetch1Called, isTrue); // Was evicted
      expect(str1, 'new content 1');
    });
  });
}
