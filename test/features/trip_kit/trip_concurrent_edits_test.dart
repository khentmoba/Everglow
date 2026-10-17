import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/trip_kit/data/models/trip.dart';
import 'package:everglow/features/trip_kit/data/services/trip_kit_service.dart';
import '../../support/transaction_test_fakes.dart';

Map<String, dynamic> _tripData({
  List<Map<String, dynamic>> packing = const [],
}) => {
  'title': 'Demo trip',
  'packing': packing,
  'expenses': <Map<String, dynamic>>[],
  'places': <Map<String, dynamic>>[],
  'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
};

void main() {
  test(
    'adding a packing item retries against and keeps the latest list',
    () async {
      final db = TransactionFirestore(_tripData());
      final service = TripKitService(db: db);
      db.beforeCommit = () {
        db.data!['packing'] = [
          {'id': 'remote', 'label': 'Remote item', 'packed': false},
        ];
        db.revision++;
      };

      await service.addPackingItem(
        'trip',
        const TripPackItem(id: 'local', label: 'Local item'),
      );

      final items = Trip.fromMap(db.data!, 'trip').packing;
      expect(items.map((e) => e.id), unorderedEquals(['remote', 'local']));
      expect(db.retries, 1);
    },
  );

  test('checking a place updates its ID in the latest list', () async {
    final db = TransactionFirestore(
      _tripData(
          packing: [
            {'id': 'pack-1', 'label': 'Bag', 'packed': false},
          ],
        )
        ..['places'] = [
          {'id': 'place-1', 'name': 'Waterfall', 'note': '', 'done': false},
        ],
    );
    final service = TripKitService(db: db);
    db.beforeCommit = () {
      final current = db.data!['places'] as List;
      db.data!['places'] = [
        ...current,
        {'id': 'place-2', 'name': 'Cafe', 'note': '', 'done': false},
      ];
      db.revision++;
    };

    await service.setPlaceDone('trip', 'place-1', true);

    final places = Trip.fromMap(db.data!, 'trip').places;
    expect(places.firstWhere((e) => e.id == 'place-1').done, isTrue);
    expect(places.map((e) => e.id), unorderedEquals(['place-1', 'place-2']));
    expect(db.retries, 1);
  });

  test('failed list writes propagate so the UI can keep its draft', () async {
    final service = TripKitService(db: TransactionFirestore());
    await expectLater(
      service.addPackingItem(
        'missing',
        const TripPackItem(id: 'p1', label: 'Sunscreen'),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
