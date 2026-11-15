// - explicitly waived with `// ci:unbounded-stream: <reason>` for review.
import 'dart:io';

import '_io.dart';

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
      final tail = chain.split(';').last.split('return').last;
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
