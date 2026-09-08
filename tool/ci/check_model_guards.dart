// Model-guard gate: Firestore parsing must tolerate hostile stored data.
// Prevents the #107-#110 class: one odd stored doc blanking a whole
// surface — GardenStats hard-cast on lastVisit (4d83936), gallery photo
// with text tags / string coords throwing mid-stream (5a0477f), chat
// month-day padding and bad timestamps (bd505ea), mood check-in retry
// (b24eca9).
//
// Rule: the pinned guard tests below must exist and must exercise bad
// input (null / wrong-type markers). Deleting or hollowing them fails
// the PR. When adding a new fromFirestore/fromMap model, add a companion
// test with null + garbage cases and pin it here.
//
// Usage: dart tool/ci/check_model_guards.dart
import 'dart:convert';
import 'dart:io';

// Lenient read: one non-UTF8 source file (extended-ASCII) must not break
// the scan; all markers we look for are ASCII.
Future<String> readTolerant(File f) =>
    f.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));

const pinned = {
  'test/features/daily_bloom/garden_stats_test.dart': ['frommap', 'lastvisit'],
  'test/features/gallery/memory_photo_test.dart': ['frommap', 'odd'],
  'test/features/chat/chat_message_test.dart': ['month-day', 'pad'],
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

  // Advisory only: models with fromFirestore but no companion test.
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
