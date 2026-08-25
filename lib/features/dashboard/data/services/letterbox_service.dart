import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../domain/models/hidden_note.dart';
import '../../../../core/utils/logger.dart';

class LetterboxService {
  static final LetterboxService _instance = LetterboxService._internal();
  factory LetterboxService() => _instance;
  LetterboxService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of all notes, shared globally, ordered by unlock date.
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
          .map((snapshot) {
            final out = <HiddenNote>[];
            for (final doc in snapshot.docs) {
              try {
                out.add(HiddenNote.fromFirestore(doc));
              } catch (e) {
                Logger.e('Letterbox: skipping malformed note ${doc.id}', error: e);
              }
            }
            return out;
          }),
      label: 'letterbox-notes',
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