import 'dart:typed_data';

/// In-memory and file-based offline storage for native / test environments.
class OfflineMediaStorage {
  OfflineMediaStorage._();
  static final OfflineMediaStorage instance = OfflineMediaStorage._();

  static const mediaCacheName = 'everglow-offline-media-v1';
  static const mangaCacheName = 'everglow-offline-manga-v1';

  final Map<String, Uint8List> _mediaStore = {};
  final Map<String, Uint8List> _mangaStore = {};
  final Map<String, String> _objectUrls = {};

  bool get supported => true;

  Future<void> init() async {}

  Future<bool> saveMediaBlob(
    String key,
    Uint8List bytes, {
    String mimeType = 'video/mp4',
  }) async {
    _mediaStore[key] = bytes;
    return true;
  }

  Future<bool> saveMangaPage(
    String key,
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    _mangaStore[key] = bytes;
    return true;
  }

  Future<String?> getBlobUrl(String key, {bool isManga = false}) async {
    final store = isManga ? _mangaStore : _mediaStore;
    if (!store.containsKey(key)) return null;
    final fakeUrl = 'blob:offline://${isManga ? "manga" : "media"}/$key';
    _objectUrls[fakeUrl] = key;
    return fakeUrl;
  }

  Future<Uint8List?> getBlobBytes(String key, {bool isManga = false}) async {
    final store = isManga ? _mangaStore : _mediaStore;
    return store[key];
  }

  Future<void> revokeBlobUrl(String url) async {
    _objectUrls.remove(url);
  }

  Future<bool> deleteBlob(String key, {bool isManga = false}) async {
    final store = isManga ? _mangaStore : _mediaStore;
    return store.remove(key) != null;
  }

  Future<bool> hasBlob(String key, {bool isManga = false}) async {
    final store = isManga ? _mangaStore : _mediaStore;
    return store.containsKey(key);
  }

  Future<void> clearAll() async {
    _mediaStore.clear();
    _mangaStore.clear();
    _objectUrls.clear();
  }
}
