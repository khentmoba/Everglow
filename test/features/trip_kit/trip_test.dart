import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/trip_kit/data/models/trip.dart';

void main() {
  group('Trip.fromMap', () {
    test('parses a full trip with all sections', () {
      final trip = Trip.fromMap({
        'title': 'Tagaytay weekend',
        'destination': 'Tagaytay',
        'startDate': Timestamp.fromDate(DateTime(2026, 6, 12)),
        'endDate': Timestamp.fromDate(DateTime(2026, 6, 14)),
        'notes': 'Bring jackets',
        'budgetTotal': 8000,
        'packing': [
          {'id': 'p1', 'label': 'Sunscreen', 'packed': true, 'packedBy': 'clairjassen'},
          {'id': 'p2', 'label': 'Camera', 'packed': false},
        ],
        'expenses': [
          {'id': 'e1', 'label': 'Gas', 'amount': 1500},
        ],
        'places': [
          {'id': 'l1', 'name': 'Sky Ranch', 'note': 'Sunset', 'done': false},
        ],
        'createdBy': 'khentsgdz',
        'createdAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
      }, 'trip-1');

      expect(trip.title, 'Tagaytay weekend');
      expect(trip.packing, hasLength(2));
      expect(trip.packedCount, 1);
      expect(trip.packing.first.packedBy, 'clairjassen');
      expect(trip.expenses, hasLength(1));
      expect(trip.spentTotal, 1500);
      expect(trip.budgetProgress, closeTo(0.1875, 0.001));
      expect(trip.overBudget, isFalse);
      expect(trip.remaining, 6500);
      expect(trip.places.first.note, 'Sunset');
    });

    test('tolerates null + garbage without throwing (crash guard)', () {
      final trip = Trip.fromMap({
        'title': null,
        'destination': 42,
        'startDate': 'not-a-date',
        'budgetTotal': 'lots',
        'packing': 'not-a-list',
        'expenses': [
          {'id': 'e1', 'label': 'Gas', 'amount': 'NaN-amount'},
          'odd-string-entry',
          123,
          {'label': null, 'amount': null},
        ],
        'places': [
          {'name': 7, 'done': 'yes'},
        ],
        'createdBy': null,
        'createdAt': 'someday',
      }, 'odd-trip');

      expect(trip.title, '');
      expect(trip.destination, '');
      expect(trip.startDate, isNull);
      expect(trip.budgetTotal, 0);
      expect(trip.packing, isEmpty);
      // Garbage scalar entries are skipped; maps with bad fields parse to defaults.
      expect(trip.expenses, hasLength(2));
      expect(trip.spentTotal, 0);
      expect(trip.places, hasLength(1));
      expect(trip.places.first.name, '');
      expect(trip.places.first.done, isFalse);
      expect(trip.createdBy, '');
    });

    test('empty map yields a blank trip, never a crash', () {
      final trip = Trip.fromMap(const {}, 'empty');
      expect(trip.title, '');
      expect(trip.packing, isEmpty);
      expect(trip.expenses, isEmpty);
      expect(trip.places, isEmpty);
      expect(trip.budgetProgress, 0);
    });
  });

  group('Trip computed helpers', () {
    test('overBudget flags when spent passes the total', () {
      final trip = Trip(
        id: 't',
        title: 'x',
        budgetTotal: 100,
        expenses: const [
          TripExpense(id: 'e1', label: 'Food', amount: 120),
        ],
        createdBy: 'khentsgdz',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(trip.overBudget, isTrue);
      expect(trip.budgetProgress, 1.0);
      expect(trip.remaining, -20);
    });

    test('toFirestore round-trips the sections', () {
      final trip = Trip(
        id: 't',
        title: 'Batangas',
        destination: 'Batangas',
        notes: 'Beach!',
        budgetTotal: 5000,
        packing: const [TripPackItem(id: 'p1', label: 'Goggles')],
        expenses: const [TripExpense(id: 'e1', label: 'Boat', amount: 2000)],
        places: const [TripPlace(id: 'l1', name: 'Anilao')],
        createdBy: 'khentsgdz',
        createdAt: DateTime(2026, 1, 1),
      );
      final back = Trip.fromMap(trip.toFirestore(), 't');
      expect(back.title, 'Batangas');
      expect(back.packing.first.label, 'Goggles');
      expect(back.expenses.first.amount, 2000);
      expect(back.places.first.name, 'Anilao');
    });

    test('unchecking packing clears packedBy', () {
      const item = TripPackItem(id: 'p1', label: 'x', packed: true, packedBy: 'clairjassen');
      expect(item.copyWith(packed: false).packedBy, isNull);
    });
  });
}
