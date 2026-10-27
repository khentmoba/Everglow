import 'dart:async';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import 'network_quality_service.dart';

/// Cached entry holding a value and freshness timestamps.
class FastCacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  final Duration ttl;
  final Duration staleTtl;

  const FastCacheEntry({
    required this.data,
    required this.cachedAt,
    required this.ttl,
    required this.staleTtl,
  });

  bool get isFresh => DateTime.now().difference(cachedAt) < ttl;
  bool get isUsable => DateTime.now().difference(cachedAt) < staleTtl;
}

/// In-memory LRU network cache with Stale-While-Revalidate support.
///
/// Accelerates slow internet devices by:
/// 1. Serving cached responses with 0ms latency.
/// 2. Allowing background revalidation so the UI never blocks.
/// 3. Falling back to stale cached data during network timeouts or drops.
class FastNetworkCache {
  FastNetworkCache({int maxEntries = 120}) : _maxEntries = maxEntries;

  static final FastNetworkCache instance = FastNetworkCache();

  final int _maxEntries;
  final Map<String, FastCacheEntry<http.Response>> _responseCache = {};
  final Map<String, FastCacheEntry<String>> _stringCache = {};
  final Set<String> _inFlightKeys = {};

  int get responseCount => _responseCache.length;
  int get stringCount => _stringCache.length;

  void clear() {
    _responseCache.clearDistributed();
    _stringCache.clear();
    _inFlightKeys.clear();
  }

  /// Directly updates a cached string value (e.g. on explicit force-refresh).
  void putStringDirectly(
    String key,
    String data, {
    Duration ttl = const Duration(minutes: 15),
    Duration staleTtl = const Duration(hours: 24),
  }) {
    _putString(key, data, ttl, staleTtl);
  }

  /// Fetches an HTTP response with transparent stale-while-revalidate caching.
  Future<http.Response> getOrFetchResponse(
    String key,
    Future<http.Response> Function() fetcher, {
    Duration ttl = const Duration(minutes: 15),
    Duration staleTtl = const Duration(hours: 24),
    bool staleWhileRevalidate = true,
  }) async {
    final cached = _responseCache[key];

    // 1. Fresh cache hit: return immediately.
    if (cached != null && cached.isFresh) {
      return _cloneResponse(cached.data);
    }

    // 2. Stale cache hit:
    if (cached != null && cached.isUsable) {
      // On slow connections, immediately return stale cache to avoid blocking user.
      if (NetworkQualityService.instance.isSlowConnection) {
        if (staleWhileRevalidate) {
          unawaited(_revalidateResponse(key, fetcher, ttl, staleTtl));
        }
        return _cloneResponse(cached.data);
      }

      if (staleWhileRevalidate) {
        // Return stale data at once, revalidate in background.
        unawaited(_revalidateResponse(key, fetcher, ttl, staleTtl));
        return _cloneResponse(cached.data);
      }
    }

    // 3. Cache miss: fetch from network with fallback to stale cache on failure.
    try {
      final response = await fetcher();
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        _putResponse(key, response, ttl, staleTtl);
      }
      return response;
    } catch (e) {
      // If network fails (e.g. timeout on 2G/3G) but we have any cached data, heal with cache!
      if (cached != null) {
        Logger.w('[FastNetworkCache] Network failed, served stale cache for $key');
        return _cloneResponse(cached.data);
      }
      rethrow;
    }
  }

  /// Fetches a String payload (e.g. HTML or JSON) with stale-while-revalidate caching.
  Future<String?> getOrFetchString(
    String key,
    Future<String?> Function() fetcher, {
    Duration ttl = const Duration(minutes: 15),
    Duration staleTtl = const Duration(hours: 24),
    bool staleWhileRevalidate = true,
  }) async {
    final cached = _stringCache[key];

    if (cached != null && cached.isFresh) {
      return cached.data;
    }

    if (cached != null && cached.isUsable) {
      if (NetworkQualityService.instance.isSlowConnection || staleWhileRevalidate) {
        unawaited(_revalidateString(key, fetcher, ttl, staleTtl));
        return cached.data;
      }
    }

    try {
      final fresh = await fetcher();
      if (fresh != null && fresh.isNotEmpty) {
        _putString(key, fresh, ttl, staleTtl);
      }
      return fresh;
    } catch (e) {
      if (cached != null) {
        return cached.data;
      }
      rethrow;
    }
  }

  void _putResponse(
    String key,
    http.Response response,
    Duration ttl,
    Duration staleTtl,
  ) {
    if (_responseCache.length >= _maxEntries) {
      _responseCache.remove(_responseCache.keys.first);
    }
    _responseCache[key] = FastCacheEntry(
      data: _cloneResponse(response),
      cachedAt: DateTime.now(),
      ttl: ttl,
      staleTtl: staleTtl,
    );
  }

  void _putString(
    String key,
    String data,
    Duration ttl,
    Duration staleTtl,
  ) {
    if (_stringCache.length >= _maxEntries) {
      _stringCache.remove(_stringCache.keys.first);
    }
    _stringCache[key] = FastCacheEntry(
      data: data,
      cachedAt: DateTime.now(),
      ttl: ttl,
      staleTtl: staleTtl,
    );
  }

  Future<void> _revalidateResponse(
    String key,
    Future<http.Response> Function() fetcher,
    Duration ttl,
    Duration staleTtl,
  ) async {
    if (_inFlightKeys.contains(key)) return;
    _inFlightKeys.add(key);
    try {
      final response = await fetcher();
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        _putResponse(key, response, ttl, staleTtl);
      }
    } catch (e) {
      Logger.w('[FastNetworkCache] revalidateResponse failed', error: e);
    } finally {
      _inFlightKeys.remove(key);
    }
  }

  Future<void> _revalidateString(
    String key,
    Future<String?> Function() fetcher,
    Duration ttl,
    Duration staleTtl,
  ) async {
    if (_inFlightKeys.contains(key)) return;
    _inFlightKeys.add(key);
    try {
      final fresh = await fetcher();
      if (fresh != null && fresh.isNotEmpty) {
        _putString(key, fresh, ttl, staleTtl);
      }
    } catch (e) {
      Logger.w('[FastNetworkCache] revalidateString failed', error: e);
    } finally {
      _inFlightKeys.remove(key);
    }
  }

  http.Response _cloneResponse(http.Response res) {
    return http.Response(
      res.body,
      res.statusCode,
      headers: Map<String, String>.from(res.headers),
      request: res.request,
      isRedirect: res.isRedirect,
      persistentConnection: res.persistentConnection,
      reasonPhrase: res.reasonPhrase,
    );
  }
}

extension on Map<String, FastCacheEntry<http.Response>> {
  void clearDistributed() => clear();
}
