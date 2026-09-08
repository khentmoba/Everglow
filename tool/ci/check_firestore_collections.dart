// Firestore collection guard: fails the PR check on the exact breakage
// classes seen in PR #63 and the rules-drift audits (#55/#57/#59).
//
// 1. Shell-corrupted literals: POSIX escaping baked into Dart strings
//    (e.g. collection('"'"'watch_list'"'"'')) is valid Dart, so
//    `flutter analyze` stays green while every Firestore listen is
//    denied by rules. Forbids the corruption marker outright.
// 2. Collection-name shape: names must match ^[a-z_]+$ so a typo with
//    quotes, spaces, or capitals fails here instead of live.
// 3. Rules coverage: every collection segment used in lib/ must appear
//    as a `match /<segment>/...` in firestore.rules (nested matches
//    count, e.g. users/{uid}/garden_stats covers garden_stats).
//    A new collection without rules fails closed instead of shipping
//    open or denied.
//
// Usage: dart tool/ci/check_firestore_collections.dart
// Runs from the repo root; exit 0 = pass, exit 1 = fail with details.
import 'dart:convert';
import 'dart:io';

// Lenient read: one non-UTF8 source file (extended-ASCII) must not break
// the scan; all markers we look for are ASCII.
Future<String> readTolerant(File f) =>
    f.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));

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

  // The PR #63 corruption is the 5-char POSIX shell escape '"'"' baked
  // into a Dart literal (e.g. collection('"'"'watch_list'"'"'')). Match
  // exactly that sequence: shorter quote pairs like "'" in replaceAll
  // are legitimate Dart.
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
  // Collect every path segment (top-level AND nested, e.g.
  // users/{uid}/garden_stats covers garden_stats). {placeholders},
  // the databases/{database}/documents boilerplate, and the {document=**}
  // wildcard carry no collection name and are skipped.
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
