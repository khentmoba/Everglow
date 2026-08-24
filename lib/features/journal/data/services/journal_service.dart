import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/journal_entry.dart';

/// Journal service — Memos + DailyTxT inspired.
///
/// Collection: journal_entries (couple-only, see firestore.rules)
class JournalService {
  static final JournalService _instance = JournalService._internal();
  factory JournalService() => _instance;
  JournalService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'journal_entries';

  Stream<List<JournalEntry>> watchAll() {
    return withFirestoreTimeout(
      _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => JournalEntry.fromFirestore(d)).toList(),
          ),
      label: 'journal-all',
    );
  }

  Stream<List<JournalEntry>> watchPinned() {
    return withFirestoreTimeout(
      _db
          .collection(_collection)
          .where('isPinned', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .map(
            (s) => s.docs.map((d) => JournalEntry.fromFirestore(d)).toList(),
          ),
      label: 'journal-pinned',
    );
  }

  Stream<List<JournalEntry>> watchByCategory(JournalCategory cat) {
    return withFirestoreTimeout(
      _db
          .collection(_collection)
          .where('category', isEqualTo: cat.name)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (s) => s.docs.map((d) => JournalEntry.fromFirestore(d)).toList(),
          ),
      label: 'journal-${cat.name}',
    );
  }

  Stream<List<JournalEntry>> watchByAuthor(String author) {
    return withFirestoreTimeout(
      _db
          .collection(_collection)
          .where('author', isEqualTo: author.toLowerCase())
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (s) => s.docs.map((d) => JournalEntry.fromFirestore(d)).toList(),
          ),
      label: 'journal-author-$author',
    );
  }

  /// Client-side search (like Starlight): filter title/content/tags.
  Stream<List<JournalEntry>> search(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return watchAll();
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => JournalEntry.fromFirestore(d))
              .where(
                (e) =>
                    e.title.toLowerCase().contains(q) ||
                    e.content.toLowerCase().contains(q) ||
                    e.tags.any((t) => t.toLowerCase().contains(q)) ||
                    e.category.name.contains(q),
              )
              .toList(),
        );
  }

  /// On This Day — same monthDay
  Future<List<JournalEntry>> getOnThisDay() async {
    final now = DateTime.now();
    final md =
        '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      final snap = await _db
          .collection(_collection)
          .where('monthDay', isEqualTo: md)
          .limit(50)
          .get();
      final entries = snap.docs
          .map((d) => JournalEntry.fromFirestore(d))
          .where((e) => e.createdAt.year != now.year)
          .toList();
      if (entries.isNotEmpty) return entries;
      // Fallback: client filter
      final fallback = await _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();
      return fallback.docs
          .map((d) => JournalEntry.fromFirestore(d))
          .where(
            (e) =>
                e.createdAt.month == now.month &&
                e.createdAt.day == now.day &&
                e.createdAt.year != now.year,
          )
          .toList();
    } catch (e) {
      Logger.e('journal onThisDay error', error: e);
      return [];
    }
  }

  Future<void> add(JournalEntry entry) async {
    try {
      await _db.collection(_collection).add(entry.toFirestore());
      Logger.i('Journal added: ${entry.title}');
    } catch (e) {
      Logger.e('Error adding journal', error: e);
    }
  }

  Future<void> update(JournalEntry entry) async {
    try {
      await _db.collection(_collection).doc(entry.id).update({
        ...entry.toFirestore(),
        'updatedAt': Timestamp.now(),
      });
      Logger.i('Journal updated: ${entry.id}');
    } catch (e) {
      Logger.e('Error updating journal', error: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      Logger.i('Journal deleted: $id');
    } catch (e) {
      Logger.e('Error deleting journal', error: e);
    }
  }

  Future<void> togglePin(String id, bool pinned) async {
    try {
      await _db.collection(_collection).doc(id).update({
        'isPinned': pinned,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      Logger.e('Error toggling pin', error: e);
    }
  }

  Future<void> toggleLock(String id, bool locked) async {
    try {
      await _db.collection(_collection).doc(id).update({
        'isLocked': locked,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      Logger.e('Error toggling lock', error: e);
    }
  }

  /// Heatmap data: count per day for last N days
  Stream<Map<String, int>> watchHeatmap({int days = 90}) {
    final start = DateTime.now().subtract(Duration(days: days));
    return _db
        .collection(_collection)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .snapshots()
        .map((snap) {
          final map = <String, int>{};
          for (final doc in snap.docs) {
            final e = JournalEntry.fromFirestore(doc);
            final key =
                '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}';
            map[key] = (map[key] ?? 0) + 1;
          }
          return map;
        });
  }
}
