import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/core/utils/firestore_stream_utils.dart';
import '../models/bucket_item.dart';
import '../../../../core/utils/logger.dart';

/// Service for managing the shared couple bucket list.
class BucketListService {
  static final BucketListService _instance = BucketListService._internal();
  factory BucketListService() => _instance;
  BucketListService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'bucket_list';

  /// All items, newest first.
  Stream<List<BucketItem>> watchAll() {
    return withFirestoreTimeout(
      _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => BucketItem.fromFirestore(doc))
                .toList(),
          ),
      label: 'bucket-list-all',
    );
  }

  /// Items filtered by status.
  Stream<List<BucketItem>> watchByStatus(BucketStatus status) {
    return withFirestoreTimeout(
      _db
          .collection(_collection)
          .where('status', isEqualTo: status.name)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => BucketItem.fromFirestore(doc))
                .toList(),
          ),
      label: 'bucket-list-${status.name}',
    );
  }

  /// Add a new bucket list item.
  Future<void> add(BucketItem item) async {
    try {
      await _db.collection(_collection).add(item.toFirestore());
      Logger.i('Added bucket item: ${item.title}');
    } catch (e) {
      Logger.e('Error adding bucket item', error: e);
    }
  }

  /// Update an existing bucket list item.
  Future<void> update(BucketItem item) async {
    try {
      await _db.collection(_collection).doc(item.id).update(item.toFirestore());
      Logger.i('Updated bucket item: ${item.id}');
    } catch (e) {
      Logger.e('Error updating bucket item', error: e);
    }
  }

  /// Delete a bucket list item.
  Future<void> delete(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      Logger.i('Deleted bucket item: $id');
    } catch (e) {
      Logger.e('Error deleting bucket item', error: e);
    }
  }

  /// Mark an item as completed.
  Future<void> markComplete(String id, String completedBy) async {
    try {
      await _db.collection(_collection).doc(id).update({
        'status': BucketStatus.completed.name,
        'completedAt': Timestamp.now(),
        'completedBy': completedBy,
      });
      Logger.i('Marked bucket item $id as completed by $completedBy');
    } catch (e) {
      Logger.e('Error completing bucket item', error: e);
    }
  }

  /// Mark an item as uncomplete (back to wish).
  Future<void> markUncomplete(String id) async {
    try {
      await _db.collection(_collection).doc(id).update({
        'status': BucketStatus.wish.name,
        'completedAt': FieldValue.delete(),
        'completedBy': FieldValue.delete(),
      });
      Logger.i('Marked bucket item $id as uncomplete');
    } catch (e) {
      Logger.e('Error uncompleting bucket item', error: e);
    }
  }

  /// Mark an item as planned.
  Future<void> markPlanned(String id) async {
    try {
      await _db.collection(_collection).doc(id).update({
        'status': BucketStatus.planned.name,
      });
      Logger.i('Marked bucket item $id as planned');
    } catch (e) {
      Logger.e('Error marking bucket item as planned', error: e);
    }
  }
}
