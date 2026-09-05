import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/budget/data/models/budget_transaction.dart';

BudgetTransaction _tx() => BudgetTransaction(
      id: 'x1',
      title: 'Groceries',
      amount: 1000,
      category: 'Food',
      paidBy: 'khent',
      date: DateTime.utc(2026, 9, 5),
    );

void main() {
  group('BudgetTransaction', () {
    test('signedAmount is negative for expenses', () {
      expect(_tx().signedAmount, -1000);
      expect(_tx().copyWith(type: TransactionType.income).signedAmount, 1000);
    });

    test('equal split halves the amount', () {
      final split = _tx().splitAmounts;

      expect(split['khentsgdz'], 500);
      expect(split['clairjassen'], 500);
    });

    test('single-payer splits assign the full amount', () {
      expect(
        _tx().copyWith(split: SplitMode.khent).splitAmounts['khentsgdz'],
        1000,
      );
      expect(
        _tx().copyWith(split: SplitMode.clair).splitAmounts['clairjassen'],
        1000,
      );
      expect(
        _tx().copyWith(split: SplitMode.clair).splitAmounts['khentsgdz'],
        0,
      );
    });

    test('custom split follows ratios and falls back on zero total', () {
      final custom = _tx().copyWith(
        split: SplitMode.custom,
        customSplit: {'khentsgdz': 3, 'clairjassen': 1},
      ).splitAmounts;

      expect(custom['khentsgdz'], 750);
      expect(custom['clairjassen'], 250);

      final fallback = _tx().copyWith(
        split: SplitMode.custom,
        customSplit: {'khentsgdz': 0, 'clairjassen': 0},
      ).splitAmounts;

      expect(fallback['khentsgdz'], 500);
      expect(fallback['clairjassen'], 500);
    });

    test('toFirestore stamps the month key and omits nulls', () {
      final map = _tx().toFirestore();

      expect(map['type'], 'expense');
      expect(map['split'], 'equal');
      expect(map['monthKey'], '2026-09');
      expect(map.containsKey('customSplit'), isFalse);
      expect(map.containsKey('receiptUrl'), isFalse);
    });

    test('monthKeyFor pads single-digit months', () {
      expect(monthKeyFor(DateTime.utc(2026, 9, 5)), '2026-09');
      expect(monthKeyFor(DateTime.utc(2026, 12, 31)), '2026-12');
    });
  });
}
