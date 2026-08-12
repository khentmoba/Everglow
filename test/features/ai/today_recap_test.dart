import 'package:everglow/features/ai/domain/memory/memory_fact.dart';
import 'package:everglow/features/ai/domain/memory/today_recap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('composeTodayRecap includes real data and on-this-day memories', () {
    final recap = composeTodayRecap(
      dateLabel: '2026-08-13',
      moods: [
        (uid: 'khentsgdz', mood: 'happy'),
      ],
      activities: ['Watched a movie'],
      starlight: ['I love our mornings'],
      watchlist: ['Interstellar'],
      memories: [
        MemoryFact(
          fact: 'Khent and Clair started dating',
          occurredAt: DateTime(2026, 2, 14),
        ),
        MemoryFact(
          fact: 'First ramen date',
          occurredAt: DateTime(2025, 8, 13),
        ),
      ],
      now: DateTime(2026, 8, 13),
    );
    expect(recap, contains('2026-08-13'));
    expect(recap, contains('khentsgdz feels happy'));
    expect(recap, contains('"I love our mornings"'));
    expect(recap, contains('First ramen date'));
    expect(recap, isNot(contains('started dating')));
  });
}
