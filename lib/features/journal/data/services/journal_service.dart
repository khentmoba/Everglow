import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'dart:async';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/firestore_pagination.dart';
import '../models/journal_entry.dart';

/// Journal service — Memos + DailyTxT inspired.
///
/// Collection: journal_entries (couple-only, see firestore.rules)
class JournalEditConflict implements Exception {
  const JournalEditConflict();
}

class JournalService {
  static JournalService? _instance;
  factory JournalService({FirebaseFirestore? db}) => db == null
      ? _instance ??= JournalService._internal()
      : JournalService._internal(db);
  JournalService._internal([this._customDb]);

  final FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  final String _collection = 'journal_entries';
  final Map<String, JournalEntry> _demoMemories = {};
  final _demoChanges = StreamController<void>.broadcast();

  Stream<JournalEntry?> watchEntry(JournalEntry initial) {
    if (AgentMode.isActive.value) return _watchDemoEntry(initial);
    return _db
        .collection(_collection)
        .doc(initial.id)
        .snapshots()
        .map((doc) => doc.exists ? JournalEntry.fromFirestore(doc) : null);
  }

  Stream<JournalEntry?> _watchDemoEntry(JournalEntry initial) async* {
    yield _demoMemories[initial.id] ?? initial;
    yield* _demoChanges.stream.map((_) => _demoMemories[initial.id] ?? initial);
  }

  Future<JournalEntry> memoryForSource({
    required String title,
    required String author,
    required DateTime date,
    String? bucketItemId,
    String? calendarEventId,
    String? photoId,
  }) async {
    final source = bucketItemId != null
        ? 'bucket_$bucketItemId'
        : calendarEventId != null
        ? 'event_$calendarEventId'
        : 'photo_$photoId';
    final id = 'memory_$source';
    if (photoId != null && !AgentMode.isActive.value) {
      final linked = await withGetTimeout(
        _db
            .collection(_collection)
            .where('photoIds', arrayContains: photoId)
            .limit(1)
            .get(),
        label: 'photo memory lookup',
      );
      if (linked.docs.isNotEmpty) {
        return JournalEntry.fromFirestore(linked.docs.first);
      }
    }
    final now = DateTime.now();
    final entry = JournalEntry(
      id: id,
      title: title,
      content: '',
      author: author,
      createdAt: date.isAfter(now) ? now : date,
      updatedAt: now,
      category: JournalCategory.memory,
      bucketItemId: bucketItemId,
      calendarEventId: calendarEventId,
      photoIds: photoId == null ? const [] : [photoId],
    );
    if (AgentMode.isActive.value) {
      return _demoMemories.putIfAbsent(id, () => entry);
    }
    try {
      final ref = _db.collection(_collection).doc(id);
      return await _db.runTransaction((tx) async {
        final current = await tx.get(ref);
        if (current.exists) {
          final saved = JournalEntry.fromFirestore(current);
          if (calendarEventId != null && saved.calendarEventId == null) {
            tx.update(ref, {'calendarEventId': calendarEventId});
            return JournalEntry.fromMap({
              ...saved.toFirestore(),
              'calendarEventId': calendarEventId,
            }, id);
          }
          return saved;
        }
        tx.set(ref, entry.toFirestore());
        return entry;
      });
    } catch (e) {
      Logger.e('Could not open shared memory', error: e);
      rethrow;
    }
  }

