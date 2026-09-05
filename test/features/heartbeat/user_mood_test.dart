import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/heartbeat/data/models/user_mood.dart';

void main() {
  group('UserMood', () {
    test('fromFirestore reads every field', () {
      final mood = UserMood.fromFirestore({
        'username': 'clair',
        'moodScore': 5,
        'moodEmoji': '🥰',
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 9, 5)),
      });

      expect(mood.username, 'clair');
      expect(mood.moodScore, 5);
      expect(mood.moodEmoji, '🥰');
      expect(mood.timestamp.millisecondsSinceEpoch, DateTime.utc(2026, 9, 5).millisecondsSinceEpoch);
    });

    test('fromFirestore falls back to neutral defaults', () {
      final mood = UserMood.fromFirestore({});

      expect(mood.username, isEmpty);
      expect(mood.moodScore, 3);
      expect(mood.moodEmoji, isNotEmpty);
    });

    test('toFirestore keeps username, score and emoji', () {
      final map = UserMood(
        username: 'khent',
        moodScore: 4,
        moodEmoji: '😊',
        timestamp: DateTime.utc(2026, 9, 5),
      ).toFirestore();

      expect(map['username'], 'khent');
      expect(map['moodScore'], 4);
      expect(map['moodEmoji'], '😊');
      expect(map.containsKey('timestamp'), isTrue);
    });
  });
}

