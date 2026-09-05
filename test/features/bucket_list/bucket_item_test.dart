import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/bucket_list/data/models/bucket_item.dart';

BucketItem _item() => BucketItem(
      id: 'b1',
      title: 'See the northern lights',
      category: BucketCategory.travel,
      status: BucketStatus.planned,
      createdBy: 'khent',
      createdAt: DateTime.utc(2026, 9, 1),
      priority: BucketPriority.high,
      assignedTo: 'clairjassen',
      dueDate: DateTime.utc(2030, 12, 20),
    );

void main() {
  group('BucketItem', () {
    test('isOverdue ignores completed items and future dates', () {
      expect(_item().isOverdue, isFalse);
      final pastDue = BucketItem(
        id: 'b2',
        title: 'T',
        createdBy: 'clair',
        createdAt: DateTime.utc(2020, 1, 1),
        dueDate: DateTime.utc(2020, 2, 1),
      );
      expect(pastDue.isOverdue, isTrue);
      expect(
        BucketItem(
          id: 'b3',
          title: 'T',
          createdBy: 'clair',
          createdAt: DateTime.utc(2020, 1, 1),
          status: BucketStatus.completed,
          dueDate: DateTime.utc(2020, 2, 1),
        ).isOverdue,
        isFalse,
      );
      expect(
        BucketItem(
          id: 'b4',
          title: 'T',
          createdBy: 'clair',
          createdAt: DateTime.utc(2026, 9, 1),
        ).isOverdue,
        isFalse,
      );
    });

    test('isChore flags assigned, prioritized or dated items', () {
      expect(_item().isChore, isTrue);
      expect(
        BucketItem(
          id: 'b5',
          title: 'T',
          createdBy: 'khent',
          createdAt: DateTime.utc(2026, 9, 1),
        ).isChore,
        isFalse,
      );
    });

    test('priority ranks order from low to urgent', () {
      final ranks = BucketPriority.values.map((p) => p.rank).toList();
      expect(ranks, [0, 1, 2, 3]);
      expect(
        BucketPriority.urgent.rank > BucketPriority.high.rank,
        isTrue,
      );
    });

    test('copyWith clears assignment and due date only when asked', () {
      final base = _item();

      expect(base.copyWith().assignedTo, 'clairjassen');
      expect(base.copyWith().dueDate, DateTime.utc(2030, 12, 20));
      expect(base.copyWith(clearAssignedTo: true).assignedTo, isNull);
      expect(base.copyWith(clearDueDate: true).dueDate, isNull);
      expect(
        base
            .copyWith(status: BucketStatus.completed, completedBy: 'clair')
            .completedBy,
        'clair',
      );
    });

    test('toFirestore omits null completion fields', () {
      final map = _item().toFirestore();

      expect(map['category'], 'travel');
      expect(map['status'], 'planned');
      expect(map['priority'], 'high');
      expect(map['assignedTo'], 'clairjassen');
      expect(map.containsKey('completedAt'), isFalse);
      expect(map.containsKey('completedBy'), isFalse);
      expect(map.containsKey('imageUrl'), isFalse);
    });

    test('every status and category has a label and emoji', () {
      for (final s in BucketStatus.values) {
        expect(s.displayName, isNotEmpty);
        expect(s.emoji, isNotEmpty);
      }
      for (final c in BucketCategory.values) {
        expect(c.displayName, isNotEmpty);
        expect(c.emoji, isNotEmpty);
      }
    });
  });
}
