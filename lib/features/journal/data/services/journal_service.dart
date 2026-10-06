import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/firestore_pagination.dart';
import '../models/journal_entry.dart';

/// Journal service — Memos + DailyTxT inspired.
///
/// Collection: journal_entries (couple-only, see firestore.rules)
class JournalService {
  static JournalService? _instance;
  factory JournalService({FirebaseFirestore? db}) => db == null
      ? _instance ??= JournalService._internal()
      : JournalService._internal(db);
  JournalService._internal([this._customDb]);

  final FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  final String _collection = 'journal_entries';

  Stream<List<JournalEntry>> watchAll() {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoJournalEntries);
    }

    Stream<List<JournalEntry>> subscribe() {
      return _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map((snap) {
            final out = <JournalEntry>[];
            for (final d in snap.docs) {
              try {
                out.add(JournalEntry.fromFirestore(d));
              } catch (e) {
                Logger.e('Journal: skipping malformed entry ${d.id}', error: e);
              }
            }
            return out;
          });
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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return const FirestorePage(items: [], nextCursor: null);
    }

    final snap = await withGetTimeout(
      _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .startAfter([Timestamp.fromDate(date)])
          .limit(limit)
          .get(),
      label: 'journal older entries',
    );
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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Future.value(
        FirestorePage(
          items: AgentFixtures.demoJournalEntries.take(limit).toList(),
          nextCursor: null,
        ),
      );
    }

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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(
        AgentFixtures.demoJournalEntries.take(limit).toList(),
      );
    }

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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(
        AgentFixtures.demoJournalEntries.where((e) => e.isPinned).toList(),
      );
    }

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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(
        AgentFixtures.demoJournalEntries
            .where((e) => e.category == cat)
            .toList(),
      );
    }

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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(
        AgentFixtures.demoJournalEntries
            .where((e) => e.author.toLowerCase() == author.toLowerCase())
            .toList(),
      );
    }

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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      final q = query.toLowerCase().trim();
      return AgentFixtures.demoJournalEntries
          .where(
            (e) =>
                e.title.toLowerCase().contains(q) ||
                e.content.toLowerCase().contains(q) ||
                e.tags.any((t) => t.toLowerCase().contains(q)) ||
                e.category.name.contains(q),
          )
          .toList();
    }

    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final snap = await withGetTimeout(
      _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(80)
          .get(),
      label: 'journal search',
    );
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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return const [];
    }

    final now = DateTime.now();
    final md =
        '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      final snap = await withGetTimeout(
        _db
            .collection(_collection)
            .where('monthDay', isEqualTo: md)
            .limit(50)
            .get(),
        label: 'journal on-this-day',
      );
      final entries = snap.docs
          .map((d) => JournalEntry.fromFirestore(d))
          .where((e) => e.createdAt.year != now.year)
          .toList();
      if (entries.isNotEmpty) return entries;
      // Fallback: client filter
      final fallback = await withGetTimeout(
        _db
            .collection(_collection)
            .orderBy('createdAt', descending: true)
            .limit(200)
            .get(),
        label: 'journal on-this-day fallback',
      );
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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      Logger.i('Agent session simulated journal add: ${entry.title}');
      return;
    }

    try {
      await _db.collection(_collection).add(entry.toFirestore());
      Logger.i('Journal added: ${entry.title}');
    } catch (e) {
      Logger.e('Error adding journal', error: e);
      rethrow;
    }
  }

  Future<void> update(JournalEntry entry) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      Logger.i('Agent session simulated journal update: ${entry.id}');
      return;
    }

    try {
      await _db.collection(_collection).doc(entry.id).update({
        ...entry.toFirestore(),
        'updatedAt': Timestamp.now(),
      });
      Logger.i('Journal updated: ${entry.id}');
    } catch (e) {
      Logger.e('Error updating journal', error: e);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      Logger.i('Agent session simulated journal delete: $id');
      return;
    }

    try {
      await _db.collection(_collection).doc(id).delete();
      Logger.i('Journal deleted: $id');
    } catch (e) {
      Logger.e('Error deleting journal', error: e);
      rethrow;
    }
  }

  Future<void> togglePin(String id, bool pinned) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      Logger.i('Agent session simulated toggle pin: $id -> $pinned');
      return;
    }

    try {
      await _db.collection(_collection).doc(id).update({
        'isPinned': pinned,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      Logger.e('Error toggling pin', error: e);
      rethrow;
    }
  }

  @visibleForTesting
  static Map<String, dynamic> buildToggleLockPayload(
    bool locked, {
    Timestamp? timestamp,
  }) {
    return {'isLocked': locked, 'updatedAt': timestamp ?? Timestamp.now()};
  }

  Future<void> toggleLock(String id, bool locked) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      Logger.i('Agent session simulated toggle lock: $id -> $locked');
      return;
    }

    try {
      await _db
          .collection(_collection)
          .doc(id)
          .update(buildToggleLockPayload(locked));
      Logger.i('Journal lock toggled: $id -> $locked');
    } catch (e) {
      Logger.e('Error toggling lock', error: e);
      rethrow;
    }
  }
}
