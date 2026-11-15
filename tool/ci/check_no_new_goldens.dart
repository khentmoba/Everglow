import 'dart:io';

import '_io.dart';

Future<void> main() async {
  final failures = <String>[];

  const allowedGolden = {'test/dashboard_motion_test.dart'};
  final testDir = Directory('test');
  if (!await testDir.exists()) {
    stderr.writeln('[goldens] test/ not found; run from the repo root.');
    exit(2);
  }

  final tagged = <String>[];
  await for (final e in testDir.list(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    final src = await readTolerant(e);
    if (src.contains("@Tags(['golden'])") ||
        src.contains('@Tags(["golden"])')) {
      tagged.add(e.path);
    }
  }
  for (final t in tagged) {
    final normPath = t.replaceAll('\\', '/');
    if (!allowedGolden.contains(normPath)) {
      failures.add(
        '$t: new golden-tagged test. Goldens are excluded from CI and '
        'cannot gate PRs — write a behavioral test instead (see '
        'test/features/jukebox/leaderboard_thumbnail_test.dart).',
      );
    }
  }

  for (final need in [
    'test/features/jukebox/leaderboard_thumbnail_test.dart',
    'test/features/dashboard/presentation/widgets/shelf_card_thumbnail_test.dart',
  ]) {
    if (!await File(need).exists()) {
      failures.add('$need is missing; thumbnail regressions lose coverage.');
    }
  }

  if (failures.isEmpty) {
    stdout.writeln(
      '[goldens] OK: no new golden tests; thumbnail behavior covered.',
    );
    return;
  }
  stderr.writeln('[goldens] FAIL (${failures.length}):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}
