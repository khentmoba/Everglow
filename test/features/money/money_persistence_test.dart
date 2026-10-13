import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/money/data/services/money_service.dart';
import 'package:everglow/features/money/data/models/money_entry.dart';
import '../../support/firestore_test_fakes.dart';
import '../../support/paged_query_test_fakes.dart';

void main() {
  test(
    'monthly totals include entry 201 and exclude the previous month',
    () async {
      final query = PagedCollection(
        entries: [
          for (var i = 0; i < 201; i++)
            {
              'amount': 10,
              'type': 'expense',
              'category': 'Food',
              'createdAt': Timestamp.fromDate(
                DateTime(2026, 10, 1).add(Duration(minutes: i)),
              ),
            },
          {
            'amount': 9999,
            'createdAt': Timestamp.fromDate(DateTime(2026, 9, 30)),
          },
        ],
      );
      final entries = await MoneyService(
        db: TestFirestore(query),
      ).watchMonth(DateTime(2026, 10)).first;
      expect(entries.length, 201);
      expect(summarizeMonth(entries, DateTime(2026, 10)).expense, 2010);
      expect(query.reads.limits, [200, 400]);
    },
  );

  test('failed money writes report failure to their caller', () async {
    final service = MoneyService(db: TestFirestore(TestCollection()));
    final entry = MoneyEntry(
      id: '',
      type: MoneyType.expense,
      amount: 25,
      category: 'Food',
      author: 'demo',
      createdAt: DateTime(2026, 10),
    );
    await expectLater(service.add(entry), throwsA(isA<FirebaseException>()));
    await expectLater(
      service.delete('demo'),
      throwsA(isA<FirebaseException>()),
    );
    await expectLater(
      service.removeLimit('Food'),
      throwsA(isA<FirebaseException>()),
    );
    await expectLater(
      service.setLimit('Food', 50),
      throwsA(isA<FirebaseException>()),
    );
  });
}
