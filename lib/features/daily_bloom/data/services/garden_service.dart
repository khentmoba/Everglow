import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/garden_stats.dart';

class GardenService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<GardenStats> watchStats(String userId) {
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

  Future<void> recordInteraction(String userId) async {
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('garden_stats')
        .doc('stats');

    final snapshot = await docRef.get();
    final now = DateTime.now();

    if (!snapshot.exists) {
      // First visit ever
      final stats = GardenStats(
        currentStage: 1, // Start at Stage 1 (Sprout) on first visit
        lastVisit: now,
        streakCount: 1,
        totalInteractions: 1,
      );
      await docRef.set(stats.toFirestore());
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
    final newStage = _calculateStage(newTotalInteractions);

    final updatedStats = currentStats.copyWith(
      currentStage: newStage,
      lastVisit: now,
      streakCount: newStreak,
      totalInteractions: newTotalInteractions,
    );

    await docRef.update(updatedStats.toFirestore());
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

  int _calculateStage(int interactions) {
    if (interactions >= 30) return 5;
    if (interactions >= 20) return 4;
    if (interactions >= 10) return 3;
    if (interactions >= 5) return 2;
    if (interactions >= 1) return 1;
    return 0;
  }
}
