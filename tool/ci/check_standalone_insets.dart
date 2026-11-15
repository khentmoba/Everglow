import 'dart:io';

Future<void> main() async {
  final failures = <String>[];

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

  final offenders = <String>[];
  await for (final entity in Directory('lib').list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    String src;
    try {
      src = await entity.readAsString();
    } catch (_) {
      continue;
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
