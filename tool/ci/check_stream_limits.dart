// Stream-limit guard: list queries must stay bounded.
// Prevents the #36/#55 class: unbounded .snapshots() streams that blow
// past Firestore rules/limits and cost cold-start jank on Clair's phone
// (capped at 500 docs in tmdb_watchlist_service, audit in 34d615a).
//
// Rule (per query): each .snapshots() call must be either
// - a single-doc read (.doc( within the preceding chain), or
// - in a file containing `limit` (.limit(n) or a threaded limit
//   parameter, e.g. watchSessions({int limit = 50})), or
// - explicitly waived with `// ci:unbounded-stream: <reason>` for review.
//
// Usage: dart tool/ci/check_stream_limits.dart
import 'dart:convert';
import 'dart:io';

// Lenient read: one non-UTF8 source file (extended-ASCII) must not break
// the scan; all markers we look for are ASCII.
Future<String> readTolerant(File f) =>
    f.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));

Future<void> main() async {
  final failures = <String>[];
  var queries = 0;

  final files = await Directory('lib')
      .list(recursive: true)
      .where((e) => e is File && e.path.endsWith('.dart'))
      .cast<File>()
      .toList();

  for (final file in files) {
    final src = await readTolerant(file);
    if (!src.contains('.snapshots()')) continue;
    if (src.contains('ci:unbounded-stream')) continue;
    final fileHasLimit = src.contains('limit');
    var start = 0;
    while (true) {
      final idx = src.indexOf('.snapshots()', start);
      if (idx < 0) break;
      queries++;
      start = idx + 1;
      final chainStart = idx - 400 >= 0 ? idx - 400 : 0;
      final chain = src.substring(chainStart, idx);
      // Walk back to the start of the current expression chain.
      final tail = chain.split(';').last.split('return').last;
      // Single-doc read: bounded. Matches .doc(, _doc( helpers, doc(.
      if (RegExp(r'\b_?doc\(').hasMatch(tail)) continue;
      if (fileHasLimit) continue;
      failures.add(
        '${file.path}: unbounded .snapshots() query. '
        'Add .limit(n) or thread a limit parameter (see #36).',
      );
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('[streams] OK: $queries stream queries bounded.');
    return;
  }
  final seen = failures.toSet().toList()..sort();
  stderr.writeln('[streams] FAIL (${seen.length} files):');
  for (final f in seen) {
    stderr.writeln('  - $f');
  }
  exit(1);
}
