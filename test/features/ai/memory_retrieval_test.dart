import 'dart:math';

import 'package:everglow/features/ai/domain/memory/memory_fact.dart';
import 'package:everglow/features/ai/domain/memory/memory_retrieval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final facts = [
    MemoryFact(
      id: 'a',
      fact: 'Khent prefers black coffee',
      category: 'preference',
      subject: 'Khent',
      relation: 'prefers',
      object: 'black coffee',
      createdAt: DateTime(2026, 8, 1),
    ),
    MemoryFact(
      id: 'b',
      fact: 'Clair loves Ethel Cain music',
      category: 'preference',
      subject: 'Clair',
      relation: 'loves',
      object: 'Ethel Cain music',
      createdAt: DateTime(2026, 8, 10),
      pinned: true,
    ),
    MemoryFact(
      id: 'c',
      fact: 'Khent rides a Honda Winner X',
      category: 'fact',
      subject: 'Khent',
      relation: 'rides',
      object: 'a Honda Winner X',
      createdAt: DateTime(2026, 1, 1),
    ),
    MemoryFact(
      id: 'd',
      fact: 'Khent and Clair started dating on Valentine\'s Day',
      category: 'date',
      subject: 'Khent and Clair',
      relation: 'started dating on',
      object: 'Valentine\'s Day',
      occurredAt: DateTime(2026, 2, 14),
      createdAt: DateTime(2026, 2, 14),
    ),
  ];

  group('MemoryRetriever', () {
    test('ranks matching facts above unrelated facts', () {
      const retriever = MemoryRetriever();
      final ranked = retriever.rank(facts, query: 'coffee');
      expect(ranked.first.id, 'a');
    });

    test('gives on-this-day memories a boost on the matching day', () {
      const retriever = MemoryRetriever();
      final ranked = retriever.rank(
        facts,
        query: '',
        now: DateTime(2027, 2, 14),
      );
      expect(ranked.first.id, 'd');
    });

    test('limits results', () {
      const retriever = MemoryRetriever();
      final ranked = retriever.rank(facts, query: 'Khent', max: 2);
      expect(ranked.length, 2);
    });
  });

  group('MemoryTriviaGenerator', () {
    test('generates grounded multiple choice questions', () {
      const generator = MemoryTriviaGenerator();
      final questions = generator.generate(facts, count: 3, random: _seed());
      expect(questions.length, 3);
      for (final question in questions) {
        expect(question.choices.length, greaterThanOrEqualTo(2));
        expect(question.answerIndex, inInclusiveRange(0, 3));
        expect(question.explanation, isNotEmpty);
        expect(
          question.explanation.contains(question.choices[question.answerIndex]),
          isTrue,
          reason: 'Answer must come from the real memory',
        );
      }
    });
  });

  group('RelationshipInsights', () {
    test('computes mood and activity patterns', () {
      const insights = RelationshipInsights();
      final result = insights.compute(
        moods: ['happy', 'happy', 'stressed'],
        activities: ['Watched a movie', 'Movie night', 'Cooked dinner'],
      );
      expect(result, hasLength(2));
      expect(result[0].detail, contains('happy'));
      expect(result[1].detail, contains('movie night'));
    });
  });
}

Random _seed() => Random(42);
