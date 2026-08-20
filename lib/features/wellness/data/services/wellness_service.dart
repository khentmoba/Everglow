import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/habit.dart';
import '../models/workout.dart';

class WellnessService {
  static final WellnessService _instance = WellnessService._internal();
  factory WellnessService() => _instance;
  WellnessService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _habitsCol = 'habits';
  final String _workoutsCol = 'workouts';

  // Habits
  Stream<List<Habit>> watchHabits() => withFirestoreTimeout(
        _db.collection(_habitsCol).orderBy('createdAt', descending: true).limit(50).snapshots().map((s) => s.docs.map((d) => Habit.fromFirestore(d)).toList()),
        label: 'habits-all',
      );

  Stream<List<Habit>> watchActiveHabits() => withFirestoreTimeout(
        _db.collection(_habitsCol).snapshots().map((s) => s.docs.map((d) => Habit.fromFirestore(d)).where((h) => h.isActive).toList()),
        label: 'habits-active',
      );

  Future<void> addHabit(Habit habit) async {
    try {
      await _db.collection(_habitsCol).add(habit.toFirestore());
      Logger.i('Habit added: ${habit.title}');
    } catch (e) {
      Logger.e('Error adding habit', error: e);
    }
  }

  Future<void> toggleCompleteToday(String habitId, String currentUsername) async {
    try {
      final doc = await _db.collection(_habitsCol).doc(habitId).get();
      if (!doc.exists) return;
      final habit = Habit.fromFirestore(doc);
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      List<DateTime> updated;
      int newStreak;
      if (habit.isCompletedToday) {
        updated = habit.completedDates.where((d) => !(d.year == todayKey.year && d.month == todayKey.month && d.day == todayKey.day)).toList();
        newStreak = (habit.streak > 0 ? habit.streak - 1 : 0);
      } else {
        updated = [...habit.completedDates, todayKey];
        newStreak = habit.streak + 1;
      }
      final longest = newStreak > habit.longestStreak ? newStreak : habit.longestStreak;
      await _db.collection(_habitsCol).doc(habitId).update({
        'completedDates': updated.map((d) => Timestamp.fromDate(d)).toList(),
        'streak': newStreak,
        'longestStreak': longest,
      });
      Logger.i('Toggled habit $habitId → $newStreak');
    } catch (e) {
      Logger.e('Error toggling habit', error: e);
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      await _db.collection(_habitsCol).doc(id).delete();
    } catch (e) {
      Logger.e('Error deleting habit', error: e);
    }
  }

  Future<void> archiveHabit(String id, bool active) async {
    try {
      await _db.collection(_habitsCol).doc(id).update({'isActive': active});
    } catch (e) {
      Logger.e('Error archiving habit', error: e);
    }
  }

  // Workouts — wger
  Stream<List<Workout>> watchWorkouts() => withFirestoreTimeout(
        _db.collection(_workoutsCol).orderBy('date', descending: true).limit(50).snapshots().map((s) => s.docs.map((d) => Workout.fromFirestore(d)).toList()),
        label: 'workouts-all',
      );

  Stream<List<Workout>> watchRecentWorkouts({int limit = 7}) => withFirestoreTimeout(
        _db.collection(_workoutsCol).orderBy('date', descending: true).limit(limit).snapshots().map((s) => s.docs.map((d) => Workout.fromFirestore(d)).toList()),
        label: 'workouts-recent',
      );

  Future<void> addWorkout(Workout workout) async {
    try {
      await _db.collection(_workoutsCol).add(workout.toFirestore());
      Logger.i('Workout added: ${workout.title}');
    } catch (e) {
      Logger.e('Error adding workout', error: e);
    }
  }

  Future<void> deleteWorkout(String id) async {
    try {
      await _db.collection(_workoutsCol).doc(id).delete();
    } catch (e) {
      Logger.e('Error deleting workout', error: e);
    }
  }

  // Stats
  Future<Map<String, int>> getWeeklyStreaks() async {
    final snap = await _db.collection(_habitsCol).where('isActive', isEqualTo: true).get();
    final habits = snap.docs.map((d) => Habit.fromFirestore(d)).toList();
    final total = habits.length;
    final completedToday = habits.where((h) => h.isCompletedToday).length;
    final avgStreak = habits.isEmpty ? 0 : (habits.map((h) => h.streak).reduce((a, b) => a + b) / habits.length).round();
    return {'total': total, 'completedToday': completedToday, 'avgStreak': avgStreak};
  }
}
