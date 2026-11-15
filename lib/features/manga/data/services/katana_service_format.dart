part of 'katana_service.dart';

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

List<KatanaChapter> sortChaptersAscending(List<KatanaChapter> chapters) {
  final sorted = List<KatanaChapter>.of(chapters)
    ..sort((a, b) {
      final byNum = a.numeric.compareTo(b.numeric);
      if (byNum != 0) return byNum;
      return a.id.compareTo(b.id);
    });
  return sorted;
}

KatanaChapter? nextUnreadChapter(
  List<KatanaChapter> chapters,
  Set<String> readChapterIds, {
  String lastReadChapterId = '',
}) {
  final ascending = sortChaptersAscending(chapters);
  if (ascending.isEmpty) return null;
  final anchor = ascending.indexWhere((c) => c.id == lastReadChapterId);
  if (anchor >= 0) {
    for (var i = anchor; i < ascending.length; i++) {
      if (!readChapterIds.contains(ascending[i].id)) return ascending[i];
    }
    return ascending.last;
  }
  for (final chapter in ascending) {
    if (!readChapterIds.contains(chapter.id)) return chapter;
  }
  return ascending.last;
}

String katanaTextFromHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
