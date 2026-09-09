import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/firestore_pagination.dart';
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
    Stream<List<JournalEntry>> subscribe() {
      return _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => JournalEntry.fromFirestore(d)).toList(),
          );
    }

    // Re-attach when the first snapshot is slow: the journal preview
    // was flipping to "could not load" on cold dashboard loads while
    // the WebChannel and auth token warm up. 12s x 3 attempts mirrors
    // calendar-upcoming and garden-stats.
    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'journal-all',
      duration: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }

  /// Older entries before [date] — seeds "load more" so the first older
  /// page starts after the live first page instead of re-fetching the
  /// newest entries. Continue with [fetchPage] + the returned cursor.
  Future<FirestorePage<JournalEntry>> fetchOlderThan(
    DateTime date, {
    int limit = 20,
  }) async {
    final snap = await _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(date)])
        .limit(limit)
        .get();
    final items = snap.docs.map(JournalEntry.fromFirestore).toList();
    final next = snap.docs.length < limit ? null : snap.docs.last;
    return FirestorePage(items: items, nextCursor: next);
  }

  /// Cursor-paginated older entries. The live first page stays on
  /// [watchAll]; call this with the previous page's [nextCursor] to
  /// scroll past entry 100 instead of hard-truncating the journal.
  Future<FirestorePage<JournalEntry>> fetchPage({
    DocumentSnapshot? cursor,
    int limit = 20,
  }) {
    return fetchFirestorePage(
      collection: _db.collection(_collection),
      orderBy: 'createdAt',
      cursor: cursor,
      limit: limit,
      fromDoc: JournalEntry.fromFirestore,
    );
  }

  // Capped preview for the dashboard rail: it renders 3 rows plus a
  // count, so a 100-doc realtime stream is 8x over-fetch on every
  // dashboard visit. Full history stays on watchAll for the journal
  // screen.
  Stream<List<JournalEntry>> watchPreview({int limit = 12}) {
    Stream<List<JournalEntry>> subscribe() {
      return _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => JournalEntry.fromFirestore(d)).toList(),
          );
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'journal-preview',
      duration: const Duration(seconds: 12),
      maxAttempts: 3,
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
  /// One-shot fetch (not a stream) so typing doesn't re-query on every
  /// remote write; callers debounce and memoize the future.
  Future<List<JournalEntry>> search(String query) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final snap = await _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .get();
    return snap.docs
        .map((d) => JournalEntry.fromFirestore(d))
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.content.toLowerCase().contains(q) ||
              e.tags.any((t) => t.toLowerCase().contains(q)) ||
              e.category.name.contains(q),
        )
        .toList();
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
        .limit(1000)
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
