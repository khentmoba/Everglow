// Golden-test guard: goldens don't run in CI, so they can't gate PRs.
// History: committed PNGs render on Windows but compare on Linux, where
// font/Skia rasterization differs, so quality.yml excludes goldens. The
// jukebox leaderboard golden went red on Linux and hid a real thumbnail
// regression until PR #119 replaced it with behavioral tests (7dcb4d9).
//
// Rule: the only golden-tagged test that may exist is the grandfathered
// test/dashboard_motion_test.dart, and test/goldens/ gains no new PNGs.
// New visual coverage must be behavioral (pump the widget, assert on
// finders/fallbacks), following leaderboard_thumbnail_test.dart and
// shelf_card_thumbnail_test.dart.
//
// Usage: dart tool/ci/check_no_new_goldens.dart
import 'dart:convert';
import 'dart:io';

// Lenient read; all markers we look for are ASCII.
Future<String> readTolerant(File f) =>
    f.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));

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
    if (!allowedGolden.contains(t)) {
      failures.add(
        '$t: new golden-tagged test. Goldens are excluded from CI and '
        'cannot gate PRs — write a behavioral test instead (see '
        'test/features/jukebox/leaderboard_thumbnail_test.dart).',
      );
    }
  }

  // Behavioral companions for the two regressions goldens once hid.
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
