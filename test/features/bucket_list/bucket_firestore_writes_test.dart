import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/bucket_list/data/models/bucket_item.dart';
import 'package:everglow/features/bucket_list/data/services/bucket_list_service.dart';

BucketItem _item({String id = 'b1', BucketStatus status = BucketStatus.wish}) =>
    BucketItem(
      id: id,
      title: 'See the northern lights',
      category: BucketCategory.travel,
      status: status,
      createdBy: 'khentsgdz',
      createdAt: DateTime.utc(2026, 9, 1),
      priority: BucketPriority.high,
      assignedTo: 'clairjassen',
      dueDate: DateTime.utc(2030, 12, 20),
    );

void main() {
  group('BucketListService Firestore write payloads', () {
    final ts = Timestamp.fromDate(DateTime.utc(2026, 9, 21, 12));

    test('add serializes every field a wish needs', () {
      final map = _item().toFirestore();

      expect(map['title'], 'See the northern lights');
      expect(map['category'], 'travel');
      expect(map['status'], 'wish');
      expect(map['createdBy'], 'khentsgdz');
      expect(map['createdAt'], Timestamp.fromDate(DateTime.utc(2026, 9, 1)));
      expect(map['priority'], 'high');
      expect(map['assignedTo'], 'clairjassen');
      expect(map['dueDate'], Timestamp.fromDate(DateTime.utc(2030, 12, 20)));
      expect(map['notes'], '');
      expect(map['description'], '');
      // Null completion fields must be absent (never written as null).
      expect(map.containsKey('completedAt'), isFalse);
      expect(map.containsKey('completedBy'), isFalse);
    });

    test('markComplete writes status, completer and timestamp together', () {
      final map =
          BucketListService.buildMarkCompletePayload('clair', timestamp: ts);

      expect(map['status'], 'completed');
      expect(map['completedBy'], 'clair');
      expect(map['completedAt'], ts);
      expect(map.keys, containsAll(['status', 'completedBy', 'completedAt']));
    });

    test(
      'markUncomplete DELETES completion fields so stale metadata never '
      'survives a wish reset',
      () {
        final map = BucketListService.buildMarkUncompletePayload();

        expect(map['status'], 'wish');
        // Deleting (not setting null) is what actually clears the fields in
        // Firestore — a null value would break fromFirestore round-trips.
        expect(map['completedAt'], isA<FieldValue>());
        expect(map['completedBy'], isA<FieldValue>());
      },
    );

    test('moveStatus to completed stamps completer and timestamp', () {
      final map = BucketListService.buildMoveStatusPayload(
        BucketStatus.completed,
        completedBy: 'khent',
        timestamp: ts,
      );

      expect(map['status'], 'completed');
      expect(map['completedAt'], ts);
      expect(map['completedBy'], 'khent');
    });

    test('moveStatus to completed omits completer when not provided', () {
      final map = BucketListService.buildMoveStatusPayload(
        BucketStatus.completed,
        timestamp: ts,
      );

      expect(map['status'], 'completed');
      expect(map.containsKey('completedBy'), isFalse);
      expect(map['completedAt'], ts);
    });

    test('moveStatus away from completed wipes completion metadata', () {
      for (final status in [
        BucketStatus.wish,
        BucketStatus.planned,
      ]) {
        final map = BucketListService.buildMoveStatusPayload(status);

        expect(map['status'], status.name);
        expect(map['completedAt'], isA<FieldValue>());
        expect(map['completedBy'], isA<FieldValue>());
      }
    });

    test('assign writes username or deletes the field when unassigned', () {
      expect(
        BucketListService.buildAssignPayload('clairjassen'),
        {'assignedTo': 'clairjassen'},
      );
      final cleared = BucketListService.buildAssignPayload(null);
      expect(cleared['assignedTo'], isA<FieldValue>());
    });

    test('setDueDate writes a Timestamp or deletes the field when cleared', () {
      final due = DateTime.utc(2030, 12, 20);
      expect(
        BucketListService.buildSetDueDatePayload(due)['dueDate'],
        Timestamp.fromDate(due),
      );
      final cleared = BucketListService.buildSetDueDatePayload(null);
      expect(cleared['dueDate'], isA<FieldValue>());
    });
  });

  group('BucketItem Firestore round-trip (couple data survives a write)', () {
    test('toFirestore -> fromMap keeps every persisted field', () {
      final original = _item().copyWith(
        status: BucketStatus.completed,
        completedAt: DateTime.utc(2026, 9, 20),
        completedBy: 'clair',
        notes: 'Booked for December!',
        description: 'Our dream trip',
      );

      final map = original.toFirestore();
      final round = BucketItem.fromMap(map, original.id);

      expect(round.id, original.id);
      expect(round.title, original.title);
      expect(round.description, 'Our dream trip');
      expect(round.category, original.category);
      expect(round.status, BucketStatus.completed);
      expect(round.createdBy, original.createdBy);
      // Timestamp round-trips come back as local-zone DateTimes at the same
      // instant; compare instants, not zone labels.
      expect(
        round.createdAt.toUtc(),
        original.createdAt.toUtc(),
      );
      expect(
        round.completedAt?.toUtc(),
        DateTime.utc(2026, 9, 20),
      );
      expect(round.completedBy, 'clair');
      expect(round.notes, 'Booked for December!');
      expect(round.priority, original.priority);
      expect(round.assignedTo, 'clairjassen');
      expect(
        round.dueDate?.toUtc(),
        DateTime.utc(2030, 12, 20),
      );
    });

    test('fromMap tolerates missing and odd-typed fields without crashing', () {
      final item = BucketItem.fromMap({
        'title': 42,
        'description': ['x'],
        'category': 'not-a-category',
        'status': 7,
        'createdBy': null,
        'priority': 'banana',
        'assignedTo': 99,
        'dueDate': 'not-a-timestamp',
      }, 'odd1');

      expect(item.id, 'odd1');
      expect(item.title, isEmpty);
      expect(item.description, isEmpty);
      expect(item.category, BucketCategory.other);
      expect(item.status, BucketStatus.wish);
      expect(item.createdBy, isEmpty);
      expect(item.priority, BucketPriority.medium);
      expect(item.assignedTo, isNull);
      expect(item.dueDate, isNull);
    });
  });
}
