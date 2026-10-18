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

List<String> privateBundleFailures(String pubspec, Iterable<String> tracked) {
  final failures = <String>[];
  if (RegExp(
    r'^\s*-\s*assets/images/(?:milestones/|\s*$)',
    multiLine: true,
  ).hasMatch(pubspec)) {
    failures.add(
      'Personal milestone photos must not be bundled as public assets.',
    );
  }
  if (tracked.any((path) => path.startsWith('assets/images/milestones/'))) {
    failures.add('Personal milestone photos must not be tracked by Git.');
  }
  return failures;
}

List<String> privateSeedFailures(String source) =>
    RegExp(
      r'''\bMilestone\s*\(|collection\(\s*['"]milestones['"]''',
    ).hasMatch(source)
    ? ['The public login page must not embed private milestone seed data.']
    : [];

Future<void> main() async {
  final tracked = await Process.run('git', [
    'ls-files',
    'assets/images/milestones',
  ]);
  if (tracked.exitCode != 0) {
    stderr.writeln('Cannot verify private photo tracking: ${tracked.stderr}');
    exit(1);
  }
  final failures =
      privateBundleFailures(
        await File('pubspec.yaml').readAsString(),
        (tracked.stdout as String).split('\n'),
      )..addAll(
        privateSeedFailures(
          await File(
            'lib/features/entry/presentation/pages/gateway_page.dart',
          ).readAsString(),
        ),
      );
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
