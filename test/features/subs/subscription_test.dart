import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/subs/data/models/subscription.dart';

Subscription _sub({
  String name = 'Netflix',
  double price = 549,
  DateTime? renewalDate,
  SubCycle cycle = SubCycle.monthly,
  SubPayer payer = SubPayer.shared,
}) =>
    Subscription(
      id: 's1',
      name: name,
      price: price,
      renewalDate: renewalDate ?? DateTime.utc(2026, 10, 15),
      cycle: cycle,
      payer: payer,
      createdBy: 'khent',
      createdAt: DateTime.utc(2026, 9, 1),
    );

void main() {
  group('Subscription renewal math', () {
    test('future renewal stays as-is', () {
      final sub = _sub(renewalDate: DateTime.utc(2026, 10, 15));
      expect(
        sub.nextRenewal(now: DateTime.utc(2026, 9, 27)),
        DateTime(2026, 10, 15),
      );
      expect(sub.daysUntilRenewal(now: DateTime.utc(2026, 9, 27)), 18);
    });

    test('renewal today counts as today, not next month', () {
      final sub = _sub(renewalDate: DateTime.utc(2026, 9, 27));
      expect(
        sub.nextRenewal(now: DateTime.utc(2026, 9, 27)),
        DateTime(2026, 9, 27),
      );
      expect(sub.daysUntilRenewal(now: DateTime.utc(2026, 9, 27)), 0);
    });

    test('past monthly renewal rolls forward month by month', () {
      final sub = _sub(renewalDate: DateTime.utc(2026, 6, 15));
      expect(
        sub.nextRenewal(now: DateTime.utc(2026, 9, 27)),
        DateTime(2026, 10, 15),
      );
    });

    test('past yearly renewal rolls forward by year', () {
      final sub = _sub(
        renewalDate: DateTime.utc(2024, 3, 10),
        cycle: SubCycle.yearly,
      );
      expect(
        sub.nextRenewal(now: DateTime.utc(2026, 9, 27)),
        DateTime(2027, 3, 10),
      );
    });

    test('month-end renewal clamps instead of overflowing', () {
      // Jan 31 -> Feb would overflow to Mar 3 without clamping.
      final sub = _sub(renewalDate: DateTime.utc(2026, 1, 31));
      expect(
        sub.nextRenewal(now: DateTime.utc(2026, 2, 10)),
        DateTime(2026, 2, 28),
      );
    });

    test('monthlyCost folds yearly prices into a monthly share', () {
      expect(_sub(price: 549).monthlyCost, 549);
      expect(_sub(price: 1200, cycle: SubCycle.yearly).monthlyCost, 100);
    });
  });

  group('Subscription.fromMap tolerates hostile stored data', () {
    test('fromMap survives nulls and wrong types', () {
      final odd = Subscription.fromMap(const {
        'name': 42,
        'price': 'not-a-number',
        'renewalDate': 'yesterday-ish',
        'cycle': 'fortnightly',
        'payer': 'the cat',
        'createdBy': null,
        'createdAt': 12345,
      }, 'odd');
      expect(odd.name, '');
      expect(odd.price, 0);
      expect(odd.cycle, SubCycle.monthly);
      expect(odd.payer, SubPayer.shared);
      expect(odd.createdBy, '');
      // Still computes a renewal instead of throwing.
      expect(odd.daysUntilRenewal() >= 0, isTrue);
    });

    test('fromMap accepts numeric strings and Firestore round-trip', () {
      final fromStrings = Subscription.fromMap({
        'name': 'Spotify',
        'price': '129.5',
        'renewalDate': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
        'cycle': 'monthly',
        'payer': 'clair',
        'createdBy': 'khent',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
      }, 's2');
      expect(fromStrings.price, 129.5);
      expect(fromStrings.payer, SubPayer.clair);

      final roundTrip = Subscription.fromMap(
        _sub().toFirestore(),
        's1',
      );
      expect(roundTrip.name, 'Netflix');
      expect(roundTrip.price, 549);
      expect(roundTrip.cycle, SubCycle.monthly);
    });
  });
}
