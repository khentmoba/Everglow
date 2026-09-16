import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/watch_party/data/models/watch_party_chat_message.dart';

void main() {
  group('WatchPartyChatMessage', () {
    test('fromMap reads every field', () {
      final sent = DateTime.utc(2026, 9, 15, 21);
      final message = WatchPartyChatMessage.fromMap('m1', {
        'sender': 'khent',
        'senderUid': 'uid2',
        'text': 'Starting in 3, 2, 1',
        'timestamp': Timestamp.fromDate(sent),
      });

      expect(message.id, 'm1');
      expect(message.sender, 'khent');
      expect(message.senderUid, 'uid2');
      expect(message.text, 'Starting in 3, 2, 1');
      expect(message.timestamp.millisecondsSinceEpoch,
          sent.millisecondsSinceEpoch);
    });

    test('fromMap never crashes on odd field types', () {
      final message = WatchPartyChatMessage.fromMap('m2', {
        'sender': 1,
        'senderUid': ['uid2'],
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
