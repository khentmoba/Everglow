import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/budget_transaction.dart';

class BudgetService {
  static final BudgetService _instance = BudgetService._internal();
  factory BudgetService() => _instance;
  BudgetService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _col = 'budget_transactions';
  final String _budgetsCol = 'budget_limits';

  Stream<List<BudgetTransaction>> watchAll() => withFirestoreTimeout(
    _db
        .collection(_col)
        .orderBy('date', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) => s.docs.map((d) => BudgetTransaction.fromFirestore(d)).toList(),
        ),
    label: 'budget-all',
  );

  Stream<List<BudgetTransaction>> watchMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return withFirestoreTimeout(
      _db
          .collection(_col)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (s) =>
                s.docs.map((d) => BudgetTransaction.fromFirestore(d)).toList(),
          ),
      label: 'budget-month',
    );
  }

  // Budget limits (envelopes) per month — Actual-style
  Stream<Map<String, double>> watchBudgetLimits(DateTime month) {
    final key = monthKeyFor(month);
    return withFirestoreTimeout(
      _db
          .collection(_budgetsCol)
          .where('monthKey', isEqualTo: key)
          .snapshots()
          .map((s) {
            final map = <String, double>{};
            for (final d in s.docs) {
              final data = d.data();
              final cat = data['category'] as String? ?? 'Other';
              final amt = (data['amount'] as num?)?.toDouble() ?? 0;
              map[cat] = amt;
            }
            return map;
          }),
      label: 'budget-limits',
    );
  }

  Future<void> setBudgetLimit(
    DateTime month,
    String category,
    double amount,
  ) async {
    final key = monthKeyFor(month);
    final docId = '${key}_$category';
    try {
      if (amount <= 0) {
        await _db.collection(_budgetsCol).doc(docId).delete();
        return;
      }
      await _db.collection(_budgetsCol).doc(docId).set({
        'monthKey': key,
        'category': category,
        'amount': amount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Logger.i('Budget limit set: $category $amount for $key');
    } catch (e) {
      Logger.e('Error setting budget limit', error: e);
    }
  }

  Future<void> add(BudgetTransaction tx) async {
    try {
      await _db.collection(_col).add(tx.toFirestore());
      Logger.i('Budget added: ${tx.title} ${tx.amount}');
    } catch (e) {
      Logger.e('Error adding budget', error: e);
    }
  }

  Future<void> update(String id, BudgetTransaction tx) async {
    try {
      await _db.collection(_col).doc(id).update(tx.toFirestore());
      Logger.i('Budget updated: $id');
    } catch (e) {
      Logger.e('Error updating budget', error: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _db.collection(_col).doc(id).delete();
    } catch (e) {
      Logger.e('Error deleting budget', error: e);
    }
  }

  // IHateMoney compute: net owes
  Map<String, double> computeOwes(List<BudgetTransaction> txs) {
    double khentPaid = 0, clairPaid = 0;
    double khentShare = 0, clairShare = 0;
    for (final t in txs) {
      if (t.type == TransactionType.income) continue;
      final paid = t.amount;
      if (t.paidBy == 'khentsgdz') khentPaid += paid;
      if (t.paidBy == 'clairjassen') clairPaid += paid;
      final split = t.splitAmounts;
      khentShare += split['khentsgdz'] ?? 0;
      clairShare += split['clairjassen'] ?? 0;
    }
    final khentOwes = khentShare - khentPaid;
    final clairOwes = clairShare - clairPaid;
    return {
      'khentsgdz': khentOwes,
      'clairjassen': clairOwes,
      'khentPaid': khentPaid,
      'clairPaid': clairPaid,
      'khentShare': khentShare,
      'clairShare': clairShare,
    };
  }

  Map<String, double> byCategory(List<BudgetTransaction> txs) {
    final map = <String, double>{};
    for (final t in txs) {
      if (t.type == TransactionType.expense) {
        map[t.category] = (map[t.category] ?? 0) + t.amount;
      }
    }
    return map;
  }

  double totalIncome(List<BudgetTransaction> txs) => txs
      .where((t) => t.type == TransactionType.income)
      .fold(0, (a, b) => a + b.amount);

  double totalExpense(List<BudgetTransaction> txs) => txs
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (a, b) => a + b.amount);
}
