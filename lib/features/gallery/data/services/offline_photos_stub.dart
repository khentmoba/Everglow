/// No-op twin of `offline_photos_web.dart`: native builds already keep
/// viewed photos on disk, and VM tests have no browser cache.
class OfflinePhotos {
  OfflinePhotos._();

  static final OfflinePhotos instance = OfflinePhotos._();

  bool get supported => false;

  Future<int> savedCount() async => 0;

  Future<int> save(
    List<String> urls, {
    void Function(int done)? onProgress,
  }) async => 0;

  Future<void> clear() async {}
}
