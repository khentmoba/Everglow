import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/money_entry.dart';

/// Shared couple wallet. Collections: `budget_transactions`,
/// `budget_limits` (both couple-only, see firestore.rules).
class MoneyService {
  static final MoneyService _instance = MoneyService._internal();
  factory MoneyService() => _instance;
  MoneyService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Recent entries, newest first. Monthly math happens client-side so
  /// one stream powers the summary, budgets, and list.
  Stream<List<MoneyEntry>> watchRecent({int limit = 200}) {
    Stream<List<MoneyEntry>> subscribe() {
      return _db
          .collection('budget_transactions')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) {
        final out = <MoneyEntry>[];
        for (final d in snap.docs) {
          try {
            out.add(MoneyEntry.fromFirestore(d));
          } catch (e) {
            Logger.e('Money: skipping malformed entry ${d.id}', error: e);
          }
        }
        return out;
      });
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'money-recent',
      duration: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }

  /// One doc per category with a cap. Small collection, no limit needed
  /// beyond the guard-friendly cap.
  Stream<List<BudgetLimit>> watchLimits() {
    return withFirestoreTimeout(
      _db.collection('budget_limits').limit(30).snapshots().map(
            (snap) => snap.docs.map(BudgetLimit.fromFirestore).toList(),
          ),
      label: 'money-limits',
    );
  }

  Future<void> add(MoneyEntry entry) async {
    try {
      await _db.collection('budget_transactions').add(entry.toFirestore());
      Logger.i('Money added: ${entry.type.name} ${entry.amount}');
    } catch (e) {
      Logger.e('Error adding money entry', error: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _db.collection('budget_transactions').doc(id).delete();
      Logger.i('Money deleted: $id');
    } catch (e) {
      Logger.e('Error deleting money entry', error: e);
    }
  }

  /// Set (or overwrite) the monthly cap for [category].
  Future<void> setLimit(String category, double amount) async {
    try {
      await _db.collection('budget_limits').doc(category).set({
        'category': category,
        'amount': amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Logger.i('Money budget set: $category -> $amount');
    } catch (e) {
      Logger.e('Error setting budget limit', error: e);
    }
  }

  Future<void> removeLimit(String category) async {
    try {
      await _db.collection('budget_limits').doc(category).delete();
      Logger.i('Money budget removed: $category');
    } catch (e) {
      Logger.e('Error removing budget limit', error: e);
    }
  }
}
