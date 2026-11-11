// Formatting-churn ratchet: a PR must not reformat a file it did not change.
//
// `dart format` is not enforced repo-wide, so 572 of 1008 files currently
// differ from what the formatter would write. An agent that formats a file it
// is editing therefore rewrites the whole file, and the real change disappears
// into hundreds of layout lines (PR 584 review round 2: a 2-line fix arrived as
// 62 lines; PR 583 round 1: ~574 lines, almost all `dart format`).
//
// A file is churn when formatting its base version and its head version
// produces the same text: the PR changed nothing but layout. A file that also
// changes behaviour formats differently and passes, so this never asks anyone
// to stop formatting code they actually touched.
//
// Base ref: $BASE_SHA, else the merge-base with origin/main, else HEAD^1.
//
// Usage: dart tool/ci/check_format_churn.dart
import 'dart:io';

const _roots = ['lib', 'test'];

String? _git(List<String> args, {bool allowFail = false}) {
  final result = Process.runSync('git', args);
  if (result.exitCode != 0) {
    if (allowFail) return null;
    stderr.writeln('[format-churn] FAIL: git ${args.join(' ')} failed.');
    exit(1);
  }
  return (result.stdout as String).trim();
}

/// Raw stdout, so file content is not trimmed.
String? _gitRaw(List<String> args) {
  final result = Process.runSync('git', args);
  if (result.exitCode != 0) return null;
  return result.stdout as String;
}

/// The commit this branch is measured against.
String _baseRef() {
  final fromEnv = Platform.environment['BASE_SHA'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  final mergeBase = _git(
    ['merge-base', 'HEAD', 'origin/main'],
    allowFail: true,
  );
  if (mergeBase != null && mergeBase.isNotEmpty) return mergeBase;
  if (_git(['rev-parse', '--verify', 'HEAD^1'], allowFail: true) != null) {
    return 'HEAD^1';
  }
  stderr.writeln(
    '[format-churn] FAIL: cannot resolve a base commit. Fetch one '
    '(git fetch origin main) or set BASE_SHA.',
  );
  exit(1);
}

void main() {
  final base = _baseRef();
  final changed = (_git([
    'diff',
    '--name-only',
    '--no-renames',
    base,
    'HEAD',
    '--',
    ..._roots,
  ]) ?? '')
      .split('\n')
      .where((p) => p.endsWith('.dart'))
      .toList();

  if (changed.isEmpty) {
    stdout.writeln('[format-churn] OK: no Dart files changed.');
    return;
  }

  final scratch = Directory.systemTemp.createTempSync('everglow-churn-');
  try {
    final baseDir = Directory('${scratch.path}/base')..createSync();
    final headDir = Directory('${scratch.path}/head')..createSync();
    final pairs = <String, List<File>>{};

    for (var i = 0; i < changed.length; i++) {
      final path = changed[i];
      final head = File(path);
      if (!head.existsSync()) continue; // deleted in this PR
      final baseSource = _gitRaw(['show', '$base:$path']);
      if (baseSource == null) continue; // added in this PR

      // Normalise line endings so a Windows checkout and a Linux runner agree.
      String lf(String text) => text.replaceAll('\r\n', '\n');
      final baseFile = File('${baseDir.path}/$i.dart')
        ..writeAsStringSync(lf(baseSource));
      final headFile = File('${headDir.path}/$i.dart')
        ..writeAsStringSync(lf(head.readAsStringSync()));
      pairs[path] = [baseFile, headFile];
    }

    if (pairs.isEmpty) {
      stdout.writeln('[format-churn] OK: no modified Dart files.');
      return;
    }

    // One formatter run for every pair, in place.
    Process.runSync('dart', ['format', baseDir.path, headDir.path]);

    final churn = <String>[];
    for (final entry in pairs.entries) {
      final baseText = entry.value[0].readAsStringSync();
      final headText = entry.value[1].readAsStringSync();
      if (baseText == headText) churn.add(entry.key);
    }

    if (churn.isNotEmpty) {
      stderr.writeln(
        '[format-churn] FAIL: these files changed only by formatting, so the '
        'real change is buried. Keep the layout of the base version and '
        're-apply just your edit (git checkout $base -- <path>):\n'
        '${churn.map((p) => '  $p').join('\n')}',
      );
      exit(1);
    }
    stdout.writeln(
      '[format-churn] OK: ${pairs.length} changed Dart file(s), each with a '
      'real change beyond formatting.',
    );
  } finally {
    scratch.deleteSync(recursive: true);
  }
}
