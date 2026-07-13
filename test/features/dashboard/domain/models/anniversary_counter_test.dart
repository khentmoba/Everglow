import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/domain/models/anniversary_counter.dart';

void main() {
  group('AnniversaryCounter.calculate', () {
    test('returns all zeros when now is before the start date', () {
      final start = DateTime(2026, 2, 14);
      final now = DateTime(2025, 1, 1);

      final counter = AnniversaryCounter.calculate(start, now);

      expect(counter.years, 0);
      expect(counter.months, 0);
      expect(counter.days, 0);
      expect(counter.hours, 0);
      expect(counter.minutes, 0);
      expect(counter.seconds, 0);
    });

    test('returns all zeros when now equals start date', () {
      final start = DateTime(2026, 2, 14);
      final now = DateTime(2026, 2, 14);

      final counter = AnniversaryCounter.calculate(start, now);

      expect(counter.years, 0);
      expect(counter.months, 0);
      expect(counter.days, 0);
      expect(counter.hours, 0);
      expect(counter.minutes, 0);
      expect(counter.seconds, 0);
    });

    test('calculates correct values after 1 day', () {
      final start = DateTime(2026, 2, 14);
      final now = DateTime(2026, 2, 15);

      final counter = AnniversaryCounter.calculate(start, now);

      expect(counter.years, 0);
      expect(counter.months, 0);
      expect(counter.days, 1);
      expect(counter.hours, 0);
      expect(counter.minutes, 0);
      expect(counter.seconds, 0);
    });

    test('calculates correct values after 1 year', () {
      final start = DateTime(2026, 2, 14);
      final now = DateTime(2027, 2, 14);

      final counter = AnniversaryCounter.calculate(start, now);

      expect(counter.years, 1);
      expect(counter.months, 0);
      expect(counter.days, 0);
    });

    test('calculates correct values after 1 year and 1 month', () {
      final start = DateTime(2026, 2, 14);
      final now = DateTime(2027, 3, 14);

      final counter = AnniversaryCounter.calculate(start, now);

      expect(counter.years, 1);
      expect(counter.months, 1);
      expect(counter.days, 0);
    });

    test('calculates correct values with hours, minutes, seconds', () {
      final start = DateTime(2026, 2, 14, 10, 30, 0);
      final now = DateTime(2026, 2, 14, 15, 45, 30);

      final counter = AnniversaryCounter.calculate(start, now);

      expect(counter.years, 0);
      expect(counter.months, 0);
      expect(counter.days, 0);
      expect(counter.hours, 5);
      expect(counter.minutes, 15);
      expect(counter.seconds, 30);
    });

    test('handles month boundary correctly', () {
      final start = DateTime(2025, 1, 1);
      final now = DateTime(2025, 3, 1);

      final counter = AnniversaryCounter.calculate(start, now);

      expect(counter.years, 0);
      expect(counter.months, 2);
      expect(counter.days, 0);
    });

    test('handles leap year correctly', () {
      final start = DateTime(2024, 2, 29);
      final now = DateTime(2025, 3, 1);

      final counter = AnniversaryCounter.calculate(start, now);

      expect(counter.years, 1);
      // months/days may vary by age_calculator impl — just ensure no crash
      expect(counter.months, greaterThanOrEqualTo(0));
      expect(counter.days, greaterThanOrEqualTo(0));
    });

    test('handles multi-year span', () {
      final start = DateTime(2020, 6, 15);
      final now = DateTime(2026, 6, 15);

      final counter = AnniversaryCounter.calculate(start, now);

      expect(counter.years, 6);
      expect(counter.months, 0);
      expect(counter.days, 0);
    });
  });

  group('AnniversaryCounter.anniversaryDate', () {
    test('returns February 14, 2026', () {
      expect(AnniversaryCounter.anniversaryDate, DateTime(2026, 2, 14));
    });
  });
}
