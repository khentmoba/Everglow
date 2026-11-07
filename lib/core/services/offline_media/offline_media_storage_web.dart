import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

import '../../utils/logger.dart';

/// Web Cache Storage and Blob URL manager for offline media and manga pages.
class OfflineMediaStorage {
  OfflineMediaStorage._();
  static final OfflineMediaStorage instance = OfflineMediaStorage._();

  /// Must match `OFFLINE_MEDIA` and `OFFLINE_MANGA` in `web/sw.js`.
  static const mediaCacheName = 'everglow-offline-media-v1';
  static const mangaCacheName = 'everglow-offline-manga-v1';

  final Set<String> _createdObjectUrls = {};

  bool get supported => true;

  Future<void> init() async {}

  String _cacheKey(String key, bool isManga) {
    final prefix = isManga ? 'offline-manga' : 'offline-media';
    final safeKey = Uri.encodeComponent(key);
    return '${web.window.location.origin}/$prefix/$safeKey';
  }

  Future<web.Cache> _openCache(String name) async {
    return await web.window.caches.open(name).toDart;
  }

  Future<bool> saveMediaBlob(
    String key,
    Uint8List bytes, {
    String mimeType = 'video/mp4',
  }) async {
    try {
      final cache = await _openCache(mediaCacheName);
      final cacheKey = _cacheKey(key, false);
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: mimeType),
      );
      final headers = web.Headers();
      headers.set('Content-Type', mimeType);
      headers.set('Content-Length', bytes.lengthInBytes.toString());
      final response = web.Response(
        blob,
        web.ResponseInit(status: 200, statusText: 'OK', headers: headers),
      );
      await cache.put(cacheKey.toJS, response).toDart;
      return true;
    } catch (e) {
      Logger.e('OfflineMediaStorage: could not save media blob $key', error: e);
      return false;
    }
  }

  Future<bool> saveMangaPage(
    String key,
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final cache = await _openCache(mangaCacheName);
      final cacheKey = _cacheKey(key, true);
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: mimeType),
      );
      final headers = web.Headers();
      headers.set('Content-Type', mimeType);
      headers.set('Content-Length', bytes.lengthInBytes.toString());
      final response = web.Response(
        blob,
        web.ResponseInit(status: 200, statusText: 'OK', headers: headers),
      );
      await cache.put(cacheKey.toJS, response).toDart;
      return true;
    } catch (e) {
      Logger.e('OfflineMediaStorage: could not save manga page $key', error: e);
      return false;
    }
  }

  Future<String?> getBlobUrl(String key, {bool isManga = false}) async {
    try {
      final cache = await _openCache(
        isManga ? mangaCacheName : mediaCacheName,
      );
      final cacheKey = _cacheKey(key, isManga);
      final res = await cache.match(cacheKey.toJS).toDart;
      if (res == null) return null;
      final blob = await res.blob().toDart;
      final url = web.URL.createObjectURL(blob);
      _createdObjectUrls.add(url);
      return url;
    } catch (e) {
      Logger.e('OfflineMediaStorage: could not create blob URL for $key', error: e);
      return null;
    }
  }

  Future<Uint8List?> getBlobBytes(String key, {bool isManga = false}) async {
    try {
      final cache = await _openCache(
        isManga ? mangaCacheName : mediaCacheName,
      );
      final cacheKey = _cacheKey(key, isManga);
      final res = await cache.match(cacheKey.toJS).toDart;
      if (res == null) return null;
      final buffer = await res.arrayBuffer().toDart;
      return buffer.toDart.asUint8List();
    } catch (e) {
      Logger.e('OfflineMediaStorage: could not get blob bytes for $key', error: e);
      return null;
    }
  }

  Future<void> revokeBlobUrl(String url) async {
    if (_createdObjectUrls.remove(url)) {
      try {
        web.URL.revokeObjectURL(url);
      } catch (e) {
        Logger.e('OfflineMediaStorage: error revoking blob URL', error: e);
      }
    }
  }

  Future<bool> deleteBlob(String key, {bool isManga = false}) async {
    try {
      final cache = await _openCache(
        isManga ? mangaCacheName : mediaCacheName,
      );
      final cacheKey = _cacheKey(key, isManga);
      return (await cache.delete(cacheKey.toJS).toDart).toDart;
    } catch (e) {
      Logger.e('OfflineMediaStorage: could not delete blob $key', error: e);
      return false;
    }
  }

  Future<bool> hasBlob(String key, {bool isManga = false}) async {
    try {
      final cache = await _openCache(
        isManga ? mangaCacheName : mediaCacheName,
      );
      final cacheKey = _cacheKey(key, isManga);
      final res = await cache.match(cacheKey.toJS).toDart;
      return res != null;
    } catch (e) {
      Logger.e('OfflineMediaStorage: error checking blob $key', error: e);
      return false;
    }
  }

  Future<void> clearAll() async {
    for (final url in _createdObjectUrls) {
      try {
        web.URL.revokeObjectURL(url);
      } catch (e) {
        Logger.e('OfflineMediaStorage: error revoking blob URL', error: e);
      }
    }
    _createdObjectUrls.clear();
    try {
      await web.window.caches.delete(mediaCacheName).toDart;
      await web.window.caches.delete(mangaCacheName).toDart;
    } catch (e) {
      Logger.e('OfflineMediaStorage: could not clear caches', error: e);
    }
  }
}
