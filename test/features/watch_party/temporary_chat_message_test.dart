import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/watch_party/data/models/temporary_chat_message.dart';

void main() {
  group('TemporaryChatMessage', () {
    test('fromMap reads every field', () {
      final sent = DateTime.utc(2026, 9, 15, 21);
      final message = TemporaryChatMessage.fromMap('m1', {
        'sender': 'clair',
        'senderUid': 'uid1',
        'text': 'Pause, snacks break',
        'timestamp': Timestamp.fromDate(sent),
      });

      expect(message.id, 'm1');
      expect(message.sender, 'clair');
      expect(message.senderUid, 'uid1');
      expect(message.text, 'Pause, snacks break');
      expect(message.timestamp.millisecondsSinceEpoch,
          sent.millisecondsSinceEpoch);
    });

    test('fromMap never crashes on odd field types', () {
      final message = TemporaryChatMessage.fromMap('m2', {
        'sender': 1,
        'senderUid': ['uid1'],
        'text': 42,
        'timestamp': 'not-a-date',
      });

      expect(message.sender, isEmpty);
      expect(message.senderUid, isEmpty);
      expect(message.text, isEmpty);
      expect(message.timestamp, isA<DateTime>());
    });
  });
}