  Future<void> savePerspective(String id, String username, String words) async {
    if (!{'khentsgdz', 'clairjassen'}.contains(username) ||
        words.length > 1000) {
      throw ArgumentError('Invalid memory contribution');
    }
    if (AgentMode.isActive.value) {
      final entry =
          _demoMemories[id] ??
          AgentFixtures.demoJournalEntries.firstWhere((e) => e.id == id);
      _demoMemories[id] = JournalEntry.fromMap({
        ...entry.toFirestore(),
        'perspectives': {...entry.perspectives, username: words.trim()},
      }, id);
      _demoChanges.add(null);
      return;
    }
    try {
      await _db.collection(_collection).doc(id).update({
        'perspectives.$username': words.trim(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      Logger.e('Could not save memory contribution', error: e);
      rethrow;
    }
  }

  Future<void> setMemoryPhotos(String id, List<String> photoIds) async {
    if (photoIds.length > 20) throw ArgumentError('Up to 20 photos per memory');
    if (AgentMode.isActive.value) {
      final entry =
          _demoMemories[id] ??
          AgentFixtures.demoJournalEntries.firstWhere((e) => e.id == id);
      _demoMemories[id] = JournalEntry.fromMap({
        ...entry.toFirestore(),
        'photoIds': photoIds.toSet().toList(),
      }, id);
      _demoChanges.add(null);
      return;
    }
    try {
      await _db.collection(_collection).doc(id).update({
        'photoIds': photoIds.toSet().toList(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      Logger.e('Could not link memory photos', error: e);
      rethrow;
    }
  }

  Future<void> addMemoryPhoto(String id, String photoId) async {
    if (AgentMode.isActive.value) {
      final entry =
          _demoMemories[id] ??
          AgentFixtures.demoJournalEntries.firstWhere((e) => e.id == id);
      return setMemoryPhotos(id, {...entry.photoIds, photoId}.toList());
    }
    try {
      final ref = _db.collection(_collection).doc(id);
      await _db.runTransaction((tx) async {
        final doc = await tx.get(ref);
        if (!doc.exists) throw StateError('Memory no longer exists');
        final photos = {...JournalEntry.fromFirestore(doc).photoIds, photoId};
        if (photos.length > 20) {
          throw StateError('Memory already has 20 photos');
        }
        tx.update(ref, {
          'photoIds': photos.toList(),
          'updatedAt': Timestamp.now(),
        });
      });
    } catch (e) {
      Logger.e('Could not add memory photo', error: e);
      rethrow;
    }
  }

  Stream<List<JournalEntry>> watchAll() {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoJournalEntries);
    }

    Stream<List<JournalEntry>> subscribe() {
      return _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(100)
          // Metadata changes flip an entry from "syncing" to synced.
          .snapshots(includeMetadataChanges: true)
          .map((snap) {
            final out = <JournalEntry>[];
            for (final d in snap.docs) {
              try {
                out.add(
                  JournalEntry.fromMap(
                    d.data(),
                    d.id,
                    isSyncing: d.metadata.hasPendingWrites,
                  ),
                );
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
    final matches = <JournalEntry>[];
    DocumentSnapshot? cursor;
    do {
      final page = await fetchPage(cursor: cursor, limit: 80);
      matches.addAll(
        page.items.where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.content.toLowerCase().contains(q) ||
              e.tags.any((t) => t.toLowerCase().contains(q)) ||
              e.category.name.contains(q),
        ),
      );
      cursor = page.nextCursor;
    } while (cursor != null);
    return matches;
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

  /// A fresh id for a new entry, so retrying a save rewrites the same
  /// document instead of creating a duplicate.
  String newEntryId() => AgentMode.isActive.value && AgentMode.useDemoData.value
      ? 'demo-${DateTime.now().microsecondsSinceEpoch}'
      : _db.collection(_collection).doc().id;

  Future<void> add(JournalEntry entry, {String? id}) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      Logger.i('Agent session simulated journal add: ${entry.title}');
      return;
    }

    try {
      if (id == null) {
        await _db.collection(_collection).add(entry.toFirestore());
      } else {
        await _db.collection(_collection).doc(id).set(entry.toFirestore());
      }
      Logger.i('Journal added: ${entry.title}');
    } catch (e) {
      Logger.e('Error adding journal', error: e);
      rethrow;
    }
  }

  Future<JournalEntry> get(String id) async {
    final snapshot = await _db.collection(_collection).doc(id).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw StateError('Journal entry $id no longer exists');
    }
    return JournalEntry.fromMap(data, id);
  }

  Future<void> update(
    JournalEntry entry, {
    required JournalEntry original,
  }) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      Logger.i('Agent session simulated journal update: ${entry.id}');
      return;
    }

    final changes = <String, dynamic>{};
    if (entry.title != original.title) changes['title'] = entry.title;
    if (entry.content != original.content) changes['content'] = entry.content;
    if (!_sameDate(entry.createdAt, original.createdAt)) {
      changes['createdAt'] = Timestamp.fromDate(entry.createdAt);
      changes['monthDay'] = _monthDay(entry.createdAt);
    }
    if (entry.category != original.category) {
      changes['category'] = entry.category.name;
    }
    if (entry.mood != original.mood) {
      changes['mood'] = entry.mood?.key ?? FieldValue.delete();
    }
    if (!_sameStrings(entry.tags, original.tags)) changes['tags'] = entry.tags;
    if (entry.isPinned != original.isPinned) {
      changes['isPinned'] = entry.isPinned;
    }
    if (entry.isLocked != original.isLocked) {
      changes['isLocked'] = entry.isLocked;
    }
    if (entry.coverColor != original.coverColor) {
      changes['coverColor'] = entry.coverColor ?? FieldValue.delete();
    }
    if (entry.wordCount != original.wordCount ||
        entry.content != original.content) {
      changes['wordCount'] = entry.wordCount;
    }
    if (changes.isEmpty) return;

    try {
      final ref = _db.collection(_collection).doc(entry.id);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw StateError('Journal entry ${entry.id} no longer exists');
        }
        final currentTitle = data['title'] is String
            ? data['title'] as String
            : '';
        final currentContent = data['content'] is String
            ? data['content'] as String
            : '';
        if (changes.containsKey('title') && currentTitle != original.title) {
          throw const JournalEditConflict();
        }
        if (changes.containsKey('content') &&
            currentContent != original.content) {
          throw const JournalEditConflict();
        }

        final patch = Map<String, dynamic>.of(changes)
          ..['updatedAt'] = Timestamp.fromDate(entry.updatedAt);
        if (changes.containsKey('title') || changes.containsKey('content')) {
          final title = changes['title'] as String? ?? currentTitle;
          final content = changes['content'] as String? ?? currentContent;
          patch['searchKey'] =
              '$title ${content.substring(0, content.length > 500 ? 500 : content.length)}'
                  .toLowerCase();
        }
        transaction.update(ref, patch);
      });
      Logger.i('Journal updated: ${entry.id}');
    } catch (e) {
      Logger.e('Error updating journal', error: e);
      rethrow;
    }
  }

  static bool _sameDate(DateTime a, DateTime b) => a.isAtSameMomentAs(b);

  static bool _sameStrings(List<String> a, List<String> b) =>
      a.length == b.length && a.indexed.every((pair) => pair.$2 == b[pair.$1]);

  static String _monthDay(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
