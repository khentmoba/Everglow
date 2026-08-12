import 'memory_fact.dart';

/// One compact, data-grounded recap of "today in Everglow". Mirrors the
/// server's `composeTodayRecap` so the client and scheduled functions
/// tell the same story.
String composeTodayRecap({
  required String dateLabel,
  List<({String uid, String mood})> moods = const [],
  List<String> activities = const [],
  List<String> watchlist = const [],
  List<String> starlight = const [],
  List<MemoryFact> memories = const [],
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final parts = <String>[];
  parts.add('Today is $dateLabel.');

  if (moods.isEmpty) {
    parts.add('No mood logged yet today.');
  } else {
    parts.add(
      moods.map((m) => '${m.uid} feels ${m.mood}.').join(' '),
    );
  }

  if (activities.isNotEmpty) {
    parts.add('Recently: ${activities.take(3).join(', ')}.');
  }
  if (starlight.isNotEmpty) {
    parts.add('A star in the jar: "${starlight.first}".');
  }
  if (watchlist.isNotEmpty) {
    parts.add('On the watchlist: ${watchlist.take(2).join(', ')}.');
  }

  final onThisDay = memories.where((m) => m.isOnThisDay(current)).toList();
  if (onThisDay.isNotEmpty) {
    parts.add('On this day: ${onThisDay.first.fact}.');
  }
  parts.add('Have a beautiful day together!');
  return parts.join(' ');
}
