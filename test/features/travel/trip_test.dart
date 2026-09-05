import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/travel/data/models/trip.dart';

Trip _trip() => Trip(
      id: 't1',
      title: 'El Nido Escape',
      description: 'Island hopping',
      startDate: DateTime.utc(2026, 10, 10),
      endDate: DateTime.utc(2026, 10, 12),
      status: TripStatus.upcoming,
      createdBy: 'khent',
      createdAt: DateTime.utc(2026, 9, 1),
      budgetEstimate: 25000,
    );

Trip _statusTrip(TripStatus status) => Trip(
      id: 't2',
      title: 'T',
      startDate: DateTime.utc(2026, 10, 10),
      endDate: DateTime.utc(2026, 10, 10),
      status: status,
      createdBy: 'clair',
      createdAt: DateTime.utc(2026, 9, 1),
    );

void main() {
  group('Trip', () {
    test('days counts both endpoints', () {
      expect(_trip().days, 3);
      expect(_statusTrip(TripStatus.active).days, 1);
    });

    test('isUpcoming covers planning and upcoming only', () {
      expect(_statusTrip(TripStatus.planning).isUpcoming, isTrue);
      expect(_statusTrip(TripStatus.upcoming).isUpcoming, isTrue);
      expect(_statusTrip(TripStatus.active).isUpcoming, isFalse);
      expect(_statusTrip(TripStatus.completed).isUpcoming, isFalse);
    });

    test('toFirestore keeps status name and builds a search key', () {
      final map = _trip().toFirestore();

      expect(map['status'], 'upcoming');
      expect(map['currency'], 'PHP');
      expect(map['budgetEstimate'], 25000);
      expect(map['searchKey'], contains('el nido escape'));
      expect(map['searchKey'], contains('island hopping'));
      expect(map['memberIds'], ['khentsgdz', 'clairjassen']);
    });
  });

  group('TripPin', () {
    test('isVisited follows visitedAt', () {
      const pin = TripPin(
        id: 'p1',
        tripId: 't1',
        title: 'Nacpan',
        lat: 11.1,
        lng: 119.9,
        createdBy: 'clair',
      );

      expect(pin.isVisited, isFalse);
      expect(
        const TripPin(
          id: 'p1',
          tripId: 't1',
          title: 'Nacpan',
          lat: 11.1,
          lng: 119.9,
          visitedAt: null,
          createdBy: 'clair',
        ).isVisited,
        isFalse,
      );
      expect(
        TripPin(
          id: 'p1',
          tripId: 't1',
          title: 'Nacpan',
          lat: 11.1,
          lng: 119.9,
          visitedAt: DateTime.utc(2026, 10, 11),
          createdBy: 'clair',
        ).isVisited,
        isTrue,
      );
    });

    test('toFirestore omits null visitedAt and photoUrl', () {
      final map = const TripPin(
        id: 'p1',
        tripId: 't1',
        title: 'Nacpan',
        lat: 11.1,
        lng: 119.9,
        category: PinCategory.eat,
        createdBy: 'clair',
      ).toFirestore();

      expect(map['category'], 'eat');
      expect(map.containsKey('visitedAt'), isFalse);
      expect(map.containsKey('photoUrl'), isFalse);
    });

    test('every pin category has a distinct emoji', () {
      final seen = <String>{};
      for (final c in PinCategory.values) {
        final pin = TripPin(
          id: 'p',
          tripId: 't',
          title: 'x',
          lat: 0,
          lng: 0,
          category: c,
          createdBy: 'khent',
        );
        expect(pin.emoji, isNotEmpty);
        seen.add(pin.emoji);
      }
      expect(seen.length, PinCategory.values.length);
    });
  });
}

