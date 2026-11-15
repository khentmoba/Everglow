import 'dart:io';

import '_io.dart';

final RegExp _rootedPath = RegExp(
  r'`((?:lib|tool|test|\.github|functions|web|assets)/[A-Za-z0-9_./-]+)`',
);

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
    if (cited.endsWith('*')) continue;
    if (!File(cited).existsSync() && !Directory(cited).existsSync()) {
      missing.add('${_lineOf(src, match.start)} cites "$cited", which does not exist');
    }
  }

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

String _lineOf(String src, int offset) =>
    '$_notes:${'\n'.allMatches(src.substring(0, offset)).length + 1}';