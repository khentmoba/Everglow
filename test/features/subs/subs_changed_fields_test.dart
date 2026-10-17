import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/subs/data/models/subscription.dart';
import 'package:everglow/features/subs/data/services/subs_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/transaction_test_fakes.dart';

void main() {
  test('editing one subscription field keeps newer untouched fields', () async {
    final original = Subscription(
      id: 'sub-1',
      name: 'Netflix',
      price: 549,
      renewalDate: DateTime(2026, 10, 15),
      payer: SubPayer.shared,
      createdBy: 'demo',
      createdAt: DateTime(2026, 1, 1),
    );
    final db = TransactionFirestore(original.toFirestore());
    db.data!['payer'] = 'clair';

    await SubsService(
      db: db,
    ).update(original.copyWith(price: 599), original: original);

    expect(db.data!['price'], 599);
    expect(db.data!['payer'], 'clair');
    expect(db.data!['name'], 'Netflix');
    expect((db.data!['createdAt'] as Timestamp).toDate(), DateTime(2026, 1, 1));
  });
}
