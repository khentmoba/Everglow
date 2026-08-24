import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/domain/models/anniversary_counter.dart';

void main() {
  group('AnniversaryCounter.calculate', () {
    test('returns zeros when date is in the future', () {
      final future = DateTime.now().add(const Duration(days: 365));
      final counter = AnniversaryCounter.calculate(future, DateTime.now());
      expect(counter.years, 0);
      expect(counter.months, 0);
      expect(counter.days, 0);
      expect(counter.hours, 0);
      expect(counter.minutes, 0);
      expect(counter.seconds, 0);
    });

    test('returns correct values for a known date', () {
      final start = DateTime(2026, 2, 14);
      final now = DateTime(2026, 2, 15, 12, 30, 45);
      final counter = AnniversaryCounter.calculate(start, now);
      expect(counter.years, 0);
      expect(counter.months, 0);
      expect(counter.days, 1);
      expect(counter.hours, 12);
      expect(counter.minutes, 30);
      expect(counter.seconds, 45);
    });

    test('seconds roll over correctly', () {
      final start = DateTime(2026, 2, 14);
      final now = DateTime(2026, 2, 14, 0, 0, 59);
      final counter = AnniversaryCounter.calculate(start, now);
      expect(counter.seconds, 59);
    });

    test('handles exactly one year', () {
      final start = DateTime(2026, 2, 14);
      final now = DateTime(2027, 2, 14);
      final counter = AnniversaryCounter.calculate(start, now);
      expect(counter.years, 1);
      expect(counter.months, 0);
      expect(counter.days, 0);
    });
  });
}
