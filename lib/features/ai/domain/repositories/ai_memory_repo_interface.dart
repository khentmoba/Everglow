/// Abstract interface for memory repository operations.
///
/// Enables dependency injection and test mocking.
abstract class IAIMemoryRepository {
  List<String> get all;
  bool get isLoaded;

  Future<void> load();
  Future<void> save(String fact, {String category = 'fact'});
  Future<void> delete(String factId);
  bool isDuplicate(String fact);
  void reset();
}
