import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../domain/models/hidden_note.dart';
import '../../../../core/utils/logger.dart';

class LetterboxService {
  static final LetterboxService _instance = LetterboxService._internal();
  factory LetterboxService() => _instance;
  LetterboxService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // In-memory cache shared by the dashboard rail and the archive screen.
  // Lets a revisit (or rail -> View All) paint instantly while the live
  // stream revalidates in the background (stale-while-revalidate).
  List<HiddenNote> _cachedNotes = const [];
  List<HiddenNote> get cachedNotes => _cachedNotes;

  List<HiddenNote> _mapSnapshot(QuerySnapshot snapshot) {
    final out = <HiddenNote>[];
    for (final doc in snapshot.docs) {
      try {
        out.add(HiddenNote.fromFirestore(doc));
      } catch (e) {
        Logger.e('Letterbox: skipping malformed note ${doc.id}', error: e);
      }
    }
    _cachedNotes = List.unmodifiable(out);
    return _cachedNotes;
  }

  // Full stream of all notes, shared globally, ordered by unlock date.
  // Used by the archive screen (needs everything for search/filter).
  // Wrapped with timeout so UI never hangs on web navigation.
  // Individual doc parse errors are swallowed so one malformed letter
  // does not kill the entire rail (the bug that left Letterbox empty
  // after a bad write).
  Stream<List<HiddenNote>> get notes {
    return withFirestoreTimeout(
      _db
          .collection('notes')
          .orderBy('unlockDate', descending: false)
          .snapshots()
          .map(_mapSnapshot),
      label: 'letterbox-notes',
    );
  }

  // Lightweight preview for the dashboard rail. The rail only shows a
  // horizontal strip, so fetching the whole collection wastes a rule
  // `get(/users/{uid})` evaluation per letter plus bandwidth on every
  // dashboard open — the main reason the rail felt slow on cold start.
  Stream<List<HiddenNote>> notesPreview({int limit = 10}) {
    return withFirestoreTimeout(
      _db
          .collection('notes')
          .orderBy('unlockDate', descending: false)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            // Preview must not clobber the full cache when the archive
            // already holds more letters — only widen, never shrink.
            final out = <HiddenNote>[];
            for (final doc in snapshot.docs) {
              try {
                out.add(HiddenNote.fromFirestore(doc));
              } catch (e) {
                Logger.e(
                  'Letterbox: skipping malformed note ${doc.id}',
                  error: e,
                );
              }
            }
            if (out.length >= _cachedNotes.length) {
              _cachedNotes = List.unmodifiable(out);
            }
            return out;
          }),
      label: 'letterbox-notes-preview',
    );
  }

  // Persist read state to Firestore
  Future<void> markAsRead(String noteId) async {
    try {
      await _db.collection('notes').doc(noteId).update({'isRead': true});
      Logger.i("Marked note $noteId as read");
    } catch (e) {
      Logger.e("Error marking note as read", error: e);
    }
  }

  // Optional: helper to add a note (for future admin use)
  Future<void> addNote(HiddenNote note) async {
    try {
      await _db.collection('notes').add(note.toFirestore());
      Logger.i("Added new note to letterbox");
    } catch (e) {
      Logger.e("Error adding note", error: e);
    }
  }

  // Ensure the notes collection has at least one sample note if empty.
  // Unlike seedInitialNotes() this does NOT clear existing data.
  Future<void> ensureSeeded() async {
    try {
      final existing = await _db.collection('notes').limit(1).get();
      if (existing.docs.isNotEmpty) return;
      final data = {
        'title': 'My Favorite Number',
        'content': '1111',
        'unlockDate': Timestamp.fromDate(DateTime.now()),
        'isRead': false,
      };
      await _db.collection('notes').add(data);
      Logger.i('Letterbox: seeded initial sample note');
    } catch (e) {
      // Permission denied for cinema-only users is expected; swallow.
      Logger.e('Letterbox ensureSeeded failed (likely permission)', error: e);
    }
  }

  // Seed the collection with sample data
  Future<void> seedInitialNotes() async {
    // 1. Clear existing notes
    final existingNotes = await _db.collection('notes').get();
    final deleteBatch = _db.batch();
    for (var doc in existingNotes.docs) {
      deleteBatch.delete(doc.reference);
    }
    await deleteBatch.commit();

    // 2. Add the new note
    final data = {
      'title': 'My Favorite Number',
      'content': '1111',
      'unlockDate': Timestamp.fromDate(DateTime.now()),
      'isRead': false,
    };

    await _db.collection('notes').add(data);
  }
}