import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/agent/agent_fixtures.dart';

import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/subscription.dart';

/// Service for the couple's shared subscription tracker.
class SubsService {
  static final SubsService _instance = SubsService._internal();
  factory SubsService({FirebaseFirestore? db}) =>
      db == null ? _instance : SubsService._internal(db);
  SubsService._internal([this._customDb]);

  final FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  final String _collection = 'subscriptions';

  /// All subscriptions, newest first. The screen sorts by next renewal.
  Stream<List<Subscription>> watchAll() {
    if (AgentMode.isActive.value) {
      return Stream.value(AgentFixtures.demoSubscriptions);
    }
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
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection(_collection).add(sub.toFirestore());
      Logger.i('Added subscription: ${sub.name}');
    } catch (e) {
      Logger.e('Error adding subscription', error: e);
      rethrow;
    }
  }

  /// Update an existing subscription.
  Future<void> update(
    Subscription sub, {
    required Subscription original,
  }) async {
    if (AgentMode.isActive.value) return;
    final changes = <String, dynamic>{};
    if (sub.name != original.name) changes['name'] = sub.name;
    if (sub.price != original.price) changes['price'] = sub.price;
    if (sub.renewalDate != original.renewalDate) {
      changes['renewalDate'] = Timestamp.fromDate(sub.renewalDate);
    }
    if (sub.cycle != original.cycle) changes['cycle'] = sub.cycle.name;
    if (sub.payer != original.payer) changes['payer'] = sub.payer.name;
    if (changes.isEmpty) return;
    try {
      await _db.collection(_collection).doc(sub.id).update(changes);
      Logger.i('Updated subscription: ${sub.id}');
    } catch (e) {
      Logger.e('Error updating subscription', error: e);
      rethrow;
    }
  }

  /// Delete a subscription.
  Future<void> delete(String id) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection(_collection).doc(id).delete();
      Logger.i('Deleted subscription: $id');
    } catch (e) {
      Logger.e('Error deleting subscription', error: e);
      rethrow;
    }
  }
}
