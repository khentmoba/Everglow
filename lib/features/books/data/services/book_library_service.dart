import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/book_item.dart';

/// Z-Lib style personal library: per-user favorites and a download
/// history. Both collections are couple-only in `firestore.rules`,
/// mirroring `read_list`. Breyan / Octagram never see these.
class BookLibraryService {
  BookLibraryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static bool isCoupleUser(String userName) =>
      userName == 'khentsgdz' || userName == 'clairjassen';

  // ── FAVORITES ──────────────────────────────────────────────────────

  /// Heart a book. Idempotent: re-tapping keeps a single document.
  Future<void> addFavorite(BookItem item, String userName) async {
    if (!isCoupleUser(userName)) {
      Logger.w('addFavorite refused: $userName is not a couple user');
      return;
    }
    try {
      final collection = _firestore.collection('book_favorites');
      final existing = await withGetTimeout(
        collection
            .where('workKey', isEqualTo: item.workKey)
            .where('userName', isEqualTo: userName)
            .limit(1)
            .get(),
        label: 'book favorite lookup',
      );
      if (existing.docs.isNotEmpty) return;
      await collection.add(
        item.copyWith(status: 'favorite', userName: userName).toFirestore(),
      );
      Logger.i('Favorited book: ${item.title} ($userName)');
    } catch (e) {
      Logger.e('Error adding book favorite', error: e);
      rethrow;
    }
  }

  Future<void> removeFavorite(String workKey, String userName) async {
    if (userName.isEmpty) return;
    try {
      final collection = _firestore.collection('book_favorites');
      final existing = await withGetTimeout(
        collection
            .where('workKey', isEqualTo: workKey)
            .where('userName', isEqualTo: userName)
            .limit(1)
            .get(),
        label: 'book favorite remove lookup',
      );
      for (final doc in existing.docs) {
        await collection.doc(doc.id).delete();
      }
    } catch (e) {
      Logger.e('Error removing book favorite', error: e);
      rethrow;
    }
  }

  Stream<List<BookItem>> getFavoritesStream(String userName, {int? limit}) {
    return withFirestoreTimeout(
      _firestore
          .collection('book_favorites')
          .where('userName', isEqualTo: userName)
          .limit(limit ?? 500)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => BookItem.fromFirestore(doc.data(), doc.id))
                    .toList()
                  ..sort((a, b) => b.addedAt.compareTo(a.addedAt)),
          ),
      label: 'book-favorites-$userName',
    );
  }

  // ── DOWNLOAD HISTORY ───────────────────────────────────────────────

  /// Log a download. One document per (book, format) so re-downloads
  /// refresh the timestamp instead of spamming the list.
  Future<void> logDownload(
    BookItem item,
    String userName, {
    String format = '',
  }) async {
    if (!isCoupleUser(userName)) return;
    try {
      final collection = _firestore.collection('book_download_history');
      final existing = await withGetTimeout(
        collection
            .where('workKey', isEqualTo: item.workKey)
            .where('userName', isEqualTo: userName)
            .where('format', isEqualTo: format)
            .limit(1)
            .get(),
        label: 'book download lookup',
      );
      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).update({
          'addedAt': Timestamp.now(),
        });
        return;
      }
      final data = item
          .copyWith(status: 'downloaded', userName: userName)
          .toFirestore();
      data['format'] = format;
      await collection.add(data);
    } catch (e) {
      Logger.e('Error logging book download', error: e);
      rethrow;
    }
  }

  Stream<List<BookItem>> getDownloadHistoryStream(
    String userName, {
    int? limit,
  }) {
    return withFirestoreTimeout(
      _firestore
          .collection('book_download_history')
          .where('userName', isEqualTo: userName)
          .limit(limit ?? 200)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => BookItem.fromFirestore(doc.data(), doc.id))
                    .toList()
                  ..sort((a, b) => b.addedAt.compareTo(a.addedAt)),
          ),
      label: 'book-download-history-$userName',
    );
  }
}
