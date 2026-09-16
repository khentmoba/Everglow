part of 'katana_service.dart';

/// Formats a [DateTime] as a Manga Katana style relative string
/// ("58 minutes ago") or "Aug-12-2026" for older dates.
String formatKatanaTime(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return m == 1 ? '1 minute ago' : '$m minutes ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return h == 1 ? '1 hour ago' : '$h hours ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return d == 1 ? '1 day ago' : '$d days ago';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[time.month - 1]}-${time.day.toString().padLeft(2, '0')}-${time.year}';
}

/// Sorts a chapter list oldest → newest for the reader.
///
/// Ties on the chapter number (e.g. `c5` vs `v2c5` volume re-releases)
/// fall back to the chapter id so the order is stable — Dart's list
/// sort is not stable, and without the tie-break the tied chapters
/// used to shuffle around on every open, which made the list look
/// inconsistent ("chapter 2 shows up first").
List<KatanaChapter> sortChaptersAscending(List<KatanaChapter> chapters) {
  final sorted = List<KatanaChapter>.of(chapters)
    ..sort((a, b) {
      final byNum = a.numeric.compareTo(b.numeric);
      if (byNum != 0) return byNum;
      return a.id.compareTo(b.id);
    });
  return sorted;
}

String katanaTextFromHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
