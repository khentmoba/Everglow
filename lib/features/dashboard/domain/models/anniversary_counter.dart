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

    // Calendar borrow: full years, then full months, then leftover days.
    var years = now.year - startDate.year;
    var months = now.month - startDate.month;
    var days = now.day - startDate.day;
    if (days < 0) {
      months -= 1;
      days += DateTime(now.year, now.month, 0).day;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    final Duration sinceStart = now.difference(startDate);

    return AnniversaryCounter(
      years: years,
      months: months,
      days: days,
      hours: sinceStart.inHours % 24,
      minutes: sinceStart.inMinutes % 60,
      seconds: sinceStart.inSeconds % 60,
    );
  }

  static DateTime get anniversaryDate => DateTime(2026, 2, 14);
}
