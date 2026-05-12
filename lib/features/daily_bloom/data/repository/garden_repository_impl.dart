import '../../domain/repository/garden_repository.dart';
import '../models/garden_stats.dart';
import '../services/garden_service.dart';

class GardenRepositoryImpl implements GardenRepository {
  final GardenService _service;

  GardenRepositoryImpl(this._service);

  @override
  Stream<GardenStats> getGardenStats(String userId) {
    return _service.watchStats(userId);
  }

  @override
  Future<void> updateGardenStats(String userId, GardenStats stats) async {
    // This could be used for manual overrides or admin tools
  }

  @override
  Future<void> incrementInteractions(String userId) {
    return _service.recordInteraction(userId);
  }
}
