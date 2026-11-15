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
