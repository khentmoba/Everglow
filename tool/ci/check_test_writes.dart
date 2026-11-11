// Tests must not name a tracked path.
//
// A test that writes into the repo dirties every working tree that runs the
// suite, so `git status` stops being trustworthy and the next `git add -A`
// ships an unrelated change. That already happened once: a proof-capture test
// rewrote docs/pr-proof/pr-579/shot.png on every run and nearly landed it in
// another PR (retro finding, PR 584 review round 1).
//
// The rule is the path literal, not the write call: a tracked path inside a
// test is either a write (wrong) or a read (use Directory.current, or load it
// through rootBundle). Artifacts go to Directory.systemTemp.
//
// Usage: dart tool/ci/check_test_writes.dart
import 'dart:io';

import '_io.dart';

/// A `File(...)`/`Directory(...)` call whose first argument is a literal
/// pointing at a tracked top-level folder.
final _trackedLiteral = RegExp(
  r'''(?:File|Directory)\(\s*r?['"](?:docs|assets|lib|web|functions|tool|test)/''',
);

const _tracked = 'docs/, assets/, lib/, web/, functions/, tool/, test/';

Future<void> main() async {
  final failures = <String>[];
  final files = await Directory('test')
      .list(recursive: true)
      .where((e) => e is File && e.path.endsWith('.dart'))
      .cast<File>()
      .toList();

  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    final lines = (await readTolerant(file)).split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (_trackedLiteral.hasMatch(lines[i])) {
        failures.add('  $path:${i + 1}: ${lines[i].trim()}');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln(
      '[test-writes] FAIL: a test names a tracked path. Tests must not write '
      'into the repo ($_tracked) — that dirties every working tree that runs '
      'the suite. Write artifacts to Directory.systemTemp, and build a read '
      'path from Directory.current instead of a literal.\n'
      '${failures.join('\n')}',
    );
    exit(1);
  }
  stdout.writeln(
    '[test-writes] OK: ${files.length} test file(s), no tracked path literals.',
  );
}
