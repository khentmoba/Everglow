import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../../core/utils/logger.dart';

class OfflinePhotos {
  OfflinePhotos._();

  static final OfflinePhotos instance = OfflinePhotos._();

  static const cacheName = 'everglow-offline-photos-v1';

  bool get supported => true;

  Future<int> savedCount() async {
    try {
      final cache = await web.window.caches.open(cacheName).toDart;
      return (await cache.keys().toDart).length;
    } catch (e) {
      Logger.e('Offline photos: could not count saved photos', error: e);
      return 0;
    }
  }

  Future<int> save(
    List<String> urls, {
    void Function(int done)? onProgress,
  }) async {
    final cache = await web.window.caches.open(cacheName).toDart;
    var saved = 0;
    var done = 0;
    for (final url in urls) {
      if (!url.startsWith('http')) {
        saved++;
        onProgress?.call(++done);
        continue;
      }
      try {
        await cache.add(url.toJS).toDart;
        saved++;
      } catch (e) {
        Logger.e('Offline photos: could not keep $url', error: e);
      }
      onProgress?.call(++done);
    }
    return saved;
  }

  Future<void> clear() async {
    try {
      await web.window.caches.delete(cacheName).toDart;
    } catch (e) {
      Logger.e('Offline photos: could not clear saved photos', error: e);
    }
  }
}
