import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/star_note.dart';
import '../../../../core/utils/logger.dart';

class StarlightService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'starlight_jar';

  static String _monthDay(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$m-$d';
  }

  /// All stars, newest first (for the jar visualization).
  Stream<List<StarNote>> getStarNotes() {
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

  /// Stars filtered by category.
  Stream<List<StarNote>> getStarsByCategory(String category) {
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

  /// Add a new star with category and tags.
  Future<void> addStar(
    String content,
    String author, {
    String category = 'gratitude',
    List<String> tags = const [],
  }) async {
    if (content.trim().isEmpty) return;

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

  /// Get a random star from the jar.
  Future<StarNote?> getRandomStarNote() async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      if (snapshot.docs.isEmpty) return null;

      final docs = snapshot.docs;
      docs.shuffle();
      return StarNote.fromFirestore(docs.first);
    } catch (e) {
      Logger.e("Error getting random star", error: e);
      return null;
    }
  }

  /// "On This Day" — stars from the same month+day across all years.
  Future<List<StarNote>> getStarsFromThisDay() async {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    try {
      final monthDay = _monthDay(now);
      var snapshot = await _db
          .collection(_collection)
          .where('monthDay', isEqualTo: monthDay)
          .limit(100)
          .get();

      // Legacy stars predate the monthDay field; bound the fallback.
      if (snapshot.docs.isEmpty) {
        snapshot = await _db
            .collection(_collection)
            .orderBy('timestamp', descending: true)
            .limit(200)
            .get();
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

  /// Search stars by content (client-side full-text).
  Stream<List<StarNote>> searchStars(String query) {
    final lowerQuery = query.toLowerCase();
    return _db
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StarNote.fromFirestore(doc))
              .where(
                (note) =>
                    note.content.toLowerCase().contains(lowerQuery) ||
                    note.tags.any((t) => t.toLowerCase().contains(lowerQuery)),
              )
              .toList(),
        );
  }

  /// Delete a star note.
  Future<void> deleteStar(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      Logger.i("Deleted star $id");
    } catch (e) {
      Logger.e("Error deleting star", error: e);
    }
  }
}
