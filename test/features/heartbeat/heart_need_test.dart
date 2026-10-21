import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/heartbeat/data/models/user_mood.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('needs expire at the next calendar day, including month changes', () {
    final mood = UserMood(
      username: 'demo',
      moodScore: 3,
      moodEmoji: '',
      timestamp: DateTime(2026, 10, 31, 23, 59),
      need: HeartNeed.quiet,
    );
    expect(mood.isCurrentAt(DateTime(2026, 10, 31, 23, 59, 59)), isTrue);
    expect(mood.isCurrentAt(DateTime(2026, 11, 1)), isFalse);
    expect(mood.isCurrentAt(DateTime(2026, 10, 30)), isFalse);
  });

  test('legacy and unfamiliar needs remain optional', () {
    final data = {
      'username': 'demo',
      'moodScore': 4,
      'moodEmoji': '',
      'timestamp': Timestamp.now(),
    };
    expect(UserMood.fromFirestore(data).need, isNull);
    expect(
      UserMood.fromFirestore({...data, 'need': 'unrecognized'}).need,
      isNull,
    );
    final mood = UserMood.fromFirestore({
      ...data,
      'need': 'company',
      'acknowledgedBy': 'partner',
    }, id: 'mood-1');
    expect(mood.need, HeartNeed.company);
    expect(mood.acknowledgedBy, 'partner');
    expect(mood.id, 'mood-1');
  });
}
