import 'dart:io';

import '_io.dart';

Future<void> main() async {
  final failures = <String>[];

  final libDir = Directory('lib');
  if (!await libDir.exists()) {
    stderr.writeln('[collections] lib/ not found; run from the repo root.');
    exit(2);
  }

  final dartFiles = await libDir
      .list(recursive: true)
      .where((e) => e is File && e.path.endsWith('.dart'))
      .cast<File>()
      .toList();

  final collectionPattern = RegExp(r'''\.collection\(\s*'([^']*)'\s*\)''');
  final shapePattern = RegExp(r'^[a-z_]+$');
  final used = <String, List<String>>{};

  for (final file in dartFiles) {
    final src = await readTolerant(file);
    if (src.contains('\'"\'"\'')) {
      failures.add(
        '${file.path}: shell-escaped quote sequence \'"\'"\' found '
        '(PR #63 class). Restore clean string literals.',
      );
    }
    for (final m in collectionPattern.allMatches(src)) {
      final name = m.group(1)!;
      if (!shapePattern.hasMatch(name)) {
        failures.add(
          '${file.path}: collection name "$name" must match ^[a-z_]+\$.',
        );
      }
      used.putIfAbsent(name, () => []).add(file.path);
    }
  }

  final rulesFile = File('firestore.rules');
  if (!await rulesFile.exists()) {
    stderr.writeln('[collections] firestore.rules not found.');
    exit(2);
  }
  final rules = await readTolerant(rulesFile);
  final matchPattern = RegExp(r'match\s+/([A-Za-z0-9_{}/]+)');
  final covered = <String>{};
  for (final m in matchPattern.allMatches(rules)) {
    for (final seg in m.group(1)!.split('/')) {
      if (seg.isEmpty || seg.startsWith('{') || seg == 'databases') {
        continue;
      }
      covered.add(seg);
    }
  }

  for (final name in used.keys.toList()..sort()) {
    if (!covered.contains(name)) {
      failures.add(
        'collection "$name" used in '
        '${used[name]!.take(3).join(", ")} '
        'but has no `match /$name/...` in firestore.rules. '
        'Add rules + extend functions/rules_static.test.js.',
      );
    }
  }

  if (failures.isEmpty) {
    stdout.writeln(
      '[collections] OK: ${used.length} collections clean and covered.',
    );
    return;
  }
  stderr.writeln('[collections] FAIL (${failures.length}):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}
