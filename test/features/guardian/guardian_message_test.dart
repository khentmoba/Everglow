import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/guardian/data/models/guardian_message.dart';

void main() {
  group('GuardianMessage', () {
    test('fromFirestore reads every field', () {
      final created = DateTime.utc(2026, 9, 14);
      final message = GuardianMessage.fromFirestore({
        'content': 'Drink some water',
        'category': 'care',
        'createdAt': Timestamp.fromDate(created),
      }, 'm1');

      expect(message.id, 'm1');
      expect(message.content, 'Drink some water');
      expect(message.category, 'care');
      expect(message.createdAt?.millisecondsSinceEpoch,
          created.millisecondsSinceEpoch);
    });

    test('fromFirestore defaults an empty message to idle', () {
      final message = GuardianMessage.fromFirestore({}, 'm2');

      expect(message.content, isEmpty);
      expect(message.category, 'idle');
      expect(message.createdAt, isNull);
    });

    test('fromFirestore never crashes on odd field types', () {
      final message = GuardianMessage.fromFirestore({
        'content': 42,
        'category': ['care'],
        'createdAt': 'yesterday',
      }, 'm3');

      expect(message.content, isEmpty);
      expect(message.category, 'idle');
      expect(message.createdAt, isNull);
    });
  });
}
