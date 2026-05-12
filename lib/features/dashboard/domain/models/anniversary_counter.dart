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

    DateDuration duration = AgeCalculator.age(startDate, today: now);
    
    // AgeCalculator doesn't provide h/m/s, so we calculate them manually
    // from the remainder of the day.
    Duration timeDifference = now.difference(DateTime(
      now.year,
      now.month,
      now.day,
    ));

    // If the time is before the start time on the same day, we need to adjust
    // But for simplicity and since the user didn't specify a time, we'll assume 00:00:00
    
    return AnniversaryCounter(
      years: duration.years,
      months: duration.months,
      days: duration.days,
      hours: now.hour,
      minutes: now.minute,
      seconds: now.second,
    );
  }

  static DateTime get anniversaryDate => DateTime(2026, 2, 14);
}
