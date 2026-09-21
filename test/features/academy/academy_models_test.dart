import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/academy/data/models/academy_question.dart';
import 'package:everglow/features/academy/data/models/game_match.dart';

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
        explanation: 'Because Motchi says so.',
      );
      final map = q.toMap();

      expect(map['questionText'], 'Q');
      expect(map['options'], ['A', 'B']);
      expect(map['correctOptionIndex'], 0);
      expect(map['category'], 'science');
      expect(map['explanation'], 'Because Motchi says so.');
      final restored = AcademyQuestion.fromMap(map, 'q1');
      expect(restored.questionText, 'Q');
      expect(restored.correctOptionIndex, 0);
      expect(restored.explanation, 'Because Motchi says so.');
    });

    test('explanation is null on older docs', () {
      final q = AcademyQuestion.fromMap({
        'questionText': 'Q',
        'options': ['A', 'B'],
        'correctOptionIndex': 0,
      }, 'doc1');
      expect(q.explanation, isNull);
      expect(q.toMap().containsKey('explanation'), isFalse);
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
      final m = GameMatch.fromMap({'hostId': 'uid-khent'}, 'm1');

      expect(m.matchId, 'm1');
      expect(m.hostId, 'uid-khent');
      expect(m.status, 'waiting');
      expect(m.hostScore, 0);
      expect(m.guestScore, 0);
      expect(m.questionIndex, 0);
      expect(m.questionIds, isEmpty);
      expect(m.isReplenishing, isFalse);
      expect(m.winnerId, isNull);
      expect(m.participantId, isNull);
    });

    test('fromMap reads scores and timestamps', () {
      final m = GameMatch.fromMap({
        'hostId': 'uid-khent',
        'participantId': 'uid-clair',
        'hostUsername': 'khentsgdz',
        'participantUsername': 'clairjassen',
        'hostScore': 3,
        'guestScore': 5,
        'status': 'finished',
        'currentQuestionId': 'q9',
        'questionIndex': 9,
        'questionIds': ['q1', 'q9'],
        'category': 'science',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 5)),
        'winnerId': 'clairjassen',
      }, 'm2');

      expect(m.hostScore, 3);
      expect(m.guestScore, 5);
      expect(m.hostUsername, 'khentsgdz');
      expect(m.participantUsername, 'clairjassen');
      expect(m.questionIds, ['q1', 'q9']);
      expect(m.status, 'finished');
      expect(m.winnerId, 'clairjassen');
      expect(
        m.createdAt.millisecondsSinceEpoch,
        DateTime.utc(2026, 9, 5).millisecondsSinceEpoch,
      );
    });

    test('fromMap reads legacy khent/clair score keys', () {
      final m = GameMatch.fromMap({
        'hostId': 'khentsgdz',
        'khentScore': 3,
        'clairScore': 5,
      }, 'm-legacy');
      expect(m.hostScore, 3);
      expect(m.guestScore, 5);
    });

    test('copyWith advances the match without losing ids', () {
      final m = GameMatch.fromMap({'hostId': 'uid-khent'}, 'm3').copyWith(
        status: 'active',
        participantId: 'uid-clair',
        participantUsername: 'clairjassen',
        hostScore: 1,
        questionIndex: 1,
        currentQuestionId: 'q1',
        questionIds: const ['q1', 'q2'],
        isReplenishing: true,
      );

      expect(m.matchId, 'm3');
      expect(m.hostId, 'uid-khent');
      expect(m.status, 'active');
      expect(m.participantId, 'uid-clair');
      expect(m.participantUsername, 'clairjassen');
      expect(m.hostScore, 1);
      expect(m.questionIndex, 1);
      expect(m.questionIds, ['q1', 'q2']);
      expect(m.isReplenishing, isTrue);
    });
  });
}
