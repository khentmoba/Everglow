import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/subscription.dart';

/// Service for the couple's shared subscription tracker.
class SubsService {
  static final SubsService _instance = SubsService._internal();
  factory SubsService() => _instance;
  SubsService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'subscriptions';

  /// All subscriptions, newest first. The screen sorts by next renewal.
  Stream<List<Subscription>> watchAll() {
    Stream<List<Subscription>> subscribe() {
      return _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(Subscription.fromFirestore).toList(),
          );
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'subs-all',
      duration: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }

  /// Add a new subscription.
  Future<void> add(Subscription sub) async {
    try {
      await _db.collection(_collection).add(sub.toFirestore());
      Logger.i('Added subscription: ${sub.name}');
    } catch (e) {
      Logger.e('Error adding subscription', error: e);
    }
  }

  /// Update an existing subscription.
  Future<void> update(Subscription sub) async {
    try {
      await _db.collection(_collection).doc(sub.id).update(sub.toFirestore());
      Logger.i('Updated subscription: ${sub.id}');
    } catch (e) {
      Logger.e('Error updating subscription', error: e);
    }
  }

  /// Delete a subscription.
  Future<void> delete(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      Logger.i('Deleted subscription: $id');
    } catch (e) {
      Logger.e('Error deleting subscription', error: e);
    }
  }
}
