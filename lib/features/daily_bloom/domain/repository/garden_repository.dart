import '../../data/models/garden_stats.dart';

abstract class GardenRepository {
  Stream<GardenStats> getGardenStats(String userId);
  Future<void> updateGardenStats(String userId, GardenStats stats);
  Future<void> incrementInteractions(String userId);
}
