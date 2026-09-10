// Standalone-inset gate: the iPhone Home Screen status-bar overlap must
// stay fixed globally. Prevents the cinema-player class: content sliding
// under the status bar (and its buttons going untappable) in the installed
// web app, where Flutter's SafeArea reports zero padding.
//
// The fix lives in exactly one place — WebStandaloneInsets injected into
// MediaQuery at the app root — so every SafeArea/AppBar/paddingOf reader
// in the app clears the bar, including screens added in the future.
// Per-screen padding widgets would double-pad on top of it, so they are
// banned: this guard fails the PR when
//   1. AppRoot stops applying WebStandaloneInsets, or
//   2. the removed WebAppTopInset widget (or a new usage of it) reappears.
//
// Usage: dart tool/ci/check_standalone_insets.dart
import 'dart:io';

Future<void> main() async {
  final failures = <String>[];

  // 1. The global coverage must stay wired at the app root.
  final appRoot = File('lib/core/di/app_root.dart');
  if (!await appRoot.exists()) {
    failures.add('lib/core/di/app_root.dart is missing.');
  } else {
    final src = await appRoot.readAsString();
    if (!src.contains('WebStandaloneInsets')) {
      failures.add(
        'AppRoot no longer applies WebStandaloneInsets: Home Screen '
        'status-bar overlap will regress on every screen.',
      );
    }
  }

  // 2. The injector itself must keep measuring + publishing the inset.
  final webImpl = File('lib/core/system/web_standalone_web.dart');
  if (!await webImpl.exists()) {
    failures.add('lib/core/system/web_standalone_web.dart is missing.');
  } else {
    final src = await webImpl.readAsString();
    for (final marker in [
      'class WebStandaloneInsets',
      'safeAreaTop',
      'viewPadding',
    ]) {
      if (!src.contains(marker)) {
        failures.add(
          'web_standalone_web.dart lost "$marker": the global inset '
          'no longer reaches MediaQuery.',
        );
      }
    }
  }

  // 3. No per-screen padding widgets: they double-pad under the global
  // inset. (WebAppTopInset was removed when coverage moved to AppRoot.)
  final offenders = <String>[];
  await for (final entity in Directory('lib').list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    String src;
    try {
      src = await entity.readAsString();
    } catch (_) {
      continue; // Non-UTF8 asset-adjacent file: not a widget source.
    }
    if (src.contains('WebAppTopInset')) {
      offenders.add(entity.path);
    }
  }
  if (offenders.isNotEmpty) {
    failures.add(
      'Per-screen WebAppTopInset usage would double-pad under the global '
      'inset (found in: ${offenders.join(", ")}). Use plain SafeArea — '
      'AppRoot already supplies the inset via MediaQuery.',
    );
  }

  if (failures.isEmpty) {
    stdout.writeln(
      '[insets] OK: global Home Screen status-bar coverage intact.',
    );
    return;
  }
  stderr.writeln('[insets] FAIL (${failures.length}):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}
