import 'package:everglow/features/ai/domain/memory/memory_fact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FactStructureParser', () {
    const parser = FactStructureParser();

    test('parses known subject-verb-object facts', () {
      final result = parser.parse('Khent prefers black coffee');
      expect(result.$1, 'Khent');
      expect(result.$2, 'prefers');
      expect(result.$3, 'black coffee');
    });

    test('parses couple subjects', () {
      final result = parser.parse('Khent and Clair love Ethel Cain');
      expect(result.$1, 'Khent and Clair');
      expect(result.$2, 'love');
      expect(result.$3, 'Ethel Cain');
    });

    test('returns nulls for unstructured facts', () {
      final result = parser.parse('They met on Valentine\'s Day');
      expect(result.$1, isNull);
      expect(result.$2, isNull);
      expect(result.$3, isNull);
    });
  });

  group('MemoryFact', () {
    test('isOnThisDay only matches month and day', () {
      final fact = MemoryFact(
        fact: 'Khent and Clair started dating',
        occurredAt: DateTime(2026, 2, 14, 18, 30),
      );
      expect(fact.isOnThisDay(DateTime(2027, 2, 14)), isTrue);
      expect(fact.isOnThisDay(DateTime(2027, 2, 15)), isFalse);
    });

    test('round-trips through json', () {
      final fact = MemoryFact(
        id: 'abc',
        fact: 'Clair loves lilies',
        category: 'preference',
        subject: 'Clair',
        relation: 'loves',
        object: 'lilies',
        occurredAt: DateTime(2026, 2, 14),
        createdAt: DateTime(2026, 2, 15),
        pinned: true,
      );
      final restored = MemoryFact.fromJson(fact.toJson(), id: 'abc');
      expect(restored.fact, fact.fact);
      expect(restored.subject, 'Clair');
      expect(restored.object, 'lilies');
      expect(restored.pinned, isTrue);
      expect(restored.occurredAt, DateTime(2026, 2, 14));
    });
  });
}
