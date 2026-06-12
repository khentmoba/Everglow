import 'package:age_calculator/age_calculator.dart';

class AnniversaryCounter {
  final int years;
  final int months;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  AnniversaryCounter({
    required this.years,
    required this.months,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  factory AnniversaryCounter.calculate(DateTime startDate, DateTime now) {
    if (now.isBefore(startDate)) {
      return AnniversaryCounter(
        years: 0,
        months: 0,
        days: 0,
        hours: 0,
        minutes: 0,
        seconds: 0,
      );
    }

    final DateDuration calendar = AgeCalculator.age(startDate, today: now);
    final Duration sinceStart = now.difference(startDate);
    final int hours = sinceStart.inHours % 24;
    final int minutes = sinceStart.inMinutes % 60;
    final int seconds = sinceStart.inSeconds % 60;

    return AnniversaryCounter(
      years: calendar.years,
      months: calendar.months,
      days: calendar.days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
  }

  static DateTime get anniversaryDate => DateTime(2026, 2, 14);
}
