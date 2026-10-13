import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../models/garden_stats.dart';
import '../../../../core/utils/logger.dart';

/// Source of garden stats. [GardenService] is the Firestore-backed
/// implementation; tests substitute a fake so [GardenProvider]'s retry
/// behavior can be verified without Firebase.
abstract class GardenStatsSource {
  Stream<GardenStats> watchStats(String userId);
  Stream<GardenStats> watchPartnerStats(String partnerUid);
  Future<void> recordInteraction(String userId);
  Future<void> setPlantType(String userId, String plantType);
}

class GardenService implements GardenStatsSource {
  GardenService({FirebaseFirestore? db}) : _customDb = db;
  final FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;

  @override
  Stream<GardenStats> watchStats(String userId) {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoGardenStats);
    }
    Stream<GardenStats> subscribe() {
      return _db
          .collection('users')
          .doc(userId)
          .collection('garden_stats')
          .doc('stats')
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists) {
              return GardenStats.initial();
            }
            return GardenStats.fromFirestore(snapshot);
          });
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'garden-stats',
      duration: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }

  @override
  Future<void> recordInteraction(String userId) async {
    if (AgentMode.isActive.value) return;
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('garden_stats')
        .doc('stats');

    await _db.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);
      final now = DateTime.now();

      if (!snapshot.exists) {
        // First visit ever
        final stats = GardenStats(
          currentStage: 1, // Start at Stage 1 (Sprout) on first visit
          lastVisit: now,
          streakCount: 1,
          totalInteractions: 1,
        );
        txn.set(docRef, stats.toFirestore());
        return;
      }

      final currentStats = GardenStats.fromFirestore(snapshot);

      // Calculate new streak
      int newStreak = currentStats.streakCount;
      if (_isYesterday(currentStats.lastVisit, now)) {
        newStreak += 1;
      } else if (!_isToday(currentStats.lastVisit, now)) {
        newStreak = 1; // Streak broken
      }
      // If it's today, streak stays the same (already incremented for today)

      final newTotalInteractions = currentStats.totalInteractions + 1;
      final newStage = GardenStats.calculateStage(newTotalInteractions);

      final updatedStats = currentStats.copyWith(
        currentStage: newStage,
        lastVisit: now,
        streakCount: newStreak,
        totalInteractions: newTotalInteractions,
      );

      txn.update(docRef, {
        'currentStage': updatedStats.currentStage,
        'lastVisit': Timestamp.fromDate(now),
        'streakCount': updatedStats.streakCount,
        'totalInteractions': newTotalInteractions,
      });
    });
  }

  bool _isToday(DateTime lastVisit, DateTime now) {
    return lastVisit.year == now.year &&
        lastVisit.month == now.month &&
        lastVisit.day == now.day;
  }

  bool _isYesterday(DateTime lastVisit, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return lastVisit.year == yesterday.year &&
        lastVisit.month == yesterday.month &&
        lastVisit.day == yesterday.day;
  }

  /// Watch partner's garden stats for the shared garden view.
  @override
  Stream<GardenStats> watchPartnerStats(String partnerUid) {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoGardenStats);
    }
    Stream<GardenStats> subscribe() {
      return _db
          .collection('users')
          .doc(partnerUid)
          .collection('garden_stats')
          .doc('stats')
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists) {
              return GardenStats.initial();
            }
            return GardenStats.fromFirestore(snapshot);
          });
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'garden-partner-stats',
      duration: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }

  /// Update the user's selected plant type.
  @override
  Future<void> setPlantType(String userId, String plantType) async {
    if (AgentMode.isActive.value) return;
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('garden_stats')
        .doc('stats');

    await _db.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);
      if (snapshot.exists) {
        txn.update(docRef, {'plantType': plantType});
      } else {
        // Create initial stats with the selected plant type
        final stats = GardenStats(
          currentStage: 0,
          lastVisit: DateTime.now(),
          streakCount: 0,
          totalInteractions: 0,
          plantType: plantType,
        );
        txn.set(docRef, stats.toFirestore());
      }
    });
    Logger.i('Plant type set to $plantType for user $userId');
  }
}
