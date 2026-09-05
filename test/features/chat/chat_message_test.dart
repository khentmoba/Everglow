import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/chat/domain/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('parseTimestamp reads timestamps, millis and ISO strings', () {
      expect(
        ChatMessage.parseTimestamp(
            Timestamp.fromDate(DateTime.utc(2026, 9, 5))),
        isA<DateTime>(),
      );
      expect(
        ChatMessage.parseTimestamp(1700000000000),
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(
        ChatMessage.parseTimestamp('2026-09-05T10:00:00.000Z'),
        DateTime.utc(2026, 9, 5, 10),
      );
    });

    test('toMap stamps month-day and server timestamp', () {
      final map = ChatMessage(
        id: 'm1',
        sender: 'clair',
        senderUid: 'uid1',
        text: 'Good morning',
        timestamp: DateTime.utc(2026, 9, 5, 7, 30),
      ).toMap();

      expect(map['sender'], 'clair');
      expect(map['senderUid'], 'uid1');
      expect(map['text'], 'Good morning');
      expect(map['monthDay'], '09-05');
      expect(map.containsKey('timestamp'), isTrue);
    });
  });
}
