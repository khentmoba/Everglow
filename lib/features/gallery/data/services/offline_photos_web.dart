import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../../core/utils/logger.dart';

/// Gallery thumbnails Clair chose to keep on this device.
///
/// Lives in its own Cache Storage bucket, which `web/sw.js` serves before
/// the network and never clears on update. Logout deletes it.
class OfflinePhotos {
  OfflinePhotos._();

  static final OfflinePhotos instance = OfflinePhotos._();

  /// Must match `OFFLINE_PHOTOS` in `tool/generate_sw.dart`.
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

  /// Saves each URL, skipping ones that fail, and returns how many are kept.
  Future<int> save(
    List<String> urls, {
    void Function(int done)? onProgress,
  }) async {
    final cache = await web.window.caches.open(cacheName).toDart;
    var saved = 0;
    var done = 0;
    for (final url in urls) {
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
