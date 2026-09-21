import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/academy/data/models/game_match.dart';

void main() {
  group('GameMatch crash-guard', () {
    test('fromMap never crashes on empty input', () {
      final m = GameMatch.fromMap({}, 'm1');

      expect(m.matchId, 'm1');
      expect(m.hostId, isEmpty);
      expect(m.participantId, isNull);
      expect(m.hostUsername, isNull);
      expect(m.participantUsername, isNull);
      expect(m.hostScore, 0);
      expect(m.guestScore, 0);
      expect(m.status, 'waiting');
      expect(m.questionIndex, 0);
      expect(m.questionIds, isEmpty);
      expect(m.category, 'engineering');
      expect(m.winnerId, isNull);
      expect(m.isReplenishing, isFalse);
      expect(m.createdAt, isA<DateTime>());
    });

    test('fromMap never crashes on odd field types', () {
      final m = GameMatch.fromMap({
        'hostId': 7,
        'participantId': 123,
        'hostUsername': 9,
        'hostScore': 'three',
        'guestScore': [5],
        'khentScore': 'legacy',
        'status': true,
        'currentQuestionId': 99,
        'questionIndex': 'nine',
        'questionIds': 'not-a-list',
        'category': 42,
        'createdAt': 'not-a-date',
        'winnerId': 0,
        'isReplenishing': 'yes',
      }, 'm2');

      expect(m.hostId, isEmpty);
      expect(m.participantId, isNull);
      expect(m.hostUsername, isNull);
      expect(m.hostScore, 0);
      expect(m.guestScore, 0);
      expect(m.status, 'waiting');
      expect(m.currentQuestionId, isEmpty);
      expect(m.questionIndex, 0);
      expect(m.questionIds, isEmpty);
      expect(m.category, 'engineering');
      expect(m.winnerId, isNull);
      expect(m.isReplenishing, isFalse);
      expect(m.createdAt, isA<DateTime>());
    });

    test('fromMap reads millis and DateTime timestamps', () {
      final millis = DateTime.utc(2026, 9, 5).millisecondsSinceEpoch;
      expect(
        GameMatch.fromMap({'createdAt': millis}, 'm3').createdAt,
        DateTime.fromMillisecondsSinceEpoch(millis),
      );

      final date = DateTime.utc(2026, 9, 6);
      expect(GameMatch.fromMap({'createdAt': date}, 'm4').createdAt, date);
      expect(
        GameMatch.fromMap({
          'createdAt': Timestamp.fromDate(date),
        }, 'm5').createdAt.millisecondsSinceEpoch,
        date.millisecondsSinceEpoch,
      );
    });
  });
}
