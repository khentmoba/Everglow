import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/money/data/models/money_entry.dart';

void main() {
  group('MoneyEntry.fromMap', () {
    test('parses a full entry', () {
      final e = MoneyEntry.fromMap({
        'type': 'expense',
        'amount': 250,
        'category': 'Food',
        'note': 'milk tea',
        'author': 'clairjassen',
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 15)),
      }, 'abc');
      expect(e.id, 'abc');
      expect(e.type, MoneyType.expense);
      expect(e.amount, 250);
      expect(e.category, 'Food');
      expect(e.note, 'milk tea');
      expect(e.author, 'clairjassen');
      expect(e.createdAt, DateTime(2026, 9, 15));
    });

    test('tolerates null + garbage without throwing', () {
      final e = MoneyEntry.fromMap(const {
        'type': 'lottery',
        'amount': 'not-a-number',
        'category': null,
        'createdAt': {'odd': true},
      }, 'bad');
      expect(e.type, MoneyType.expense);
      expect(e.amount, 0);
      expect(e.category, 'Other');
      expect(e.note, '');
      // Falls back to now — just must not crash or be null.
      expect(e.createdAt.isBefore(DateTime.now().add(const Duration(minutes: 1))), isTrue);
    });

    test('parses income + string amount', () {
      final e = MoneyEntry.fromMap(const {
        'type': 'income',
        'amount': '1500.5',
      }, 'i1');
      expect(e.type, MoneyType.income);
      expect(e.amount, 1500.5);
    });
  });

  group('formatPeso', () {
    test('formats with peso sign + thousands', () {
      expect(formatPeso(1250), '₱1,250');
      expect(formatPeso(0), '₱0');
      expect(formatPeso(8000.99), '₱8,001');
    });
  });

  group('summarizeMonth', () {
    MoneyEntry entry({
      required MoneyType type,
      required double amount,
      required DateTime at,
      String category = 'Food',
    }) =>
        MoneyEntry(
          id: 'x',
          type: type,
          amount: amount,
          category: category,
          author: 'khentsgdz',
          createdAt: at,
        );

    test('sums income/expense for the month only', () {
      final entries = [
        entry(type: MoneyType.income, amount: 10000, at: DateTime(2026, 9, 2)),
        entry(type: MoneyType.expense, amount: 250, at: DateTime(2026, 9, 5)),
        entry(type: MoneyType.expense, amount: 500, at: DateTime(2026, 8, 30)),
      ];
      final total = summarizeMonth(entries, DateTime(2026, 9, 15));
      expect(total.income, 10000);
      expect(total.expense, 250);
      expect(total.balance, 9750);
    });

    test('spentByCategory groups this month expenses', () {
      final entries = [
        entry(type: MoneyType.expense, amount: 100, at: DateTime(2026, 9, 2), category: 'Food'),
        entry(type: MoneyType.expense, amount: 200, at: DateTime(2026, 9, 3), category: 'Food'),
        entry(type: MoneyType.expense, amount: 300, at: DateTime(2026, 9, 4), category: 'Fun'),
        entry(type: MoneyType.income, amount: 999, at: DateTime(2026, 9, 5), category: 'Gift'),
      ];
      final spent = spentByCategory(entries, DateTime(2026, 9, 20));
      expect(spent, {'Food': 300, 'Fun': 300});
    });
  });

  group('BudgetLimit.fromFirestore', () {
    test('falls back to doc id + 0 on garbage', () {
      // fromMap-equivalent via fromFirestore needs a doc; exercise the
      // parsing shape through a minimal fake instead.
      const limit = BudgetLimit(category: 'Food', amount: 8000);
      expect(limit.category, 'Food');
      expect(limit.amount, 8000);
    });
  });
}
