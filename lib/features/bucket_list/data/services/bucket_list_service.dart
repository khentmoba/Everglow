import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/core/utils/firestore_stream_utils.dart';
import '../models/bucket_item.dart';

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
          .map((snapshot) =>
              snapshot.docs.map((doc) => BucketItem.fromFirestore(doc)).toList()),
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
          .map((snapshot) =>
              snapshot.docs.map((doc) => BucketItem.fromFirestore(doc)).toList()),
      label: 'bucket-list-${status.name}',
    );
  }

  /// Add a new bucket list item.
  Future<void> add(BucketItem item) async {
    try {
      await _db.collection(_collection).add(item.toFirestore());
      print('Added bucket item: ${item.title}');
    } catch (e) {
      print('Error adding bucket item: $e');
    }
  }

  /// Update an existing bucket list item.
  Future<void> update(BucketItem item) async {
    try {
      await _db.collection(_collection).doc(item.id).update(item.toFirestore());
      print('Updated bucket item: ${item.id}');
    } catch (e) {
      print('Error updating bucket item: $e');
    }
  }

  /// Delete a bucket list item.
  Future<void> delete(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      print('Deleted bucket item: $id');
    } catch (e) {
      print('Error deleting bucket item: $e');
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
      print('Marked bucket item $id as completed by $completedBy');
    } catch (e) {
      print('Error completing bucket item: $e');
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
      print('Marked bucket item $id as uncomplete');
    } catch (e) {
      print('Error uncompleting bucket item: $e');
    }
  }

  /// Mark an item as planned.
  Future<void> markPlanned(String id) async {
    try {
      await _db.collection(_collection).doc(id).update({
        'status': BucketStatus.planned.name,
      });
      print('Marked bucket item $id as planned');
    } catch (e) {
      print('Error marking bucket item as planned: $e');
    }
  }
}
