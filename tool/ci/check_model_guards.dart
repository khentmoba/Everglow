import 'dart:io';

import '_io.dart';

const pinned = {
  'test/features/daily_bloom/garden_stats_test.dart': ['frommap', 'lastvisit'],
  'test/features/gallery/memory_photo_test.dart': ['frommap', 'odd'],
  'test/features/chat/chat_message_test.dart': ['month-day', 'pad'],
  'test/features/canvas/doodle_stroke_test.dart': ['frommap', 'malformed'],
};

Future<void> main() async {
  final failures = <String>[];
  var optionalMissing = <String>[];

  for (final entry in pinned.entries) {
    final file = File(entry.key);
    if (!await file.exists()) {
      failures.add('${entry.key} is missing; model crash-guard lost.');
      continue;
    }
    final src = await readTolerant(file);
    final missingMarkers =
        entry.value.where((m) => !src.toLowerCase().contains(m)).toList();
    if (missingMarkers.isNotEmpty) {
      failures.add(
        '${entry.key} no longer covers bad input '
        '(missing: ${missingMarkers.join(", ")}).',
      );
    }
  }

  final untested = <String>[];
  await for (final e in Directory('lib').list(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    final src = await readTolerant(e);
    if (!src.contains('fromFirestore') && !src.contains('fromMap')) continue;
    if (e.path.contains('/services/') || e.path.contains('/screens/')) {
      continue;
    }
    final base = e.path.split('/').last.replaceAll('.dart', '');
    var hasTest = false;
    await for (final t in Directory('test').list(recursive: true)) {
      if (t is File &&
          (t.path.endsWith('${base}_test.dart') ||
              t.path.endsWith('${base}test.dart'))) {
        hasTest = true;
        break;
      }
    }
    if (!hasTest) untested.add(e.path);
  }
  if (untested.isNotEmpty) {
    optionalMissing = (untested..sort()).take(10).toList();
  }

  if (failures.isEmpty) {
    stdout.writeln('[guards] OK: pinned model crash-guards intact.');
    if (optionalMissing.isNotEmpty) {
      stdout.writeln(
        '[guards] note: ${untested.length} models lack companion tests '
        '(advisory, not failing):',
      );
      for (final u in optionalMissing) {
        stdout.writeln('  - $u');
      }
      if (untested.length > optionalMissing.length) {
        stdout.writeln('  ... and ${untested.length - optionalMissing.length} more.');
      }
    }
    return;
  }
  stderr.writeln('[guards] FAIL (${failures.length}):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}
