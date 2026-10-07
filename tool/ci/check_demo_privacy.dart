// Public demo and benchmark sources may only use synthetic artwork.
import 'dart:io';

import '_io.dart';

List<String> demoPrivacyFailures(String source) {
  final failures = <String>[];
  if (source.contains('assets/images/milestones/')) {
    failures.add('Personal milestone artwork is not public demo data.');
  }
  for (final match in RegExp(
    r'''(?:assets/|https?://)[^\s'"<>]+\.(?:jpg|jpeg|png|webp|gif|svg)(?:\?[^\s'"<>]*)?''',
  ).allMatches(source)) {
    final path = match.group(0)!;
    if (!path.startsWith('assets/images/demo/')) {
      failures.add('Unapproved demo artwork: $path');
    }
  }
  return failures;
}

Future<void> main() async {
  final failures = <String>[];
  for (final root in ['lib/core/agent', 'lib/core/perf']) {
    await for (final file in Directory(root).list(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll('\\', '/');
      if (!path.contains('fixture') && !path.contains('bench')) continue;
      for (final failure in demoPrivacyFailures(await readTolerant(file))) {
        failures.add('$path: $failure');
      }
    }
  }
  if (failures.isNotEmpty) {
    stderr.writeln(failures.join('\n'));
    exit(1);
  }
  stdout.writeln('[demo-privacy] OK: demo artwork is synthetic.');
}
