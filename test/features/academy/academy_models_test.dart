import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/academy/models/academy_question.dart';
import 'package:everglow/features/academy/models/game_match.dart';

void main() {
  group('AcademyQuestion', () {
    test('fromMap reads fields with engineering default', () {
      final q = AcademyQuestion.fromMap({
        'questionText': 'What is clean code?',
        'options': ['A', 'B', 'C'],
        'correctOptionIndex': 1,
      }, 'doc1');

      expect(q.id, 'doc1');
      expect(q.questionText, 'What is clean code?');
      expect(q.options, ['A', 'B', 'C']);
      expect(q.correctOptionIndex, 1);
      expect(q.category, 'engineering');
    });

    test('toMap round-trips every field', () {
      final q = AcademyQuestion(
        id: 'q1',
        questionText: 'Q',
        options: const ['A', 'B'],
        correctOptionIndex: 0,
        category: 'science',
      );
      final map = q.toMap();

      expect(map['questionText'], 'Q');
      expect(map['options'], ['A', 'B']);
      expect(map['correctOptionIndex'], 0);
      expect(map['category'], 'science');
      final restored = AcademyQuestion.fromMap(map, 'q1');
      expect(restored.questionText, 'Q');
      expect(restored.correctOptionIndex, 0);
    });

    test('generateId is stable and content-based', () {
      final a = AcademyQuestion.generateId('Same question');
      final b = AcademyQuestion.generateId('Same question');
      final c = AcademyQuestion.generateId('Other question');

      expect(a, b);
      expect(a == c, isFalse);
      expect(a.length, 64);
    });
  });

  group('GameMatch', () {
    test('fromMap defaults to a waiting match', () {
      final m = GameMatch.fromMap({'hostId': 'khent'}, 'm1');

      expect(m.matchId, 'm1');
      expect(m.hostId, 'khent');
      expect(m.status, 'waiting');
      expect(m.khentScore, 0);
      expect(m.clairScore, 0);
      expect(m.questionIndex, 0);
      expect(m.isReplenishing, isFalse);
      expect(m.winnerId, isNull);
      expect(m.participantId, isNull);
    });

    test('fromMap reads scores and timestamps', () {
      final m = GameMatch.fromMap({
        'hostId': 'khent',
        'participantId': 'clair',
        'khentScore': 3,
        'clairScore': 5,
        'status': 'finished',
        'currentQuestionId': 'q9',
        'questionIndex': 9,
        'category': 'science',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 5)),
        'winnerId': 'clair',
      }, 'm2');

      expect(m.khentScore, 3);
      expect(m.clairScore, 5);
      expect(m.status, 'finished');
      expect(m.winnerId, 'clair');
      expect(m.createdAt.millisecondsSinceEpoch,
          DateTime.utc(2026, 9, 5).millisecondsSinceEpoch);
    });

    test('copyWith advances the match without losing ids', () {
      final m = GameMatch.fromMap({'hostId': 'khent'}, 'm3').copyWith(
        status: 'active',
        participantId: 'clair',
        khentScore: 1,
        questionIndex: 1,
        currentQuestionId: 'q1',
      );

      expect(m.matchId, 'm3');
      expect(m.hostId, 'khent');
      expect(m.status, 'active');
      expect(m.participantId, 'clair');
      expect(m.khentScore, 1);
      expect(m.questionIndex, 1);
      expect(m.isReplenishing, isFalse);
    });
  });
}
