// Stale-claim guard for docs/PERF_NOTES.md.
//
// This file is the source of truth for what has been done to performance, so a
// claim in it that no longer matches the code is worse than no file at all: it
// sends the next person hunting for a tool that was deleted. That happened
// repeatedly during the 2026-10 pass:
//
//   * it documented an on-device frame meter and the switch that reached it,
//     both of which had been removed in cfa3c9c1,
//   * it described `DeferredSection` as having a web branch that defeats the
//     very laziness it claimed,
//   * its shipped list cited `everglow_sparkles.dart`, which does not exist.
//
// All three read as authoritative and all three were wrong. This guard does not
// try to judge prose; it checks the one part that can be checked mechanically —
// **every file path the document cites must exist on disk.** That is enough to
// catch the whole class above.
//
// Usage: dart tool/ci/check_perf_notes.dart
import 'dart:io';

import '_io.dart';

/// Matches a rooted path inside backticks: `lib/....dart`, `tool/...`, etc.
/// Deliberately narrow: it wants concrete paths a reviewer can click.
final RegExp _rootedPath = RegExp(
  r'`((?:lib|tool|test|\.github|functions|web|assets)/[A-Za-z0-9_./-]+)`',
);

/// Matches a *bare* Dart filename in backticks: `everglow_sparkles.dart`,
/// `measure_scroll.mjs`. Dart only, on purpose: the notes also cite external
/// scripts by name (`hls.js`, `cat_3d_engine.js`, `sw.js`), which are loaded
/// from a CDN or npm and are not repo files, so checking them would be noise.
final RegExp _bareFilename = RegExp(r'`([A-Za-z0-9_]+\.dart)`');

const String _notes = 'docs/PERF_NOTES.md';

Future<void> main() async {
  const notes = _notes;
  final file = File(notes);
  if (!file.existsSync()) {
    stdout.writeln('[perf-notes] OK: no $notes to check.');
    return;
  }

  final src = await readTolerant(file);
  final missing = <String>[];
  final claimedBare = <String>{};

  for (final match in _rootedPath.allMatches(src)) {
    final cited = match.group(1)!;
    // A trailing glob means the author was describing a family of files.
    if (cited.endsWith('*')) continue;
    if (!File(cited).existsSync() && !Directory(cited).existsSync()) {
      missing.add('${_lineOf(src, match.start)} cites "$cited", which does not exist');
    }
  }

  // Bare filenames are resolved by name anywhere under lib/ or tool/, because
  // the doc cites widgets by name and the reader will not know where they live.
  if (_bareFilename.hasMatch(src)) {
    final known = <String>{};
    for (final root in const ['lib', 'tool']) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      await for (final e in dir.list(recursive: true)) {
        if (e is File) known.add(e.uri.pathSegments.last);
      }
    }
    for (final match in _bareFilename.allMatches(src)) {
      final name = match.group(1)!;
      if (known.contains(name)) continue;
      if (File(name).existsSync()) continue;
      if (claimedBare.add(name)) {
        missing.add(
          '${_lineOf(src, match.start)} cites "$name", which is not in lib/ or tool/',
        );
      }
    }
  }

  if (missing.isEmpty) {
    stdout.writeln('[perf-notes] OK: every path cited in $notes exists.');
    return;
  }

  stderr.writeln('[perf-notes] FAIL (${missing.length}):');
  for (final m in missing.toSet()) {
    stderr.writeln('  - $m');
  }
  stderr.writeln(
    '\n  $notes is the source of truth for perf work. A path it cites that no\n'
    '  longer exists sends the next reader after a tool that was deleted.\n'
    '  Update the claim, or remove the reference.',
  );
  exit(1);
}

/// 1-indexed line number of [offset] within [src], for a readable failure.
String _lineOf(String src, int offset) =>
    '$_notes:${'\n'.allMatches(src.substring(0, offset)).length + 1}';