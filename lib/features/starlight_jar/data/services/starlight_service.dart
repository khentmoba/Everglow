import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../domain/models/star_note.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';

class StarlightService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'starlight_jar';

  static String _monthDay(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$m-$d';
  }

  Stream<List<StarNote>> getStarNotes() {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoStars);
    }
    return _db
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .limit(40)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => StarNote.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<StarNote>> getStarsByCategory(String category) {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(
        AgentFixtures.demoStars.where((s) => s.category == category).toList(),
      );
    }
    return _db
        .collection(_collection)
        .where('category', isEqualTo: category)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => StarNote.fromFirestore(doc)).toList(),
        );
  }

  Future<void> addStar(
    String content,
    String author, {
    String category = 'gratitude',
    List<String> tags = const [],
  }) async {
    if (content.trim().isEmpty) return;
    if (AgentMode.isActive.value) return;

    try {
      await _db.collection(_collection).add({
        'content': content.trim(),
        'author': author.toLowerCase(),
        'timestamp': FieldValue.serverTimestamp(),
        'category': category,
        'tags': tags,
        'monthDay': _monthDay(DateTime.now()),
      });
      Logger.i("Dropped star into jar successfully");
    } catch (e) {
      Logger.e("Error adding star", error: e);
    }
  }

  Future<StarNote?> getRandomStarNote() async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return AgentFixtures.demoStars.first;
    }
    try {
      final snapshot = await withGetTimeout(
        _db
            .collection(_collection)
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get(),
        label: 'starlight random star',
      );
      if (snapshot.docs.isEmpty) return null;

      final docs = snapshot.docs;
      docs.shuffle();
      return StarNote.fromFirestore(docs.first);
    } catch (e) {
      Logger.e("Error getting random star", error: e);
      return null;
    }
  }

  Future<List<StarNote>> getStarsFromThisDay() async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return AgentFixtures.demoStars;
    }
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    try {
      final monthDay = _monthDay(now);
      var snapshot = await withGetTimeout(
        _db
            .collection(_collection)
            .where('monthDay', isEqualTo: monthDay)
            .limit(100)
            .get(),
        label: 'starlight on-this-day',
      );

      if (snapshot.docs.isEmpty) {
        snapshot = await withGetTimeout(
          _db
              .collection(_collection)
              .orderBy('timestamp', descending: true)
              .limit(200)
              .get(),
          label: 'starlight on-this-day fallback',
        );
      }

      final results = <StarNote>[];
      for (final doc in snapshot.docs) {
        final note = StarNote.fromFirestore(doc);
        if (note.timestamp.month == month &&
            note.timestamp.day == day &&
            note.timestamp.year != now.year) {
          results.add(note);
        }
      }
      return results;
    } catch (e) {
      Logger.e("Error getting on-this-day stars", error: e);
      return [];
    }
  }

  Future<List<StarNote>> searchStars(String query) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return AgentFixtures.demoStars;
    }
    final lowerQuery = query.toLowerCase();
    final snapshot = await withGetTimeout(
      _db
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get(),
      label: 'starlight search',
    );
    return snapshot.docs
        .map((doc) => StarNote.fromFirestore(doc))
        .where(
          (note) =>
              note.content.toLowerCase().contains(lowerQuery) ||
              note.tags.any((t) => t.toLowerCase().contains(lowerQuery)),
        )
        .toList();
  }

  Future<void> deleteStar(String id) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection(_collection).doc(id).delete();
      Logger.i("Deleted star $id");
    } catch (e) {
      Logger.e("Error deleting star", error: e);
    }
  }
}
