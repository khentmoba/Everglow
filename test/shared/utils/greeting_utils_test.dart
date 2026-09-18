import 'package:everglow/shared/utils/greeting_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('motchiGreetingTitle', () {
    test('greets Mama by time of day', () {
      expect(
        motchiGreetingTitle(DateTime(2026, 9, 18, 8), 'clairjassen'),
        'Good morning, Mama 🍡',
      );
      expect(
        motchiGreetingTitle(DateTime(2026, 9, 18, 14), 'clairjassen'),
        'Good afternoon, Mama',
      );
      expect(
        motchiGreetingTitle(DateTime(2026, 9, 18, 19), 'clairjassen'),
        'Good evening, Mama 🍡',
      );
      expect(
        motchiGreetingTitle(DateTime(2026, 9, 18, 23), 'clairjassen'),
        'Up late, Mama? 🌙',
      );
    });

    test('greets Dada and handles unknown user', () {
      expect(
        motchiGreetingTitle(DateTime(2026, 9, 18, 9), 'khentsgdz'),
        'Good morning, Dada 🍡',
      );
      expect(
        motchiGreetingTitle(DateTime(2026, 9, 18, 9), null),
        'Good morning 🍡',
      );
      expect(
        motchiGreetingTitle(DateTime(2026, 9, 18, 23), 'stranger'),
        'Up late? 🌙',
      );
    });
  });

  group('motchiGreetingSubtitle', () {
    test('changes with time of day', () {
      expect(
        motchiGreetingSubtitle(DateTime(2026, 9, 18, 8)),
        contains('fresh day'),
      );
      expect(
        motchiGreetingSubtitle(DateTime(2026, 9, 18, 14)),
        contains('purring'),
      );
      expect(
        motchiGreetingSubtitle(DateTime(2026, 9, 18, 20)),
        contains('Wind down'),
      );
      expect(
        motchiGreetingSubtitle(DateTime(2026, 9, 18, 1)),
        contains('stars'),
      );
    });
  });
}
