import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/star_note.dart';

class StarlightService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'starlight_jar';

  /// All stars, newest first (for the jar visualization).
  Stream<List<StarNote>> getStarNotes() {
    return _db
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => StarNote.fromFirestore(doc)).toList());
  }

  /// Stars filtered by category.
  Stream<List<StarNote>> getStarsByCategory(String category) {
    return _db
        .collection(_collection)
        .where('category', isEqualTo: category)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => StarNote.fromFirestore(doc)).toList());
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
      });
      print("Dropped star into jar successfully");
    } catch (e) {
      print("Error adding star: $e");
    }
  }

  /// Get a random star from the jar.
  Future<StarNote?> getRandomStarNote() async {
    try {
      final snapshot = await _db.collection(_collection).get();
      if (snapshot.docs.isEmpty) return null;

      final docs = snapshot.docs;
      docs.shuffle();
      return StarNote.fromFirestore(docs.first);
    } catch (e) {
      print("Error getting random star: $e");
      return null;
    }
  }

  /// "On This Day" — stars from the same month+day across all years.
  Future<List<StarNote>> getStarsFromThisDay() async {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    try {
      // Fetch all stars and filter client-side by month+day.
      // Firestore doesn't support month/day queries natively.
      final snapshot = await _db
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .get();

      final results = <StarNote>[];
      for (final doc in snapshot.docs) {
        final note = StarNote.fromFirestore(doc);
        if (note.timestamp.month == month && note.timestamp.day == day &&
            note.timestamp.year != now.year) {
          results.add(note);
        }
      }
      return results;
    } catch (e) {
      print("Error getting on-this-day stars: $e");
      return [];
    }
  }

  /// Search stars by content (client-side full-text).
  Stream<List<StarNote>> searchStars(String query) {
    final lowerQuery = query.toLowerCase();
    return _db
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StarNote.fromFirestore(doc))
            .where((note) =>
                note.content.toLowerCase().contains(lowerQuery) ||
                note.tags.any((t) => t.toLowerCase().contains(lowerQuery)))
            .toList());
  }

  /// Delete a star note.
  Future<void> deleteStar(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      print("Deleted star $id");
    } catch (e) {
      print("Error deleting star: $e");
    }
  }
}
