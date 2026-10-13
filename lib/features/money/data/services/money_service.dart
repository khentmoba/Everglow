import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/money_entry.dart';

/// Shared couple wallet. Collections: `budget_transactions`,
/// `budget_limits` (both couple-only, see firestore.rules).
class MoneyService {
  static final MoneyService _instance = MoneyService._internal();
  factory MoneyService({FirebaseFirestore? db}) =>
      db == null ? _instance : MoneyService._internal(db);
  MoneyService._internal([this._customDb]);

  final FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;

  /// Keep every entry in this month live so totals never silently truncate.
  /// Grow the query only when full; the screen reveals rows in small pages.
  Stream<List<MoneyEntry>> watchMonth(DateTime month) {
    if (AgentMode.isActive.value) {
      return Stream.value(AgentFixtures.demoMoney(month));
    }
    Stream<List<MoneyEntry>> subscribe() async* {
      var limit = 200;
      final query = _db
          .collection('budget_transactions')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime(month.year, month.month),
            ),
          )
          .where(
            'createdAt',
            isLessThan: Timestamp.fromDate(
              DateTime(month.year, month.month + 1),
            ),
          )
          .orderBy('createdAt', descending: true);
      while (true) {
        var needsMore = false;
        await for (final snap in query.limit(limit).snapshots()) {
          if (snap.docs.length == limit) {
            limit *= 2;
            needsMore = true;
            break;
          }
          final out = <MoneyEntry>[];
          for (final d in snap.docs) {
            try {
              out.add(MoneyEntry.fromFirestore(d));
            } catch (e) {
              Logger.e('Money: skipping malformed entry ${d.id}', error: e);
            }
          }
          yield out;
        }
        if (!needsMore) return;
      }
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
    if (AgentMode.isActive.value) {
      return Stream.value(AgentFixtures.demoBudgets);
    }
    return withFirestoreTimeout(
      _db
          .collection('budget_limits')
          .limit(30)
          .snapshots()
          .map((snap) => snap.docs.map(BudgetLimit.fromFirestore).toList()),
      label: 'money-limits',
    );
  }

  Future<void> add(MoneyEntry entry) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection('budget_transactions').add(entry.toFirestore());
      Logger.i('Money added: ${entry.type.name} ${entry.amount}');
    } catch (e) {
      Logger.e('Error adding money entry', error: e);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection('budget_transactions').doc(id).delete();
      Logger.i('Money deleted: $id');
    } catch (e) {
      Logger.e('Error deleting money entry', error: e);
      rethrow;
    }
  }

  /// Set (or overwrite) the monthly cap for [category].
  Future<void> setLimit(String category, double amount) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection('budget_limits').doc(category).set({
        'category': category,
        'amount': amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Logger.i('Money budget set: $category -> $amount');
    } catch (e) {
      Logger.e('Error setting budget limit', error: e);
      rethrow;
    }
  }

  Future<void> removeLimit(String category) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection('budget_limits').doc(category).delete();
      Logger.i('Money budget removed: $category');
    } catch (e) {
      Logger.e('Error removing budget limit', error: e);
      rethrow;
    }
  }
}
