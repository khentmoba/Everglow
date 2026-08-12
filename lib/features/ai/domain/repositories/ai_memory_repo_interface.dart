import '../memory/memory_fact.dart';

/// Abstract interface for memory repository operations.
///
/// Enables dependency injection and test mocking.
abstract class IAIMemoryRepository {
  List<String> get all;
  List<MemoryFact> get facts;
  bool get isLoaded;

  Future<void> load();
  Future<void> save(String fact, {String category = 'fact'});
  Future<void> saveStructured({
    required String fact,
    String category = 'fact',
    String? subject,
    String? relation,
    String? object,
    DateTime? occurredAt,
  });
  Future<void> delete(String factId);
  Future<void> setPinned(String factId, bool pinned);
  bool isDuplicate(String fact);
  void reset();
}
