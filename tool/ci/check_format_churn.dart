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

String? _gitRaw(List<String> args) {
  final result = Process.runSync('git', args);
  if (result.exitCode != 0) return null;
  return result.stdout as String;
}

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
      if (!head.existsSync()) continue;
      final baseSource = _gitRaw(['show', '$base:$path']);
      if (baseSource == null) continue;

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
