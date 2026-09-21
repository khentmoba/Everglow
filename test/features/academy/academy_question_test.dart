import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/academy/data/models/academy_question.dart';

void main() {
  group('AcademyQuestion crash-guard', () {
    test('fromMap never crashes on empty input', () {
      final q = AcademyQuestion.fromMap({}, 'doc1');

      expect(q.id, 'doc1');
      expect(q.questionText, isEmpty);
      expect(q.options, isEmpty);
      expect(q.correctOptionIndex, 0);
      expect(q.category, 'engineering');
    });

    test('fromMap never crashes on odd field types', () {
      final q = AcademyQuestion.fromMap({
        'questionText': 42,
        'options': 'not-a-list',
        'correctOptionIndex': 'first',
        'category': ['science'],
      }, 'doc2');

      expect(q.questionText, isEmpty);
      expect(q.options, isEmpty);
      expect(q.correctOptionIndex, 0);
      expect(q.category, 'engineering');
    });

    test('fromMap stringifies mixed option values', () {
      final q = AcademyQuestion.fromMap({
        'questionText': 'Q',
        'options': ['A', 2, null],
        'correctOptionIndex': 1,
      }, 'doc3');

      expect(q.options, ['A', '2', 'null']);
      expect(q.correctOptionIndex, 1);
      expect(q.explanation, isNull);
    });

    test('fromMap reads explanation, ignores odd types', () {
      final q = AcademyQuestion.fromMap({
        'questionText': 'Q',
        'options': ['A', 'B'],
        'correctOptionIndex': 0,
        'explanation': 'Mars is red because of rust.',
      }, 'doc4');
      expect(q.explanation, 'Mars is red because of rust.');

      final odd = AcademyQuestion.fromMap({
        'questionText': 'Q',
        'options': ['A', 'B'],
        'correctOptionIndex': 0,
        'explanation': 42,
      }, 'doc5');
      expect(odd.explanation, isNull);
    });
  });
}
